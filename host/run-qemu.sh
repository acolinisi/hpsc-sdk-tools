#!/bin/bash

# Note: Before running the following script, please make sure to:
#
# 1.  Run the "build-hpsc-yocto.sh" script to generate many of the needed QEMU
#     files.
#
# 2.  Run the "build-hpsc-baremetal.sh" script (with the proper toolchain
#     path) to create the baremetal firmware files "trch.elf" and "rtps.elf".
#
# Dependencies:
#   * uboot-tools : for creating U-boot images
#   * screen : for display of forwarded serial UART ports
#   * Python 2: with the following modules
#      - telnetlib : for communication with Qemu via QMP interface
#      - configparse : for config INI->BIN compiler (cfgc)
#      - json : for QMP and for cfgc

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

SYSCFG_ADDR=0x000ff000 # in TRCH SRAM

HPPS_FW_ADDR=0x80000000
HPPS_BL_ADDR=0x80020000
HPPS_DT_ADDR=0x80060000
HPPS_KERN_ADDR=0x80064000
HPPS_KERN_LOAD_ADDR=0x80480000 # (base + TEXT_OFFSET), where base must be aligned to 2MB
HPPS_RAMDISK_ADDR=0x90000000
# HPPS_RAMDISK_LOAD_ADDR      # where BL extracts the ramdisk, set by u-boot image header

# RTPS
RTPS_BL_ADDR=0x60000000       # load address for R52 u-boot
RTPS_APP_ADDR=0x68000000      # address of baremetal app binary file
# RTPS_APP_LOAD_ADDR          # where BL loads image: set u-boot image (from ELF header)

# TRCH
# TRCH_APP_LOAD_ADDR          # where ELF sections are loaded, set in the ELF header

# Size of off-chip memory connected to SMC SRAM ports,
# this size is used if/when this script creates the images.
LSIO_SRAM_SIZE=0x04000000           #  64MB
HPPS_SRAM_SIZE=0x01000000           #  16MB
HPPS_NAND_SIZE=0x10000000           # 256MB
HPPS_NAND_PAGE_SIZE=2048 # bytes
HPPS_NAND_OOB_SIZE=64 # bytes
HPPS_NAND_ECC_SIZE=12 # bytes
HPPS_NAND_PAGES_PER_BLOCK=64 # bytes

# Environment settings (paths to build artifacts and tools and the default
# settings defined above) may be overriden by placing the file at multiple
# locations (vars in later files override vars in earlier files):
QEMU_ENV=qemu-env.sh

source_if_exists "$(dirname "$0")/$QEMU_ENV"
source_if_exists "$HPSC_ROOT/$QEMU_ENV"
source_if_exists "$PWD/$QEMU_ENV"

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

# create non-volatile offchip sram image
function create_lsio_smc_sram_port_image()
{
    echo Creating TRCH SMC SRAM image and adding boot images...
    run "${SRAM_IMAGE_UTILS}" create "${TRCH_SRAM_FILE}" ${LSIO_SRAM_SIZE}
    run "${SRAM_IMAGE_UTILS}" add "${TRCH_SRAM_FILE}" "${SYSCFG_BIN}"   "syscfg"  ${SYSCFG_ADDR}
    run "${SRAM_IMAGE_UTILS}" add "${TRCH_SRAM_FILE}" "${RTPS_BL}"      "rtps-bl" ${RTPS_BL_ADDR}
    run "${SRAM_IMAGE_UTILS}" add "${TRCH_SRAM_FILE}" "${RTPS_APP}"     "rtps-os" ${RTPS_APP_ADDR}
    run "${SRAM_IMAGE_UTILS}" add "${TRCH_SRAM_FILE}" "${HPPS_BL}"      "hpps-bl" ${HPPS_BL_ADDR}
    run "${SRAM_IMAGE_UTILS}" add "${TRCH_SRAM_FILE}" "${HPPS_FW}"      "hpps-fw" ${HPPS_FW_ADDR}
    run "${SRAM_IMAGE_UTILS}" add "${TRCH_SRAM_FILE}" "${HPPS_DT}"      "hpps-dt" ${HPPS_DT_ADDR}
    run "${SRAM_IMAGE_UTILS}" add "${TRCH_SRAM_FILE}" "${HPPS_KERN}"    "hpps-os" ${HPPS_KERN_ADDR}
    run "${SRAM_IMAGE_UTILS}" show "${TRCH_SRAM_FILE}"
}

