# Recipes to create a sysroot with dependencies of the HPSC SDK
#
# Only needed if system (the OS distribution) cannot provide up-to-date
# versions of these dependencies, as may happen when working without root
# privileges. Often, a system may provide the library binary, but not its
# development headers, which are needed to build against that library.
#
# These recipes provides the same functionality as the Poky SDK installer
# could/should (once it is complete) -- with the difference of context: not for
# distributing the SDK but for building and using the SDK from its source tree.
#
# Another difference, which is a corrolary of the above difference in usage
# context: Poky's sysroot is exhaustive (it eliminates absolutely all
# dependencies on any system libraries), while this Makefile's sysroot does
# depend on at least some system libraries and binaries. This is indended,
# because when developing the SDK, we want to run it on the system, and the
# only reason we provide a sysroot is only for the case when something prevents
# the developer from installing the dependencie into the system (e.g. no root,
# and/or system-provided packages are out-of-date and no updates are
# available).

all: tools libs py env

BLD=bld

# Actual sysroot will be created here
SYSROOT=$(BLD)/sysroot

FETCH=$(BLD)/fetch
FETCH_CACHE?=$(FETCH)
WORK=$(BLD)/work

PREFIX=$(SYSROOT)/usr
HPREFIX=$(abspath $(PREFIX))

BIN=$(PREFIX)/bin
PC=$(PREFIX)/lib/pkgconfig
PC64=$(PREFIX)/lib64/pkgconfig

# Tools required for building the SDK:
# ... provided by the system
WGET=wget
TAR=tar
UNZIP=unzip
# ... built while building the SDK (must be absolute paths, not via $(BIN))
FAKEROOT=$(HPREFIX)/bin/fakeroot
PYTHON=$(HPREFIX)/bin/python3

PYTHON_SITE_REL=$(PREFIX)/lib/python$(VER_MAJMIN_python)/site-packages
PYTHON_SITE=$(abspath $(PYTHON_SITE_REL))

define ENV=
# Auto-generated SDK environment file
HPREFIX=$(abspath $(SYSROOT))/usr
export PATH=$$HPREFIX/sbin:$$HPREFIX/bin:$$PATH
export PYTHONPATH=$(PYTHON_SITE):$$PYTHONPATH
export LD_LIBRARY_PATH=$$HPREFIX/lib64:$$HPREFIX/lib
export PKG_CONFIG_PATH=$$HPREFIX/lib64/pkgconfig:$$HPREFIX/lib/pkgconfig
endef

ENV_FILE=$(BLD)/env.sh
env: $(ENV_FILE)
$(ENV_FILE): export ENV_SH=$(ENV)
$(ENV_FILE):
	echo "$$ENV_SH" > $@
env-clean:
	rm -f $(ENV_FILE)
.PHONY: env env-clean

# Note: the identifiers need to be unique across this whole file, including
# across separate categories, but the tarballs and build directories may have
# the same name as long as they are in different categories.

# Reason for dependency in recorded in target definitions
DEPS_LIB=\
	attr \
	libcap2 \
	util_linux \
	pcre \
	libffi \
	glib \
	pixman \
	sqlite \
	ncurses \
	openssl \
	curl \

# Tools
#
# fakeroot: for building some deps here, and for initramfs building
# dtc: for non-nested device tree builds (nested repos usually provide dtc)
# screen: for connecting to serial ports
# git: for work with repos (optional)
#
DEPS_TOOL=\
	fakeroot \
	dtc \
	screen \
	git \
	python \
	texinfo \
	uboottools \
	make \

# Python packages
#
# setuptools: for installing any other python packages
# configparser: for manipulating INI config files
# argparse: CLI in various tools
# pprint: JSON formatting used in some tools
#
DEPS_PY=\
	setuptools \
	argparse \
	configparser \
	pprint \

DEPS_NATIVE=$(DEPS_LIB) $(DEPS_TOOL)
DEPS=$(DEPS_NATIVE) $(DEPS_PY)

