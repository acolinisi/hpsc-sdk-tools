#!/bin/bash

# Construct the QEMU command line and invoke it
#
# Expects SDK to have been activated by loading
# the SDK env.sh script into the shell.
#
# Dependencies:
#   * screen : for display of forwarded serial UART ports
#   * Python 2: with the following modules
#      - telnetlib : for communication with Qemu via QMP interface
#      - json : for QMP

function finish {
    if [ -n "$GDB_CMD_FILE" ]
    then
        rm "$GDB_CMD_FILE"
    fi
    local JOBS="$(jobs -p)"
    [[ -z "$JOBS" ]] || kill $JOBS
}
trap finish EXIT

function source_if_exists()
{
    if [ -f "$1" ]
    then
        echo Loading env from: $1
        source "$1"
    fi
}

PORT_BASE=$((1024 + $(id -u) + 1000)) # arbitrary, but unique and not system
LOG_FILE=/tmp/qemu-$(whoami).log
BRIDGE=br0
HOST_BIND_IP=127.0.0.1

# Source files from which to init mem images (none by default)
TRCH_SMC_SRAM=
TRCH_SMC_NAND=
HPPS_SMC_SRAM=
HPPS_SMC_NAND=

# Size of off-chip memory connected to SMC SRAM ports,
# this size is used if/when this script creates the images.
LSIO_SRAM_SIZE=0x04000000           #  64MB
HPPS_SRAM_SIZE=0x01000000           #  16MB
HPPS_NAND_SIZE=0x10000000           # 256MB
HPPS_NAND_PAGE_SIZE=2048 # bytes
HPPS_NAND_OOB_SIZE=64 # bytes
HPPS_NAND_ECC_SIZE=12 # bytes
HPPS_NAND_PAGES_PER_BLOCK=64 # bytes
TRCH_NAND_SIZE=0x10000000           # 256MB
TRCH_NAND_PAGE_SIZE=2048 # bytes
TRCH_NAND_OOB_SIZE=64 # bytes
TRCH_NAND_ECC_SIZE=12 # bytes
TRCH_NAND_PAGES_PER_BLOCK=64 # bytes

# Allow overriding settings (most of which settable via command line)
ENV_FILES=("${PWD}/qemu-env.sh")

parse_addr() {
    echo $1 | sed 's/_//g'
}
hex() {
    printf "0x%x" $1
}
extract_word() {
    IDX=$1
    shift
    local i=0
    for w in "$@"
    do
        if [ $i -eq $IDX ]
        then
            echo $w
            return
        fi
        i=$(($i + 1))
    done
}

function nand_blocks() {
    local size=$1
    local page_size=$2
    local pages_per_block=$3
    echo $(( size / (pages_per_block * page_size) ))
}

run() {
    echo "$@"
    "$@"
}

function create_sram_image()
{
    run sram-image-utils create "$1" "$2"
    run sram-image-utils show "$1"
}

create_nand_image()
{
    local file=$1
    local size=$2
    local page_size=$3
    local pages_per_block=$4
    local oob_size=$5
    local ecc_size=$6
    local blocks="$(nand_blocks $size $page_size $pages_per_block)"
    run qemu-nand-creator $page_size $oob_size $pages_per_block $blocks $ecc_size 1 "$file"
}

create_if_absent()
{
    local dest=$1
    local src=$2
    local creator=$3
    shift 3
    if [ -f "$src" ] # if a source is given, override current image
    then
        run cp $src $dest
    else
        if [ ! -f "$dest" ]
        then
            $creator "$dest" "$@"
        else
            echo "Using existing image: $dest"
        fi
    fi
}

create_images()
{
    set -e

    create_if_absent "${TRCH_SRAM_FILE}" "${TRCH_SMC_SRAM}" create_sram_image ${LSIO_SRAM_SIZE}
    create_if_absent "${TRCH_NAND_FILE}" "${TRCH_SMC_NAND}" create_nand_image \
        $TRCH_NAND_SIZE $TRCH_NAND_PAGE_SIZE $TRCH_NAND_PAGES_PER_BLOCK $TRCH_NAND_OOB_SIZE $TRCH_NAND_ECC_SIZE
    create_if_absent "${HPPS_SRAM_FILE}" "${HPPS_SMC_SRAM}" create_sram_image ${HPPS_SRAM_SIZE}
    create_if_absent "${HPPS_NAND_FILE}" "${HPPS_SMC_NAND}" create_nand_image \
        $HPPS_NAND_SIZE $HPPS_NAND_PAGE_SIZE $HPPS_NAND_PAGES_PER_BLOCK $HPPS_NAND_OOB_SIZE $HPPS_NAND_ECC_SIZE
    set +e
}

