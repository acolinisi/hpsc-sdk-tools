# Relative paths to reduce duplication throughout this file
QEMU=qemu
QEMU_DT=qemu-devicetrees
HPSC_UTILS=hpsc-utils
TOOLS=$(HPSC_UTILS)/host
CONF=$(HPSC_UTILS)/conf
CONF_ZEBU=$(CONF)/zebu/hpps
CONF_PROF=$(CONF)/prof
CONF_BASE=$(CONF)/base
HPPS=hpps
RTPS=rtps
RTPS_R52=$(RTPS)/r52
RTPS_A53=$(RTPS)/a53
HPPS_ATF=$(HPPS)/arm-trusted-firmware
HPPS_UBOOT=$(HPPS)/u-boot
HPPS_LINUX=$(HPPS)/linux
HPPS_LINUX_BOOT=$(HPPS_LINUX)/arch/arm64/boot
HPPS_BUSYBOX=$(HPPS)/userspace/busybox
RTPS_R52_UBOOT=$(RTPS_R52)/u-boot
RTPS_A53_UBOOT=$(RTPS_A53)/u-boot
RTPS_A53_ATF=$(RTPS_A53)/arm-trusted-firmware
BARE_METAL=hpsc-baremetal

# Directory for artifacts created by this top-level build
BLD=bld
BLD_PROF=$(BLD)/prof
BLD_ZEBU=$(BLD)/zebu
BLD_QEMU=$(BLD)/qemu

UBOOT_TOOLS=$(HPPS_UBOOT)/tools

# Toolchain for bare-metal. Ok if does not support for userspace, e.g.
# aarch64-linux- from pre-built toolchains distributed at kernel.org
CROSS_A53=aarch64-linux-gnu-
# Toolchain for Linux userspace
CROSS_A53_LINUX=aarch64-linux-gnu-
CROSS_R52=arm-none-eabi-
CROSS_M4=arm-none-eabi-

# Settings for build artifacts produced by this top-level builder
HPPS_KERN_LOAD_ADDR=0x8068_0000 # (base + TEXT_OFFSET), where base must be aligned to 2MB
HPPS_DRAM_ADDR=0x8000_0000
HPPS_UBOOT_ENV_SIZE=0x1000 # must match CONFIG_ENV_SIZE in u-boot config

# Build Qemu s.t. its GDB stub points to the given target CPU cluster:
# TRCH=0, RTPS_R52=1, RTPS_A53=2, HPPS=3
QEMU_GDB_TARGET_CLUSTER=3

HPPS_ZEBU_DDR_IMAGE_INDEXES=0 1
HPPS_ZEBU_DDR_IMAGES=$(BLD_ZEBU)/hpps/ddr0.bin $(BLD_ZEBU)/hpps/ddr1.bin

# Address parsing function, takes addresses with _ separators
addr=$(subst _,,$1)

# Shortcut aliases
#
# Note: all clean targets here are hardest cleans, and all builds are full,
# e.g. including regeneration of config, if you want any other clean or partial
# build, then use the build system of the respective component directly.

all: qemu qdt target
clean: clean-qemu clean-qdt clean-target

target: trch rtps hpps
clean-target: clean-trch clean-rtps clean-hpps
.PHONY: target clean-target

trch: trch-bm
clean-trch: clean-trch-bm
.PHONY: trch clean-trch

rtps: rtps-r52 rtps-a53 rtps-bm
clean-rtps: clean-rtps-r52 clean-rtps-a53 clean-rtps-r52-bm
.PHONY: rtps clean-rtps

hpps: hpps-atf hpps-uboot hpps-linux hpps-initramfs
clean-hpps: clean-hpps-atf clean-hpps-uboot clean-hpps-linux \
	clean-hpps-busybox clean-hpps-initramfs
.PHONY: hpps clean-hpps

rtps-r52: rtps-r52-uboot rtps-r52-bm
clean-rtps-r52: clean-rtps-r52-uboot clean-rtps-r52-bm
.PHONY: rtps-r52 clean-rtps-r52