function create_hpps_smc_sram_port_image()
{
    echo Creating an empty image for off-chip mem at HPPS SMC SRAM port...
    run "${SRAM_IMAGE_UTILS}" create "${HPPS_SRAM_FILE}" ${HPPS_SRAM_SIZE}
    run "${SRAM_IMAGE_UTILS}" show "${HPPS_SRAM_FILE}"
}

create_hpps_smc_nand_port_image()
{
    echo Creating an empty image for off-chip mem at HPPS SMC NAND port...
    local blocks=$(nand_blocks $HPPS_NAND_SIZE $HPPS_NAND_PAGE_SIZE $HPPS_NAND_PAGES_PER_BLOCK)
    run "${NAND_CREATOR}" $HPPS_NAND_PAGE_SIZE $HPPS_NAND_OOB_SIZE $HPPS_NAND_PAGES_PER_BLOCK \
                "$blocks" $HPPS_NAND_ECC_SIZE 1 "${HPPS_NAND_IMAGE}"
}

create_kern_image() {
    echo Packing the kernel binary into a U-boot image...
    run mkimage -C gzip -A arm64 -d "${HPPS_KERN_BIN}" -a ${HPPS_KERN_LOAD_ADDR} "${HPPS_KERN}"
}

create_syscfg_image()
{
    echo Compiling system config from INI to binary format...
    run ${BSP_DIR}/cfgc -s "${SYSCFG_SCHEMA}" "${SYSCFG}" "${SYSCFG_BIN}"
}

syscfg_get()
{
    python -c "import configparser as cp; c = cp.ConfigParser(); c.read('$SYSCFG'); print(c['$1']['$2'])"
}

# file path, creation function
create_if_absent()
{
    if [ ! -f "$1" ]
    then
        $2
    else
        echo "Using existing image: $1"
    fi
}

create_images()
{
    set -e
    create_syscfg_image

    if [ $CREATE_KERN_IMAGE -eq 1 ]
    then
        create_kern_image
    fi

    create_lsio_smc_sram_port_image
    create_if_absent "${HPPS_SRAM_FILE}" create_hpps_smc_sram_port_image
    create_if_absent "${HPPS_NAND_IMAGE}" create_hpps_smc_nand_port_image
    set +e
}

function usage()
{
    echo "Usage: $0 [-hSq] [-n netcfg] [-i id] [ cmd ]" 1>&2
    echo "               cmd: command" 1>&2
    echo "                    run - start emulation (default)" 1>&2
    echo "                    gdb - launch the emulator in GDB" 1>&2
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

function attach_consoles()
{
    echo "Waiting for Qemu to open QMP port and to query for PTY paths..."
    #while test $(lsof -ti :$QMP_PORT | wc -l) -eq 0
    while true
    do
        PTYS=$(${BSP_DIR}/qmp.py -q localhost $QMP_PORT query-chardev ${SERIAL_PORTS[*]} 2>/dev/null)
        if [ -z "$PTYS" ]
        then
            #echo "Waiting for Qemu to open QMP port..."
            sleep 1
            ATTEMPTS+=" 1 "
            if [ "$(echo "$ATTEMPTS" | wc -w)" -eq 10 ]
            then
                echo "ERROR: failed to get PTY paths from Qemu via QMP port: giving up."
                echo "Here is what happened when we tried to get the PTY paths:"
                run ${BSP_DIR}/qmp.py -q localhost $QMP_PORT query-chardev ${SERIAL_PORTS[*]}
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
        ${BSP_DIR}/qmp.py localhost $QMP_PORT cont
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

RESET=1
NET=user
ID=0
MONITOR=1

# parse options
while getopts "h?S?q?n:i:" o; do
    case "${o}" in
        S)
            RESET=0
            ;;
        i)
            ID="$OPTARG"
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

# Privatize generated files, ports, screen sessions for this Qemu instance

SYSCFG_BIN=syscfg.bin.${ID}
TRCH_SRAM_FILE=trch_sram.bin.${ID}
HPPS_NAND_IMAGE=rootfs_nand.bin.${ID}
HPPS_SRAM_FILE=hpps_sram.bin.${ID}

