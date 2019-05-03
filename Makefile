all: bin
clean: bin-clean

bin: bin-all
bin-%:
	$(MAKE) -C bin $*
.PHONY: bin-%

sysroot: sysroot-all
sysroot-%:
	$(MAKE) -C sysroot $*
.PHONY: sysroot-%