rtps-a53: rtps-a53-atf rtps-a53-uboot
clean-rtps-a53: clean-rtps-atf clean-rtps-a53-uboot
.PHONY: rtps-a53 clean-rtps-a53

bm: trch-bm rtps-r52-bm
clean-bm: clean-trch-bm clean-rtps-r52-bm
.PHONY: bm clean-bm

$(BLD)/%/:
	mkdir -p "$@"
.PRECIOUS: $(BLD)/%/

# Invariant: artifacts have a unique recipe. That unique recipe may part of two
# different dependency trees: (A) the dependency tree for the user interface
# target (aka. an alias), or (B) the dependency tree of another artifact (e.g.
# a memory image). Also we have the requirement that rule for nested artifacts
# trigger the nested dependency build. This won't happen if the rule here
# depends on the artifact (the dep tree would be truncated at that artifact --
# if it exists, no recipe will be invoked, even if its dependencies in the
# nested tree are stale).
#
# This invariant plus the requirements determines the pattern: the recipe for
# invoking the nested dependency building for a nested artifact is associated
# with a phony target. Then, both the user-facing alias (case A) and the
# artifact (case B) both depend on that phony target. Most often there's no
# alias (case A) because the phony target is short enough to be user-facing.
#
# Another non-way to satisfy invariant+requirement would be to use only the
# phony targets for the artifacts here (i.e. eliminate Case B rule), but this
# hinders rule legibility because dependencies can no longer be explicit
# artifacts (they are phony targets) and the recipies can no longer refer to
# dependencies (e.g. via $<).

QEMU_ARGS=CFLAGS+=-DGDB_TARGET_CLUSTER=$(QEMU_GDB_TARGET_CLUSTER)
$(BLD_QEMU)/aarch64-softmmu/qemu-system-aarch64: qemu

$(BLD_QEMU)/config.status: | $(BLD_QEMU)/
	cd $(BLD_QEMU) && ../../$(QEMU)/configure \
		--target-list=aarch64-softmmu --enable-fdt \
		--disable-kvm --disable-xen --enable-debug
qemu: $(BLD_QEMU)/config.status
	$(MAKE) -C $(BLD_QEMU) $(QEMU_ARGS)
clean-qemu:
	$(MAKE) -C $(BLD_QEMU) $(QEMU_ARGS) clean
.PHONY: qemu clean-qemu

QDT_ARGS=
$(QEMU_DT)/LATEST/SINGLE_ARCH/hpsc-arch.dtb: qdt
qdt:
	$(MAKE) -C $(QEMU_DT) $(QDT_ARGS)
clean-qdt:
	$(MAKE) -C $(QEMU_DT) $(QDT_ARGS) clean
.PHONY: qdt clean-qdt

TRCH_BM_ARGS=
$(BARE_METAL)/trch/bld/trch.elf: trch-bm
trch-bm:
	$(MAKE) -C $(BARE_METAL)/trch$(TRCH_BM_ARGS) CROSS_COMPILE=$(CROSS_M4)
clean-trch-bm:
	$(MAKE) -C $(BARE_METAL)/trch$(TRCH_BM_ARGS) clean
.PHONY: trch-bm clean-trch-bm

RTPS_R52_BM_ARGS=
$(BARE_METAL)/rtps/bld/rtps.uimg: rtps-bm
rtps-r52-bm:
	$(MAKE) -C $(BARE_METAL)/rtps $(RTPS_R52_BM_ARGS) CROSS_COMPILE=$(CROSS_R52)
clean-rtps-r52-bm:
	$(MAKE) -C $(BARE_METAL)/rtps $(RTPS_R52_BM_ARGS) clean
.PHONY: rtps-r52-bm clean-rtps-r52-bm

RTPS_R52_UBOOT_ARGS=CROSS_COMPILE=$(CROSS_R52)
$(RTPS_R52_UBOOT)/.config: $(RTPS_R52_UBOOT)/configs/hpsc_rtps_r52_defconfig
	$(MAKE) -C $(RTPS_R52_UBOOT)$(RTPS_R52_UBOOT_ARGS) hpsc_rtps_r52_defconfig