function usage()
{
    echo "Usage: $0 [-hSq] [-e env] [-m mem] [-n netcfg] [-i id] [ cmd ]" 1>&2
    echo "               cmd: command" 1>&2
    echo "                    run - start emulation (default)" 1>&2
    echo "                    gdb - launch the emulator in GDB" 1>&2
    echo "               -e env: load environment settings from file" 1>&2
    echo "               -m memory map: preload files into memory" 1>&2
    echo "               -i id: numeric ID to identify the Qemu instance" 1>&2
    echo "               -n netcfg : choose networking configuration" 1>&2
    echo "                   user: forward a port on the host to the target NIC" 1>&2
    echo "                   tap: create a host tunnel interface to the target NIC (requires root)" 1>&2
    echo "               -S : wait for GDB or QMP connection instead of resetting the machine" 1>&2
    echo "               -q : do not enable the Qemu monitor prompt" 1>&2
    echo "               -h : show this message" 1>&2
    exit 1
}

function setup_screen()
{
    local SESSION=$1

    if [ "$(screen -list "$SESSION" | grep -c "$SESSION")" -gt 1 ]
    then
        # In case the user somehow ended up with more than one screen process,
        # kill them all and create a fresh one.
        echo "Found multiple screen sessions matching '$SESSION', killing..."
        screen -list "$SESSION" | grep "$SESSION" | \
            sed -n "s/\([0-9]\+\).$SESSION\s\+.*/\1/p" | xargs kill
    fi

    # There seem to be some compatibility issues between Linux distros w.r.t.
    # exit codes and behavior when using -r and -q with -ls for detecting if a
    # user is attached to a session, so we won't bother trying to wait for them.
    screen -q -list "$SESSION"
    # it's at least consistent that no matching screen sessions gives $? < 10
    if [ $? -lt 10 ]
    then
        echo "Creating screen session with console: $SESSION"
        screen -d -m -S "$SESSION"
    fi
}

function serial_ptys()
{
    qmp.py -q localhost $QMP_PORT query-chardev | \
        qemu-chardev-ptys ${SERIAL_PORTS[*]}
}

