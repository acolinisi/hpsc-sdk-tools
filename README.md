# HPSC SDK Tools

This folder contains a set of host-side tools for developing software for the
HPSC Chiplet platform. These tools are part of the SDK for the HPSC Chiplet
platform, which also includes a system emulator (Qemu) for the platform.

`make/Makefile.sdk` builds a non-relocatable SDK in-place (i.e. not packed
into an installer; usuable only on the host that built it), relying on
dependencies provided by either
 * the system (targets for installing dependency packages
   are included for supported distributions), or
 * a (partial) sysroot built from source without root privileges,
   using `sysroot/Makefile`. The sysroot is partial: the SDK
   built against it still relies on some dependencies provided
   by the system; but those remaining dependencies are usually available on
   most Linux systems, as opposed to the full set of dependencies.