$(RTPS_R52_UBOOT)/u-boot.bin: rtps-r52-uboot
rtps-r52-uboot: $(RTPS_R52_UBOOT)/.config
	$(MAKE) -C $(RTPS_R52_UBOOT)$(RTPS_R52_UBOOT_ARGS) u-boot.bin
clean-rtps-r52-uboot:
	$(MAKE) -C $(RTPS_R52_UBOOT)$(RTPS_R52_UBOOT_ARGS) clean
	rm -f $(RTPS_R52_UBOOT)/.config
.PHONY: rtps-r52-uboot clean-rtps-r52-uboot

RTPS_A53_UBOOT_ARGS=CROSS_COMPILE=$(CROSS_A53)
$(RTPS_A53_UBOOT)/.config: $(RTPS_A53_UBOOT)/configs/hpsc_rtps_a53_defconfig
	$(MAKE) -C $(RTPS_A53_UBOOT) $(RTPS_A53_UBOOT_ARGS) hpsc_rtps_a53_defconfig
$(RTPS_A53_UBOOT)/u-boot.bin: rtps-a53-uboot
rtps-a53-uboot: $(RTPS_A53_UBOOT)/u-boot.bin
	$(MAKE) -C $(RTPS_A53_UBOOT) $(RTPS_A53_UBOOT_ARGS) u-boot.bin
clean-rtps-a53-uboot:
	$(MAKE) -C $(RTPS_A53_UBOOT) $(RTPS_A53_UBOOT_ARGS) clean
	rm -f $(RTPS_A53_UBOOT)/.config
.PHONY: rtps-a53-uboot clean-rtps-a53-uboot

RTPS_A53_ATF_ARGS=PLAT=hpsc_rtps_a53 DEBUG=1 CROSS_COMPILE=$(CROSS_A53)
$(RTPS_A53_ATF)/build/hpsc_rtps_a53/debug/bl31.bin: rtps-a53-atf
rtps-a53-atf:
	$(MAKE) -C $(RTPS_A53_ATF) $(RTPS_A53_ATF_ARGS) bl31
clean-rtps-a53-atf:
	$(MAKE) -C $(RTPS_A53_ATF) $(RTPS_A53_ATF_ARGS) clean
.PHONY: rtps-a53-atf clean-rtps-a53-atf

HPPS_ATF_ARGS=PLAT=hpsc DEBUG=1 CROSS_COMPILE=$(CROSS_A53)
$(HPPS_ATF)/build/hpsc/debug/bl31.bin: hpps-atf
hpps-atf:
	$(MAKE) -C $(HPPS_ATF) $(HPPS_ATF_ARGS) bl31
clean-hpps-atf:
	$(MAKE) -C $(HPPS_ATF) $(HPPS_ATF_ARGS) clean
.PHONY: hpps-atf clean-hpps-atf

HPPS_UBOOT_ARGS=CROSS_COMPILE=$(CROSS_A53)
$(HPPS_UBOOT)/.config: $(HPPS_UBOOT)/configs/hpsc_hpps_defconfig
	$(MAKE) -C $(HPPS_UBOOT) $(HPPS_UBOOT_ARGS) hpsc_hpps_defconfig
$(HPPS_UBOOT)/u-boot.bin: $(HPPS_UBOOT)/.config
	$(MAKE) -C $(HPPS_UBOOT) $(HPPS_UBOOT_ARGS) u-boot.bin
$(HPPS_UBOOT)/u-boot.dtb: $(HPPS_UBOOT)/u-boot.bin
	$(MAKE) -C $(HPPS_UBOOT) $(HPPS_UBOOT_ARGS) u-boot.dtb
$(HPPS_UBOOT)/tools/mkenvimage:
	$(MAKE) -C $(HPPS_UBOOT) $(HPPS_UBOOT_ARGS) tools
clean-hpps-uboot: clean-hpps-uboot-env
	$(MAKE) -C $(HPPS_UBOOT) $(HPPS_UBOOT_ARGS) clean
	rm -f $(HPPS_UBOOT)/.config