function attach_consoles()
{
    echo "Waiting for Qemu to open QMP port and to query for PTY paths..."
    #while test $(lsof -ti :$QMP_PORT | wc -l) -eq 0
    while true
    do
        PTYS=$(serial_ptys 2>/dev/null)
        if [ -z "$PTYS" ]
        then
            #echo "Waiting for Qemu to open QMP port..."
            sleep 1
            ATTEMPTS+=" 1 "
            if [ "$(echo "$ATTEMPTS" | wc -w)" -eq 10 ]
            then
                echo "ERROR: failed to get PTY paths from Qemu via QMP port: giving up."
                echo "Here is what happened when we tried to get the PTY paths:"
                set -x
                serial_ptys
                exit # give up to not accumulate waiting processes
            fi
        else
            break
        fi
    done

    read -r -a PTYS_ARR <<< "$PTYS"
    for ((i = 0; i < ${#PTYS_ARR[@]}; i++))
    do
        # Need to start a new single-use $pty_sess screen session outside of the
        # persistent $sess one, then attach to $pty_sess from within $sess.
        # This is needed if $sess was previously attached, then detached (but
        # not terminated) after QEMU exited.
        local pty=${PTYS_ARR[$i]}
        local sess=${SCREEN_SESSIONS[$i]}
        local pty_sess="hpsc-pts$(basename "$pty")"
        echo "Adding console $pty to screen session $sess"
        screen -d -m -S "$pty_sess" "$pty"
        # TODO: Make this work without using "stuff" command
        screen -S "$sess" -X stuff "^C screen -m -r $pty_sess\r"
        echo "Attach to screen session from another window with:"
        echo "  screen -r $sess"
    done

    echo "Commanding Qemu to reset the machine..."
    if [ "$RESET" -eq 1 ]
    then
        echo "Sending 'continue' command to Qemu to reset the machine..."
        qmp.py localhost $QMP_PORT cont
    else
        echo "Waiting for 'continue' (aka. reset) command via GDB or QMP connection..."
    fi
}

setup_console()
{
    for session in "${SCREEN_SESSIONS[@]}"
    do
        setup_screen $session
    done
    attach_consoles &
}

preload_memory()
{
    set -e
    local map_file=$1
    echo "Preloading memory according to map file: $map_file"
    if [ ! -r ${map_file} ] # 'while...done < file' not fatal even with set -e
    then
        echo "ERROR: can't read preload memory map file: $map_file" 1>&2
        return 1
    fi
    declare -A SEGMENT_ADDRS
    declare -A SEGMENT_FILES
    local line_num=0
    while read line
    do
        local HASH="#" # workaround for vim syntax highlightin breaking
        if [[ "$line" =~ ^\s*$ || "$line" =~ ^[[:space:]]*$HASH ]]
        then
            continue
        fi
        line=$(echo $line | sed 's/\(.*\)\s*#.*/\1/')

        local key=$(extract_word 0 $line)
        local addr_spec=$(extract_word 1 $line)
        local in_file=$(eval echo $(extract_word 2 $line)) # expand vars

        if [[ -z "$key" || -z "$addr_spec" || -z "$in_file" ]]
        then
            echo "ERROR: syntax error on line $line_num" 1>&2
            exit 2
        fi

        # Address field can be: 0x00000000, 0x0000_0000, after(name), -, 4:<any of the above>
        addr_spec=$(echo "$addr_spec" | sed 's/_//g')
        local cpu="$(echo "$addr_spec" | sed -n 's/^\([0-9]\+\):.*/\1/p')" # may be empty
        addr_spec="$(echo "$addr_spec" | sed -n 's/^\([0-9]\+:\)\?\(.*\)/\2/p')"
        local ref_seg=$(echo $addr_spec | sed -n 's/^after(\([^)]\+\))/\1/p')
        if [ ! -z "$ref_seg" ]
        then
            local addr=$(hex $((${SEGMENT_ADDRS[$ref_seg]} + $(stat -c '%s' ${SEGMENT_FILES[$ref_seg]}))))
        else
            if [[ "$addr_spec" =~ - ]]
            then  # do not supply addr
                local addr=
            else
                local addr="$(parse_addr $(echo "$addr_spec" | sed -n 's/^\(0x\)\?\([0-9A-Fa-f]\+\)/\1\2/p'))"
            fi
        fi
        SEGMENT_ADDRS["$key"]="$addr"
        SEGMENT_FILES["$key"]="$in_file"

        local loader_arg="loader,file=$in_file"
        if [ ! -z "$cpu" ]
        then
            loader_arg+=",cpu-num=$cpu"
        fi
        if [ ! -z "$addr" ]
        then
            loader_arg+=",force-raw,addr=$addr"
        fi
        COMMAND+=(-device "$loader_arg")

        line_num=$(($line_num + 1))
    done < $map_file
    set +e
}

# defaults
RESET=1
NET=user
MONITOR=1

# parse options
while getopts "h?S?q?e:d:m:p:n:i:" o; do
    case "${o}" in
        S)
            RESET=0
            ;;
        d)
            QEMU_DT_FILE="$OPTARG"
            ;;
        e)
            ENV_FILES+=("$OPTARG")
            ;;
        m)
            MEMORY_FILE="$OPTARG"
            ;;
        i)
            CLI_ID="$OPTARG"
            ;;
        n)
            NET="$OPTARG"
            ;;
        q)
            MONITOR=0
            ;;
        h)
            usage
            ;;
        *)
            echo "Wrong option" 1>&2
            usage
            ;;
    esac
done
shift $((OPTIND-1))
CMD=$*

if [ -z "${CMD}" ]
then
    CMD="run"
fi

for qemu_env in "${ENV_FILES[@]}"
do
   echo QEMU ENV ${qemu_env}
    source_if_exists ${qemu_env}
done

# Privatize generated files, ports, screen sessions for this Qemu instance

# Complexity only because env files were already sourced before CLI processing
if [ ! -z "${CLI_ID}" ] # let CLI override
then
    ID=${CLI_ID}
else
    if [ -z "${ID}" ] # let env files already sourced above define it
    then
        ID=0
    fi
fi


TRCH_SRAM_FILE=trch_sram.bin.${ID}
TRCH_NAND_FILE=trch_nand.bin.${ID}
HPPS_NAND_FILE=hpps_nand.bin.${ID}
HPPS_SRAM_FILE=hpps_sram.bin.${ID}

MAC_ADDR=00:0a:35:00:02:$ID
# This target IP is for 'user' networking mode, where the address is private,
# all instances can use the same address.
TARGET_IP=10.0.2.15

SSH_TARGET_PORT=22
DEBUG_TARGET_PORT=2345

MAX_INSTANCES=8
QMP_PORT=$((PORT_BASE + 0 * $MAX_INSTANCES + $ID))
GDB_PORT=$((PORT_BASE + 1 * $MAX_INSTANCES + $ID))
SSH_PORT=$((PORT_BASE + 2 * $MAX_INSTANCES + $ID))
DEBUG_PORT=$((PORT_BASE + 3 * $MAX_INSTANCES + $ID))

# Labels are created by Qemu with the convention "serialN"
SCREEN_SESSIONS=(hpsc-$ID-trch hpsc-$ID-rtps-r52 hpsc-$ID-hpps)
SERIAL_PORTS=(serial0 serial1 serial2)
SERIAL_PORT_ARGS=()
for _ in "${SERIAL_PORTS[@]}"
do
    SERIAL_PORT_ARGS+=(-serial pty)
