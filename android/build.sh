#!/bin/bash
echo "--- Setup"
export USE_CCACHE="1"
export CCACHE_EXEC=/usr/bin/ccache
export PYTHONDONTWRITEBYTECODE=true
export BUILD_ENFORCE_SELINUX=1
export BUILD_NO=
unset BUILD_NUMBER
export OVERRIDE_TARGET_FLATTEN_APEX=true 
#TODO(zif): convert this to a runtime check, grep "sse4_2.*popcnt" /proc/cpuinfo
export CPU_SSE42=false
# Following env is set from build
# VERSION
# DEVICE
# TYPE
# RELEASE_TYPE
# EXP_PICK_CHANGES

function get_numeric() {
    local RESOLUTION=60 # seconds
    local NOW=$(date +%s)
    local OFFSET=$(date -d '2021-07-05 UTC' +%s)
    local BASE=7380771 # RQ3A.210705.001
    echo "$(( $BASE + ($NOW - $OFFSET) / $RESOLUTION ))"
}

if [ -z "$BUILD_UUID" ]; then
  export BUILD_UUID=$(uuidgen)
fi

if [ -z "$TYPE" ]; then
  export TYPE=userdebug
fi

export BUILD_NUMBER=$(get_numeric)

echo "--- Syncing"

cd /lineage/${VERSION}
rm -rf .repo/local_manifests/*
if [ -f /lineage/setup.sh ]; then
    source /lineage/setup.sh
fi
yes | repo init -u https://github.com/lineageos/android.git -b ${VERSION}
echo "Resetting build tree"
repo forall -vc "git reset --hard ; git clean -fdx" > /tmp/android-reset.log 2>&1
echo "Syncing"
repo sync -j32 -d --force-sync > /tmp/android-sync.log 2>&1
. build/envsetup.sh


echo "--- clobber"
rm -rf out

echo "--- breakfast"
breakfast lineage_${DEVICE}-${TYPE}

if [[ "$TARGET_PRODUCT" != lineage_* ]]; then
    echo "Breakfast failed, exiting"
    exit 1
fi

if [ "$RELEASE_TYPE" '==' "experimental" ]; then
  if [ -n "$EXP_PICK_CHANGES" ]; then
    repopick $EXP_PICK_CHANGES
  fi
fi
echo "--- Building"
export OVERRIDE_TARGET_FLATTEN_APEX=true 
mka otatools-package target-files-package dist > /tmp/android-build.log

echo "--- Uploading"
ssh jenkins@blob.lineageos.org mkdir -p /home/jenkins/incoming/${DEVICE}/${BUILD_UUID}/
scp out/dist/*target_files*.zip jenkins@blob.lineageos.org:/home/jenkins/incoming/${DEVICE}/${BUILD_UUID}/
scp out/target/product/${DEVICE}/otatools.zip jenkins@blob.lineageos.org:/home/jenkins/incoming/${DEVICE}/${BUILD_UUID}/