$(BLD)/hpps/uboot.env.bin: $(CONF_BASE)/hpps/u-boot/uboot.env \
	| $(UBOOT_TOOLS)/mkenvimage
	$(call make-uboot-env,$(HPPS_UBOOT_ENV_SIZE))

# The following recipe is only used when the user invokes the phony target
# explicitly. This recipe forces the nested dependency build.  The above
# non-phony recipes are shallow and do not force a dependency build.
#
# The pattern of invoking ourselves from the recipe (to build the artifact that
# depends on the nested build) is explained below near the linux targets, where
# the same situation is encountered as here. env.bin can't be a dep of hpps-uboot,
# because that would allow multiple concurrent invocations of the nested build.
hpps-uboot: $(HPPS_UBOOT)/.config
	$(MAKE) -C $(HPPS_UBOOT) $(HPPS_UBOOT_ARGS)
	$(MAKE) $(BLD)/hpps/uboot.env.bin

hpps-uboot-env: $(BLD)/hpps/uboot.env.bin
clean-hpps-uboot-env:
	rm -f $(BLD)/hpps/uboot.env.bin
.PHONY: hpps-uboot clean-hpps-uboot hpps-uboot-env clean-hpps-uboot-env

HPPS_LINUX_ARGS=ARCH=arm64 CROSS_COMPILE=$(CROSS_A53)
$(HPPS_LINUX)/.config: $(HPPS_LINUX)/arch/arm64/configs/hpsc_defconfig
	$(MAKE) -C $(HPPS_LINUX) $(HPPS_LINUX_ARGS) hpsc_defconfig

$(HPPS_LINUX_BOOT)/Image: $(HPPS_LINUX)/.config
	$(MAKE) -C $(HPPS_LINUX) $(HPPS_LINUX_ARGS) Image

# Note: need to sequence, otherwise whether we have two targets at same
# priority or we have one recipe with multiple artifacts, in both cases will be
# broken with parallel make. We do want explicit references to both artifacts
# in this makefile though, because they both participate in images.
$(HPPS_LINUX_BOOT)/dts/hpsc/hpsc.dtb: $(HPPS_LINUX_BOOT)/Image.gz
	$(MAKE) -C $(HPPS_LINUX) $(HPPS_LINUX_ARGS) hpsc/hpsc.dtb

$(BLD)/hpps/uImage: $(HPPS_LINUX_BOOT)/Image.gz | $(BLD)/hpps/
	mkimage -T kernel -C gzip -A arm64 -d "$<" -a $(call addr,${HPPS_KERN_LOAD_ADDR}) "$@"

# The make command in this recipe is only used for the invocation from the user
# interface (via hpps-linux phony target shortcut), but not from the dependency
# build of another artifact, for which the above recipes are used (a violation
# of the invariant above). The non-phony rules (above) define a shallow
# dependency graph which is disconnected from the nested dependency graph
# (modifying kernel.c will not cause uImage to be remade).  Hence, the phony
# target (hpps-linux) below gives the user a convenience way to force the
# nested dependency build.
#
# The implementation of this conenience must not allow the nested dependency
# build to be invoked concurrently multiple times, because that breaks the
# build (it's in the same directory; even if the root targets of each
# invocation differ, their dependencies may be shared and thus built twice
# concurrently on top of each other).
#
# The non-working approach is a master target that would depend on two targets,
# (1) a target that invokes the nested dependency build (waht hpps-linux does),
# and (2) build uImage (which itself depends on the nested build again). For
# (1) we would want to depend on the phony hpps-linux and not on Image.gz,
# because the latter is shallow. This master target won't work because the
# nested build recipe is present twice in the dependency subgraph of the master
# target, which allows the nested build to be invoked concurrently.
#
# The solution is to sequence the nested builds. This can be done in one
# of two ways: (A) invoke ourselves in the recipe that invokes the nested
# build (after that nested build command); or (B) define a chain of phony
# targets each of which invokes the nested build all are strictly ordered
# (hpps-linux-all -> hpps-linux-img -> hpps-linux). (B) requires having the
# same commands in the phony and non-phony recipe (for the commands that are
# not the nested build commands (e.g. build uImage), which is best done by
# factoring the commands into functions. We choose (A).
hpps-linux: $(HPPS_LINUX)/.config
	$(MAKE) -C $(HPPS_LINUX) $(HPPS_LINUX_ARGS)
	$(MAKE) $(BLD)/hpps/uImage
