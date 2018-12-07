HPSC Host Utilities
===================

This directory contains host utilities to manipulate nand and sram images for Qemu.
These utilites run on a X86 host machine.

Build
-----

Set the paths to the Poky SDK Aarch64 cross-compilation toolchain in Makefile and:

    make

qemu-nand-creator
-----

qemu-nand-creator creates a nand image file for Qemu. It can create either empty nand image or nand image file with data through STDIN.

    ./qemu-nand-creator <page size> <oob size> <num of pages per block> <num_blocks> <ecc size> <1: empty image, 0: stdin>

An example of creating empty 2Gb Nand of 2k page size, 64 byte OOB, 12 byte ECC, and 128k block size is as follows:
    ./qemu-nand-creator 2048 64 64 2048 12 1

An example of creating a nand image with a binary file written in it is as follows:
    ./qemu-nand-creator 2048 64 64 2048 12 0 < <file name>

sram-image-utils
-----

sram-image-utils creates a sram image for Qemu.
It can create an empty sram image, and add a file.
Only one transcation can be done each time.

The usage is as follows:

    ./sram-image-utils <command> <filename> [command parameters] 

	"file name" is the name of sram image file.
        "command" can be one of "create", "add", "show", "help".
        "command" can have shorter form "c", "a", "s", "h".

To create an empty sram image named "trch_sram.img":
    ./sram-image-utils c trch_sram.img

To add a file, its file name and its run-time loading address must be provided:
    ./sram-image-utils a trch_sram.img u-boot.bin 0x88000000

To show the files and their load address in the sram image:
    ./sram-image-utils s trch_sram.img