# Versions (also, comment here due to line continuations being in the way above)
VER_attr=2.4.48
VER_libcap2=2.24
VER_fakeroot=1.23
VER_MAJMIN_util_linux=2.33
VER_PATCH_util_linux=1
VER_util_linux=$(VER_MAJMIN_util_linux).$(VER_PATCH_util_linux)
VER_pcre=8.42
VER_libffi=3.2.1
VER_MAJMIN_glib=2.54
VER_PATCH_glib=3
VER_glib=$(VER_MAJMIN_glib).$(VER_PATCH_glib)
VER_pixman=0.38.0
VER_sqlite=3.28.0
VER_sqlite_NUM=3280000
VER_dtc=1.5.0
VER_ncurses=6.1
VER_openssl=1.1.1b
VER_curl=7.64.1
VER_screen=4.6.2
VER_git=2.21.0
VER_MAJMIN_python=3.7
VER_PATCH_python=3
VER_python=$(VER_MAJMIN_python).$(VER_PATCH_python)
VER_texinfo=6.6
VER_uboottools=2019.01
VER_make=4.2

# Python packages
VER_setuptools=40.8.0
VER_argparse=1.4.0
VER_pprint=0.1
VER_configparser=3.7.4

# Tarball name: default to "name-ver.tar.gz", and override the exceptions
$(foreach d,$(DEPS),$(eval TARBALL_$(d)=$(d)-$(VER_$(d)).tar.gz))
TARBALL_libcap2=libcap2_$(VER_libcap2).orig.tar.xz
TARBALL_fakeroot=fakeroot_$(VER_fakeroot).orig.tar.xz
TARBALL_util_linux=util-linux-$(VER_util_linux).tar.xz
TARBALL_pcre=pcre-$(VER_pcre).tar.bz2
TARBALL_glib=glib-$(VER_glib).tar.xz
TARBALL_sqlite=sqlite-autoconf-$(VER_sqlite_NUM).tar.gz
TARBALL_git=git-$(VER_git).tar.xz
TARBALL_setuptools=setuptools-$(VER_setuptools).zip
TARBALL_python=Python-$(VER_python).tar.xz
TARBALL_uboottools=u-boot-$(VER_uboottools).tar.bz2

# Filename in URL: default to TARBALL name, and override exceptions
$(foreach d,$(DEPS),$(eval FNAME_$(d)=$(TARBALL_$(d))))
#FNAME_setuptools=v$(VER_setuptools).tar.gz

# Name of directory in tarball: default to "name-ver", and override exceptions
$(foreach d,$(DEPS),$(eval DIR_$(d)=$(d)-$(VER_$(d))))
DIR_util_linux=util-linux-$(VER_util_linux)
DIR_sqlite=sqlite-autoconf-$(VER_sqlite_NUM)
DIR_python=Python-$(VER_python)
DIR_uboottools=u-boot-$(VER_uboottools)

URL_attr=http://download.savannah.nongnu.org/releases/attr
URL_libcap2=http://ftp.debian.org/debian/pool/main/libc/libcap2
URL_fakeroot=http://deb.debian.org/debian/pool/main/f/fakeroot
URL_util_linux=https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v$(VER_MAJMIN_util_linux)
URL_pcre=https://ftp.pcre.org/pub/pcre
URL_libffi=ftp://sourceware.org/pub/libffi
URL_glib=http://ftp.gnome.org/pub/gnome/sources/glib/$(VER_MAJMIN_glib)
URL_pixman=https://www.cairographics.org/releases
URL_sqlite=https://www.sqlite.org/2019
URL_dtc=https://git.kernel.org/pub/scm/utils/dtc/dtc.git/snapshot
URL_ncurses=https://invisible-mirror.net/archives/ncurses
URL_openssl=https://www.openssl.org/source
URL_curl=https://curl.haxx.se/download
URL_screen=https://ftp.gnu.org/gnu/screen
URL_git=https://mirrors.edge.kernel.org/pub/software/scm/git
URL_python=https://www.python.org/ftp/python/$(VER_python)
URL_texinfo=https://ftp.gnu.org/gnu/texinfo
URL_uboottools=ftp://ftp.denx.de/pub/u-boot
URL_make=https://ftp.gnu.org/gnu/make