clean-hpps-linux:
	$(MAKE) -C $(HPPS_LINUX) $(HPPS_LINUX_ARGS) mrproper
	rm -f $(BLD)/hpps/uImage
.PHONY: hpps-linux clean-hpps-linux


HPPS_BUSYBOX_ARGS=CROSS_COMPILE=$(CROSS_A53_LINUX)
$(HPPS_BUSYBOX)/.config: $(CONF_BASE)/hpps/busybox/hpsc_hpps_miniconf
	$(MAKE) -C $(HPPS_BUSYBOX) $(HPPS_BUSYBOX_ARGS) \
		allnoconfig KCONFIG_ALLCONFIG="$(abspath $<)"
$(HPPS_BUSYBOX)/busybox: hpps-busybox
hpps-busybox: $(HPPS_BUSYBOX)/.config
	$(MAKE) -C $(HPPS_BUSYBOX) $(HPPS_BUSYBOX_ARGS)
clean-hpps-busybox:
	$(MAKE) -C $(HPPS_BUSYBOX) $(HPPS_BUSYBOX_ARGS) clean
	rm -f $(HPPS_BUSYBOX)/.config
.PHONY: hpps-busybox clean-hpps-busybox

$(BLD)/hpps/initramfs.cpio: | $(BLD)/hpps/
	$(call copy-initramfs,$(CONF_BASE)/hpps/initramfs)
	$(call init-initramfs,$(CONF_BASE)/hpps/initramfs.sh)
	$(call make-initramfs,$(HPPS_BUSYBOX),$(HPPS_BUSYBOX_ARGS))

# Could use the generic target, but then need names *.hpps-initramfs.*
$(BLD)/hpps/initramfs.uimg : $(BLD)/hpps/initramfs.cpio.gz
	$(call pack-hpps-initramfs)

hpps-initramfs: $(BLD)/hpps/initramfs.uimg
clean-hpps-initramfs:
	$(call clean-initramfs,$(BLD)/hpps/initramfs)
.PHONY: hpps-initramfs clean-hpps-initramfs

# The following targets define profiles

# default profile

prof-default: $(BLD_PROF)/default/hpps/initramfs.uimg
.PHONY: prof-default

PROFILES_WITH_ZEBU+=default

# ftrace-extractor profile

$(BLD_PROF)/ftrace-extractor/qemu/prof.qemu.dts: \
	$(QEMU_DT)/hpsc-arch.dts \
	$(CONF_BASE)/qemu/dt/hpps-ddr-high-1.dts

$(BLD_PROF)/ftrace-extractor/hpps/prof.hpps-uboot.dts: \
	$(HPPS_UBOOT)/arch/arm/dts/hpsc-hpps.dts \
	$(CONF_BASE)/hpps/u-boot/dt/hpps-ddr-high-1.dts

$(BLD_PROF)/ftrace-extractor/hpps/prof.hpps-linux.dts: \
	$(HPPS_LINUX_BOOT)/dts/hpsc/hpsc.dts \
	$(CONF_BASE)/hpps/linux/dt/gp-mem.dts

prof-ftrace-extractor: \
	$(BLD_PROF)/ftrace-extractor/qemu/prof.qemu.dtb \
	$(BLD_PROF)/ftrace-extractor/hpps/initramfs.uimg \
	$(BLD_PROF)/ftrace-extractor/hpps/prof.hpps-linux.dtb \
	$(BLD_PROF)/ftrace-extractor/hpps/prof.hpps-uboot.dtb

# hpps booti profile

