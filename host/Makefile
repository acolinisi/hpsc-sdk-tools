CC=gcc

all: qemu-nand-creator sram-image-utils

.PHONY: all

qemu-nand-creator: qemu-nand-creator.c
	$(CC) -O2 -g -o $@ $^

sram-image-utils: sram-image-utils.c
	$(CC) -O2 -g $(INC) $(LIB) -o $@ $^

clean:
	rm -rf *.o qemu-nand-creator sram-image-utils