# Default to downloading from PyPI, but should there be any exceptions, simply
# define their respective URL vars below.
$(foreach p,$(DEPS_PY),\
	$(eval URL_$(p)=https://pypi.io/packages/source/$(shell echo $(p) | head -c 1)/$(p)))

# Artifacts in order to be able to define a dep tree (required for each dep)
ART_attr=$(PC)/libattr.pc
ART_libcap2=$(PC64)/libcap.pc
ART_util_linux=$(PC)/mount.pc
ART_pcre=$(PC)/libpcre.pc
ART_libffi=$(PC)/libffi.pc
ART_glib=$(PC)/glib-2.0.pc
ART_pixman=$(PC)/pixman-1.pc
ART_sqlite=$(PC)/sqlite3.pc
ART_ncurses=$(PC)/ncurses.pc
ART_openssl=$(PC64)/openssl.pc
ART_curl=$(PC)/libcurl.pc

ART_fakeroot=$(BIN)/fakeroot
ART_dtc=$(BIN)/dtc
ART_screen=$(BIN)/screen
ART_git=$(BIN)/git
ART_python=$(BIN)/python3
ART_texinfo=$(BIN)/makeinfo
ART_uboottools=$(BIN)/mkimage
ART_make=$(BIN)/make

# For python packages artifacts are standard, but any exceptions can override
$(foreach p,$(DEPS_PY),\
	$(eval ART_$(p)=$(PYTHON_SITE_REL)/$(p)-$(VER_$(p))-py$(VER_MAJMIN_python).egg))

libs: $(DEPS_LIB)
tools: $(DEPS_TOOL)
py: $(DEPS_PY)
py-clean: $(foreach d,$(DEPS_PY),$(d)-clean)

fetch: $(foreach d,$(DEPS),$(FETCH)/$(TARBALL_$(d)))

%/ :
	mkdir -p $@

# don't clean fetched tarballs unless explicitly requested
clean: sysroot-clean env-clean bld-clean
.PHONY: clean

sysroot-clean:
	rm -rf $(SYSROOT)/
.PHONY: sysroot-clean

bld-clean:
	rm -rf $(WORK)/
bld-%-clean:
	rm -f $(WORK)/$(DIR_$*)
fetch-clean:
	rm -rf $(FETCH)/
fetch-%-clean:
	rm -f $(FETCH)/$(TARBALL_$*)
.PHONY: bld-clean bld-%-clean fetch-clean fetch-%-clean

define fetch-rule
fetch: $(FETCH)/$(TARBALL_$(1))
$(FETCH_CACHE)/$(TARBALL_$(1)): | $(FETCH_CACHE)/
	$(WGET) --no-verbose -O $$@ $(URL_$(1))/$(FNAME_$(1))
.INTERMEDIATE: $(FETCH_CACHE)/$(TARBALL_$(1))
.SECONDARY: $(FETCH_CACHE)/$(TARBALL_$(1))
endef

# We make a copy, so that we're self-sufficient in case FETCH_CACHE goes away
ifneq ($(FETCH),$(FETCH_CACHE))
$(FETCH)/%: $(FETCH_CACHE)/% | $(FETCH)/
	cp $< $@
endif
.SECONDARY: $(FETCH)/

# touch the directory, since the timestamp of the dir in tar may be stored and
# it will be older than the tarball, which would cause the target to be remade.
define extract-rule-tar
$(3)/$(DIR_$(1)): $(2)/$(TARBALL_$(1)) | $(3)/
	$(TAR) -C $(3) -x -f $$<
	touch $$@
endef

define extract-rule-zip
$(3)/$(DIR_$(1)): $(2)/$(TARBALL_$(1)) | $(3)/
	cd $(3) && $(UNZIP) -o -q $(abspath $$<)
endef

define clean-rule
$(1)-clean:
	rm -rf $(WORK)/$(DIR_$(1)) $(ART_$(1))
endef

$(foreach d,$(DEPS),\
	$(eval $(call fetch-rule,$(d)))\
	$(eval $(call clean-rule,$(d))))

DEPS_TAR=$(foreach d,$(DEPS),\
	$(if $(filter %.tar.gz %.tar.xz %.tar.bz2 %.tar,$(TARBALL_$(d))),$(d),))
DEPS_ZIP=$(foreach d,$(DEPS),\
	$(if $(filter %.zip,$(TARBALL_$(d))),$(d),))

$(foreach d,$(filter $(DEPS),$(DEPS_TAR)),\
	$(eval $(call extract-rule-tar,$(d),$(FETCH),$(WORK))))
$(foreach d,$(filter $(DEPS),$(DEPS_ZIP)),\
	$(eval $(call extract-rule-zip,$(d),$(FETCH),$(WORK))))

# Make extract target a prereq of build/install target
$(foreach d,$(DEPS),$(eval $(ART_$(d)): | $(WORK)/$(DIR_$(d))))

# Alias for each dependency, that points to the artifact
$(foreach d,$(DEPS),$(eval $(d): $(ART_$(d))))

# Define per-target DIR to allow recipies to be more concise
$(foreach d,$(DEPS),$(eval $(ART_$(d)): DIR=$(WORK)/$(DIR_$(d))))

PKGCFG_PATHS=$(HPREFIX)/lib64/pkgconfig:$(HPREFIX)/lib/pkgconfig

# Env vars usually respected by autoconf configure script
SYSROOT_VARS=\
	PKG_CONFIG_PATH=$(PKGCFG_PATHS) \
	LD_LIBRARY_PATH=$(HPREFIX)/lib64:$(HPREFIX)/lib \
	CFLAGS+=-I$(HPREFIX)/include \
	LDFLAGS+="-L$(HPREFIX)/lib64 -L$(HPREFIX)/lib -Wl,-rpath=$(HPREFIX)/lib64 -Wl,-rpath=$(HPREFIX)/lib" \
	PATH="$(HPREFIX)/bin:$$PATH" \

$(ART_attr):
	cd $(DIR) && $(SYSROOT_VARS) ./configure --prefix=$(HPREFIX)
	$(MAKE) -C $(DIR) install

$(ART_libcap2): $(ART_attr)
	$(MAKE) -C $(DIR) DESTDIR=$(abspath $(SYSROOT)) LDFLAGS+=-L$(HPREFIX)/lib \
		RAISE_SETFCAP=no install \

$(ART_fakeroot): $(ART_libcap2)
	cd $(DIR) && $(SYSROOT_VARS) ./configure --prefix=$(HPREFIX) 
	$(MAKE) -C $(DIR) install

$(ART_util_linux): $(ART_fakeroot)
	cd $(DIR) && $(SYSROOT_VARS) ./configure --prefix=$(HPREFIX) \
			--with-bashcompletiondir=$(HPREFIX)/share/bash-completions
	$(MAKE) -C $(DIR)
	$(FAKEROOT) $(MAKE) -C $(DIR) install

$(ART_pcre):
	cd $(DIR) && $(SYSROOT_VARS) ./configure --prefix=$(HPREFIX) \
		--enable-utf --enable-unicode-properties
	$(MAKE) -C $(DIR) install

$(ART_libffi):
	cd $(DIR) && $(SYSROOT_VARS) ./configure --prefix=$(HPREFIX)
	$(MAKE) -C $(DIR) install

$(ART_glib): $(ART_libffi) $(ART_pcre) $(ART_util_linux)
	cd $(DIR) && $(SYSROOT_VARS) ./configure --prefix=$(HPREFIX)
	$(MAKE) -C $(DIR) install

$(ART_pixman):
	cd $(DIR) && $(SYSROOT_VARS) ./configure --prefix=$(HPREFIX)
	make -C $(DIR) install

$(ART_sqlite):
	cd $(DIR) && $(SYSROOT_VARS) ./configure --prefix=$(HPREFIX)
	make -C $(DIR) install

$(ART_ncurses):
	cd $(DIR) && $(SYSROOT_VARS) ./configure --prefix=$(HPREFIX) \
		--with-pkg-config-libdir=$(HPREFIX)/lib/pkgconfig \
		--enable-pc-files --with-shared --without-ada
	$(MAKE) -C $(DIR) install

$(ART_openssl):
	cd $(DIR) && $(SYSROOT_VARS) ./config --prefix=$(HPREFIX)
	$(MAKE) -C $(DIR)
	$(MAKE) -C $(DIR) install

$(ART_dtc):
	$(MAKE) -C $(DIR) NO_PYTHON=1 PREFIX=$(HPREFIX) install

$(ART_screen): $(ART_ncurses)
	cd $(DIR) && $(SYSROOT_VARS) ./configure --prefix=$(HPREFIX)
	$(MAKE) -C $(DIR) install

$(ART_curl):
	cd $(DIR) && $(SYSROOT_VARS) ./configure --prefix=$(HPREFIX)
	$(MAKE) -C $(DIR) install

$(ART_git): $(ART_curl)
	cd $(DIR) && $(SYSROOT_VARS) ./configure --prefix=$(HPREFIX) --with-curl
	$(MAKE) -C $(DIR) install

PY_PKGCFG_DEPS=ncurses libffi
$(ART_python): $(ART_sqlite) $(ART_ncurses) $(ART_libffi)
	cd $(DIR) && $(SYSROOT_VARS) \
		CFLAGS+="$(shell PKG_CONFIG_PATH=$(PKGCFG_PATHS) pkg-config --cflags $(PY_PKGCFG_DEPS))" \
		CPPFLAGS+="$$CFLAGS" \
		LDFLAGS+="$(shell PKG_CONFIG_PATH=$(PKGCFG_PATHS) pkg-config --libs $(PY_PKGCFG_DEPS))" \
		./configure --prefix=$(HPREFIX) --enable-loadable-sqlite-extensions --enable-optimizations
	$(MAKE) -C $(DIR) install

$(ART_texinfo):
	cd $(DIR) && $(SYSROOT_VARS) ./configure --prefix=$(HPREFIX)
	$(MAKE) -C $(DIR) install

UBOOTTOOLS_VARS=HOST_EXTRACFLAGS="-I$(HPREFIX)/include"
$(ART_uboottools):
	cd $(DIR) && $(SYSROOT_VARS) $(UBOOTTOOLS_VARS) $(MAKE) defconfig
	cd $(DIR) && $(SYSROOT_VARS) $(UBOOTTOOLS_VARS) $(MAKE) tools envtools
	cd $(DIR) && install -m 755 -t "$(HPREFIX)/bin" \
		tools/{mk{,env}image,env/fw_printenv,img2srec,dumpimage,netconsole,jtagconsole,ncb}
	cd $(DIR) && ln -sf fw_printenv $(HPREFIX)/bin/fw_setenv

$(ART_make):
	cd $(DIR) && $(SYSROOT_VARS) ./configure --prefix=$(HPREFIX)
	$(MAKE) -C $(DIR) install

# Bootstrapping does not appear to be necessary
#setuptools-bootstrap:
#	cd $(WORK)/$(DIR_setuptools) && $(PYTHON) bootstrap.py
#$(ART_setuptools): setuptools-bootstrap

define py-rule
$(ART_$(1)): $(ART_python)
	cd $$(DIR) && PYTHONPATH=$(PYTHON_SITE):$(PYTHONPATH) \
		$(PYTHON) setup.py install --prefix=$(HPREFIX)
endef

$(foreach d,$(DEPS_PY),$(eval $(call py-rule,$(d))))

# All python packages depend on setuptools
$(foreach d,$(filter-out setuptools,$(DEPS_PY)),$(eval $(ART_$(d)): $(ART_setuptools)))