prof-hpps-booti: \
	$(BLD_PROF)/hpps-booti/hpps/prof.hpps-uboot.env.bin

PROFILES_WITH_ZEBU+=hpps-booti

# Targets that implement profiles (generic as a function of profile)

.PHONY: prof-%

clean-prof-%:
	rm -rf $(BLD_PROF)/$*/
.PHONY: clean-prof-%
clean-hpps-initramfs-prof-%:
	$(call clean-initramfs,$(BLD_PROF)/$*/hpps/initramfs)
.PHONY: clean-hpps-initramfs-prof-%

# Note the empty recipe. Not sure why it does not work without it.
prof-%-zebu-hpps: prof-% $(BLD_PROF)/%/zebu/prof.hpps.zebu.mem.bin
# Enable the following to also generate striped images (.bin or .vhex)
# prof-%-zebu-hpps: $(BLD_PROF)/%/zebu/prof.hpps.zebu.x.ddr.bin
	
.PHONY: prof-%-zebu-hpps
clean-prof-%-zebu-hpps:
	rm -rf $(BLD_PROF)/$*/zebu/prof.hpps.zebu.{mem.bin,*.ddr.bin,mem.rule} \
		$(BLD_PROF)/$*/zebu/hpps.{mem.map,mem.dep,zebu}
.PHONY: prof-%-zebu-hpps clean-prof-%-zebu-hpps

$(BLD_PROF)/%.dts: | $(BLD_PROF)/
	mkdir -p $(@D)
	cat $^ > $@

$(BLD_PROF)/%/hpps/prof.hpps-uboot.env: \
	$(CONF_BASE)/hpps/u-boot/uboot.env \
	$(CONF_PROF)/%/hpps/u-boot/uboot.env \
	| $(BLD_PROF)/%/hpps/
	$(TOOLS)/merge-env $^ > $@

$(BLD_PROF)/%/zebu/prof.hpps.mem.map: \
	$(CONF_BASE)/zebu/hpps-mem.map \
	$(CONF_PROF)/%/zebu/hpps-mem.map \
	| $(BLD_PROF)/%/zebu/
	$(TOOLS)/merge-map $^ > $@

$(BLD_PROF)/%/hpps/initramfs.cpio: | $(BLD_PROF)/%/hpps/
	$(call copy-initramfs,$(CONF_BASE)/hpps/initramfs)
	[ ! -d "$(CONF_PROF)/$*/hpps/initramfs/" ] || \
		$(call copy-initramfs,$(CONF_PROF)/$*/hpps/initramfs)
	$(call init-initramfs,$(CONF_BASE)/hpps/initramfs.sh)
	[ ! -f "$(CONF_PROF)/$*/hpps/initramfs.sh" ] || \
		$(call init-initramfs,$(CONF_PROF)/$*/hpps/initramfs.sh)
	$(call make-initramfs,$(HPPS_BUSYBOX),$(HPPS_BUSYBOX_ARGS))

# Could use the generic target, but then need names *.hpps-initramfs.*
$(BLD_PROF)/%/hpps/initramfs.uimg: $(BLD_PROF)/%/hpps/initramfs.cpio.gz
	$(call pack-hpps-initramfs)

ifeq ($(filter clean-%,$(MAKECMDGOALS)),)
ifneq ($(findstring zebu,$(MAKECMDGOALS)),)
$(info INCLUDE $(foreach prof,$(PROFILES_WITH_ZEBU),\
		$(BLD_PROF)/$(prof)/zebu/prof.hpps.zebu.mem.rule))
-include $(foreach prof,$(PROFILES_WITH_ZEBU),\
		$(BLD_PROF)/$(prof)/zebu/prof.hpps.zebu.mem.rule)
endif
endif

# Extract dependencies from a memory map file into a rule file
%.mem.dep: %.mem.map
	$(TOOLS)/mkmemimg -l $< > $@

%.zebu.mem.rule: %.mem.dep
	sed 's#^#$(patsubst %.rule,%.bin,$@): #' $< > $@