# Support legacy setup where the kernel image is not created by the build
CREATE_KERN_IMAGE=0
if [ -z "$HPPS_KERN" ]
then
    if [ -z "$HPPS_KERN_BIN" ] # kernel image is created from this file
    then
        echo "ERROR: neither HPPS_KERN nor HPPS_KERN_BIN is defined" 2>&1
        exit 1
    fi
    CREATE_KERN_IMAGE=1
    HPPS_KERN=uImage.${ID}
fi

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

COMMAND=("${GDB_ARGS[@]}" "${QEMU_BIN_DIR}/qemu-system-aarch64"
    -machine "arm-generic-fdt"
    -nographic
    -qmp "telnet::$QMP_PORT,server,nowait"
    -gdb "tcp::$GDB_PORT"
    -S
    -D "${LOG_FILE}" -d "fdt,guest_errors,unimp,cpu_reset"
    -hw-dtb "${QEMU_DT_FILE}"
    "${SERIAL_PORT_ARGS[@]}"
    -drive "file=$HPPS_NAND_IMAGE,if=pflash,format=raw,index=3"
    -drive "file=$HPPS_SRAM_FILE,if=pflash,format=raw,index=2"
    -drive "file=$TRCH_SRAM_FILE,if=pflash,format=raw,index=0"
    "${QEMU_ARGS[@]}")

NET_NIC=(-net nic,vlan=0,macaddr=$MAC_ADDR)
case "${NET}" in
tap)
    # See HPSC Qemu User Guide for setup. In short, do this once, as root:
    #     ip link add $BRIDGE type bridge
    #     echo "allow $BRIDGE" >> $QEMU_PREFIX/etc/qemu/bridge.conf
    #     install -o root -g root -m 4775 $QEMU_DIR/qemu-bridge-helper $QEMU_PREFIX/bin/
    COMMAND+=("${NET_NIC[@]}" -net tap,vlan=0,br=$BRIDGE,helper=$QEMU_PREFIX/bin/qemu-bridge-helper)
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

BOOT__BIN_LOC=$(syscfg_get boot bin_loc)
if [ $? -ne 0 ]; then echo "ERROR: syscfg_get failed" && exit 1; fi

if [ "$BOOT__BIN_LOC" = "DRAM" ]
then
    # The following two are used only for developer-friendly boot mode in which
    # Qemu loads the images directly into DRAM upon startup of the machine (not
    # possible on real HW).
    COMMAND+=(
        -device "loader,addr=${RTPS_BL_ADDR},file=${RTPS_BL},force-raw,cpu-num=1"
        -device "loader,addr=${RTPS_APP_ADDR},file=${RTPS_APP},force-raw,cpu-num=1"
        -device "loader,addr=${HPPS_FW_ADDR},file=${HPPS_FW},force-raw,cpu-num=4"
        -device "loader,addr=${HPPS_BL_ADDR},file=${HPPS_BL},force-raw,cpu-num=4"
        -device "loader,addr=${HPPS_DT_ADDR},file=${HPPS_DT},force-raw,cpu-num=4"
        -device "loader,addr=${HPPS_KERN_ADDR},file=${HPPS_KERN},force-raw,cpu-num=4")
fi

HPPS__ROOTFS_LOC=$(syscfg_get HPPS rootfs_loc)
if [ $? -ne 0 ]; then echo "ERROR: syscfg_get failed" && exit 1; fi

if [ "$HPPS__ROOTFS_LOC" = "HPPS_DRAM" ]
then
    COMMAND+=(-device "loader,addr=${HPPS_RAMDISK_ADDR},file=${HPPS_RAMDISK},force-raw,cpu-num=4")
fi

# Storing TRCH code in NV mem is not yet supported, so it is loaded directly
# into TRCH SRAM by Qemu's ELF loader on machine startup
COMMAND+=(-device "loader,file=${TRCH_APP},cpu-num=0")

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

function finish {
    if [ -n "$GDB_CMD_FILE" ]
    then
        rm "$GDB_CMD_FILE"
    fi
}
trap finish EXIT

# Make it so!
"${COMMAND[@]}"