done

RUN=0
echo "CMD: ${CMD}"
case "${CMD}" in
   run)
        create_images
        setup_console
        RUN=1
        ;;
   gdb)
        # setup/attach_consoles are called when gdb runs this script with "consoles"
        # cmd from the hook to the "run" command defined below:

        if [ "$RESET" -eq 1 ]
        then
            RESET_ARG=""
        else
            RESET_ARG="-S"
        fi

        # NOTE: have to go through an actual file because -ex doesn't work since no way
        ## to give a multiline command (incl. multiple -ex), and bash-created file -x
        # <(echo -e ...) doesn't work either (issue only with gdb).
        GDB_CMD_FILE=$(mktemp)
        cat >/"$GDB_CMD_FILE" <<EOF
define hook-run
shell $0 $RESET_ARG gdb_run
end
EOF
        GDB_ARGS=(gdb -x "$GDB_CMD_FILE" --args)
        RUN=1
        ;;
    gdb_run)
        create_images
        setup_console
        ;;
esac

if [ "$RUN" -eq 0 ]
then
    exit
fi

# Compose qemu commands according to the command options.
# Build the command as an array of strings. Quote anything with a path variable
# or that uses commas as part of a string instance. Building as a string and
# using eval on it is error-prone, e.g., if spaces are introduced to parameters.
#
# See QEMU User Guide in HPSC release for explanation of the command line arguments
# Note: order of -device args may matter, must load ATF last, because loader also sets PC
# Note: If you want to see instructions and exceptions at a large performance cost, then add
# "in_asm,int" to the list of categories in -d.

COMMAND=("${GDB_ARGS[@]}" "qemu-system-aarch64"
    -machine "arm-generic-fdt"
    -m 4G
    -nographic
    -qmp "telnet::$QMP_PORT,server,nowait"
    -gdb "tcp::$GDB_PORT"
    -S
    -D "${LOG_FILE}" -d "fdt,guest_errors,unimp,cpu_reset"
    -hw-dtb "${QEMU_DT_FILE}"
    "${SERIAL_PORT_ARGS[@]}"
    -drive "file=$HPPS_NAND_FILE,if=pflash,format=raw,index=3"
    -drive "file=$HPPS_SRAM_FILE,if=pflash,format=raw,index=2"
    -drive "file=$TRCH_SRAM_FILE,if=pflash,format=raw,index=0"
    "${QEMU_ARGS[@]}")

NET_NIC=(-net nic,vlan=0,macaddr=$MAC_ADDR)
case "${NET}" in
tap)
    # See HPSC Qemu User Guide for setup. In short, do this once, as root:
    #     ip link add $BRIDGE type bridge
    #     echo "allow $BRIDGE" >> /usr/local/etc/qemu/bridge.conf
    #     install -o root -g root -m 4775 /usr/local/bin/qemu-bridge-helper $QEMU_BRIDGE_PREFIX
    COMMAND+=("${NET_NIC[@]}" -net tap,vlan=0,br=$BRIDGE,helper=qemu-bridge-helper)
    ;;
user)
    PORT_FWD_ARGS="hostfwd=tcp:$HOST_BIND_IP:$SSH_PORT-$TARGET_IP:$SSH_TARGET_PORT"
    PORT_FWD_ARGS+=",hostfwd=tcp:$HOST_BIND_IP:$DEBUG_PORT-$TARGET_IP:$DEBUG_TARGET_PORT"
    COMMAND+=("${NET_NIC[@]}" -net user,vlan=0,$PORT_FWD_ARGS)
    ;;
none)
    ;;
*)
    echo "ERROR: invalid networking config choice: $NET" 1>&2
    exit 1
    ;;
esac

if [ "$MONITOR" -eq 1 ]
then
    COMMAND+=(-monitor stdio)
fi

if [ ! -z "${MEMORY_FILE}" ]
then
    preload_memory "${MEMORY_FILE}"
fi

echo "Final Command (one arg per line):"
for arg in ${COMMAND[*]}
do
    echo $arg
done
echo

echo "Final Command:"
echo "${COMMAND[*]}"
echo

echo "QMP_PORT = ${QMP_PORT}"
echo "GDB_PORT = ${GDB_PORT}"

if [ "${NET}" = "user" ]
then
    echo "SSH_PORT = ${HOST_BIND_IP}:${SSH_PORT} -> ${TARGET_IP}:${SSH_TARGET_PORT}"
    echo "DEBUG_PORT = ${HOST_BIND_IP}:${DEBUG_PORT} -> ${TARGET_IP}:${DEBUG_TARGET_PORT}"
fi
echo

# Make it so!
"${COMMAND[@]}"
