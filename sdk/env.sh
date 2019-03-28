SDK_SYSROOT=$HPSC_ROOT/bld/sdk/sysroot

HPREFIX=$SDK_SYSROOT/usr

# This assumes python does not change (up to minor version) between the time
# the SDK sysroot was built and this env script is sourced. If python changes
# (e.g. due to a system update), then the SDK sysroot should be rebuilt.
PYTHON_VER="$(python2 -V 2>&1 | cut -d' ' -f2 | cut -d'.' -f1-2)"

export PATH=$HPREFIX/sbin:$HPREFIX/bin:$PATH
export PYTHONPATH=$HPREFIX/lib/python${PYTHON_VER}/site-packages:$PYTHONPATH
export LD_LIBRARY_PATH=$HPREFIX/lib64:$HPREFIX/lib
export PKG_CONFIG_PATH=$HPREFIX/lib/pkgconfig
