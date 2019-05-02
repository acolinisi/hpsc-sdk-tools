# HPSC SDK Tools

This folder contains a set of host-side tools for developing software for the
HPSC Chiplet platform. These tools are part of the SDK for the HPSC Chiplet
platform, which also includes a system emulator (Qemu) for the platform.

The `make/` directory provides the following makefiles:

 * `Makefile.sdk`: builds a non-relocatable SDK in-place, relying on dependencies
   provided by the system (includes targets for installing  dependency packages
   on supported distributions) or provided by the sysroot built via
  `Makefile.sysroot` (see below),
 * `Makefile.sysroot`: builds a partial sysroot, against which the SDK can then
   be built (via `Makefile.sdk`) without root privileges (since dependencies
   no longer need to be installed into the system). This sysroot does not include
   all dependendencies and some dependencies must still be provided by the system.
