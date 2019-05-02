#!/bin/sh
# Networking config script optionally invoked by Qemu.

# Useful when launching Qemu instances with the networking configuration where
# Qemu creates a tunnel network interface on the host to the emulated machine.
# This script then interconnects these tunnel devices (from multiple instances)
# to a bridge (manually) created on the host, by running the following as root:
#     # sudo ip link add br0 type bridge

set -x

switch=br0
tun=$1

if [ -n "$tun" ]
then
    ip link set $tun up
    ip link set $tun master $switch
else
    echo "Error: no interface specified"
    exit 1
fi