%.zebu.mem.bin: %.mem.map
	$(TOOLS)/mkmemimg $< $@

# The touch is a workaround for .INTERMEDIATE not accepting patterns,
# otherwise, we would mark the master target intermediate without a real file.
define zebu-stripe-ddr
	$(TOOLS)/memstripe --base $(1) -i $< \
		$(foreach idx,$(2),$(patsubst %.x.ddr.bin,%.$(idx).ddr.bin,$@))
	touch $@
endef

# Note the empty recipe. Not sure why it doesn't work without it, but
# it has to do with the pattern, because without a pattern, it works
define zebu-ddr-rule
%.$(1).zebu.$(2).ddr.bin: %.$(1).zebu.x.ddr.bin
	
endef

%.hpps.zebu.x.ddr.bin: %.hpps.zebu.mem.bin
	$(call zebu-stripe-ddr,$(HPPS_DRAM_ADDR),$(HPPS_ZEBU_DDR_IMAGE_INDEXES))
#.INTERMEDIATE: %.hpps.zebu.x.ddr.bin # patterns do not work here (use touch+PRECIOUS)
.PRECIOUS: %.hpps.zebu.x.ddr.bin
$(foreach idx,$(HPPS_ZEBU_DDR_IMAGE_INDEXES),$(eval $(call zebu-ddr-rule,hpps,$(idx))))

%.vhex: %.bin
	$(TOOLS)/hpsc-objcopy -I binary -O Verilog-H $< $@

%.gz: %
	gzip -c -9 "$<" > "$@"

%.qemu.dtb: %.qemu.dts
	$(call dt-rule,-I$(QEMU_DT))

%.hpps-uboot.dtb: %.hpps-uboot.dts
	$(call dt-rule,-I$(HPPS_UBOOT)/arch/arm/dts \
		-I$(HPPS_UBOOT)/arch/arm/dts/include -I$(HPPS_UBOOT)/include)

%.hpps-linux.dtb: %.hpps-linux.dts
	$(call dt-rule,-I$(HPPS_LINUX)/include -I$(HPPS_LINUX_BOOT)/dts/hpsc)

%.dtb: %.dts
	$(call dt-rule,)

define dt-rule
	$(CC) -E -nostdinc -x assembler-with-cpp $(1) -o - $< | \
		dtc -q -I dts -O dtb -o $@ -
endef

%.hpps-uboot.env.bin: %.hpps-uboot.env | $(UBOOT_TOOLS)/mkenvimage
	$(call make-uboot-env,$(HPPS_UBOOT_ENV_SIZE))

define make-uboot-env
	$(UBOOT_TOOLS)/mkenvimage -s $(1) -o $@ $<
endef

IRF_FR=initramfs.fakeroot
define copy-initramfs
	rsync -aq $(1)/ $(@D)/initramfs
endef
define init-initramfs
	( cd $(@D)/initramfs && fakeroot -s ../$(IRF_FR) $(abspath $(1)) )
endef
define make-initramfs
	fakeroot -i $(@D)/$(IRF_FR) -s $(@D)/$(IRF_FR) \
		$(MAKE) -j1 -C $(1) $(2) \
			CONFIG_PREFIX="$(abspath $(@D)/initramfs)" install
	cd $(@D)/initramfs && find . | fakeroot -i ../$(IRF_FR) -s $(IRF_FR) \
		cpio -R root:root -c -o -O "../$(@F)"
endef
define pack-initramfs
	mkimage -T ramdisk -C gzip -A $(1) -n "Initramfs" -d "$<" "$@"
endef
define clean-initramfs
	rm -rf $(1){/,.uimg,.cpio,.cpio.gz,.fakeroot}
endef

define pack-hpps-initramfs
	$(call pack-initramfs,arm64)
endef

# Currently unused, but ideally, for consistency, would rename artifacts and
# eliminated targets that casll the same recipe in favor of this target.
%.hpps-initramfs.uimg: %.hpps-initramfs.cpio.gz
	$(call pack-hpps-initramfs)

# Prevent deletion of intermediate artifacts
.SECONDARY:
