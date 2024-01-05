#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE_COMMON=universal8895-common
VENDOR=samsung

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi


# Initialize the helper
setup_vendor "${DEVICE_COMMON}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}" true

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

# Fix proprietary blobs
BLOB_ROOT="$ANDROID_ROOT"/vendor/"$VENDOR"/"$DEVICE_COMMON"/proprietary

sed -i -z "s/    seclabel u:r:gpsd:s0\n//" $BLOB_ROOT/vendor/etc/init/init.gps.rc

# gps config
sed -i "s/XTRA_SERVER_1/LONGTERM_PSDS_SERVER_1/" $BLOB_ROOT/etc/gps_debug.conf
sed -i "s/XTRA_SERVER_2/LONGTERM_PSDS_SERVER_2/" $BLOB_ROOT/etc/gps_debug.conf

# replace SSLv3_client_method with SSLv23_method
sed -i "s/SSLv3_client_method/SSLv23_method\x00\x00\x00\x00\x00\x00/" $BLOB_ROOT/vendor/bin/hw/gpsd

# RIL patches
xxd -p -c0 $BLOB_ROOT/proprietary/vendor/lib64/libsec-ril-dsds.so | sed "s/600e40f9820c8052e10315aae30314aa/600e40f9820c8052e10315aa030080d2/g" | xxd -r -p > $BLOB_ROOT/proprietary/vendor/lib64/libsec-ril-dsds.so.patched
mv $BLOB_ROOT/proprietary/vendor/lib64/libsec-ril-dsds.so.patched $BLOB_ROOT/proprietary/vendor/lib64/libsec-ril-dsds.so

xxd -p -c0 $BLOB_ROOT/proprietary/vendor/lib64/libsec-ril.so | sed "s/600e40f9820c8052e10315aae30314aa/600e40f9820c8052e10315aa030080d2/g" | xxd -r -p > $BLOB_ROOT/proprietary/vendor/lib64/libsec-ril.so.patched
mv $BLOB_ROOT/proprietary/vendor/lib64/libsec-ril.so.patched $BLOB_ROOT/proprietary/vendor/lib64/libsec-ril.so

# Audio hal bt sco shim
"${PATCHELF}" --add-needed libaudioparams_shim.so $BLOB_ROOT/lib/hw/audio.primary.exynos8895.so
sed -i 's/str_parms_get_str/str_parms_get_mod/g' $BLOB_ROOT/lib/hw/audio.primary.exynos8895.so

# Audio Drop SoundTrigger HAL
"${PATCHELF}" --remove-needed libaudio_soundtrigger.so $BLOB_ROOT/lib/hw/audio.primary.exynos8895.so

# hidlbase legacy hack
"${PATCHELF}" --replace-needed libhidlbase.so libhidlbase-v32.so $BLOB_ROOT/lib/android.hardware.gnss@1.0.so
"${PATCHELF}" --replace-needed libhidlbase.so libhidlbase-v32.so $BLOB_ROOT/lib/vendor.samsung.hardware.gnss@1.0.so
"${PATCHELF}" --replace-needed libhidlbase.so libhidlbase-v32.so $BLOB_ROOT/lib/android.hardware.gnss@1.1.so
"${PATCHELF}" --replace-needed libhidlbase.so libhidlbase-v32.so $BLOB_ROOT/lib/vendor.samsung_slsi.hardware.ExynosHWCServiceTW@1.0.so
"${PATCHELF}" --replace-needed libhidlbase.so libhidlbase-v32.so $BLOB_ROOT/lib64/android.hardware.gnss@1.0.so
"${PATCHELF}" --replace-needed libhidlbase.so libhidlbase-v32.so $BLOB_ROOT/lib64/vendor.samsung.hardware.gnss@1.0.so
"${PATCHELF}" --replace-needed libhidlbase.so libhidlbase-v32.so $BLOB_ROOT/lib64/android.hardware.gnss@1.1.so
"${PATCHELF}" --replace-needed libhidlbase.so libhidlbase-v32.so $BLOB_ROOT/lib64/vendor.samsung_slsi.hardware.ExynosHWCServiceTW@1.0.so

# HWC wants old libutils
"${PATCHELF}" --replace-needed libutils.so libutils-v32.so $BLOB_ROOT/vendor/lib64/libexynosdisplay.so
"${PATCHELF}" --replace-needed libutils.so libutils-v32.so $BLOB_ROOT/vendor/lib/libexynosdisplay.so
"${PATCHELF}" --replace-needed libutils.so libutils-v32.so $BLOB_ROOT/vendor/lib64/hw/hwcomposer.exynos5.so
"${PATCHELF}" --replace-needed libutils.so libutils-v32.so $BLOB_ROOT/vendor/lib/hw/hwcomposer.exynos5.so

# Remove libhidltransport dependencie
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/lib/android.hardware.gnss@1.0.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/lib/android.hardware.gnss@1.1.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/lib/libGrallocWrapper.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/lib/libskeymaster.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/lib/vendor.samsung.hardware.gnss@1.0.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/lib/vendor.samsung_slsi.hardware.ExynosHWCServiceTW@1.0.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/lib64/android.hardware.gnss@1.0.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/lib64/android.hardware.gnss@1.1.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/lib64/libGrallocWrapper.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/lib64/libskeymaster.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/lib64/vendor.samsung.hardware.gnss@1.0.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/lib64/vendor.samsung_slsi.hardware.ExynosHWCServiceTW@1.0.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/bin/hw/android.hardware.drm@1.1-service.widevine
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/bin/hw/vendor.samsung.hardware.gnss@1.0-service
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/bin/hw/vendor.samsung_slsi.hardware.ExynosHWCServiceTW@1.0-service
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/lib/libskeymaster3device.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/lib/libstagefright_bufferqueue_helper_vendor.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/lib/libstagefright_omx_vendor.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/lib/libwvhidl.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/lib/sensors.sensorhub.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/lib64/hw/android.hardware.gnss@1.1-impl.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/lib64/hw/vendor.samsung.hardware.gnss@1.0-impl.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/lib64/libskeymaster3device.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/lib64/sensors.sensorhub.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/lib64/libsec-ril-dsds.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/lib64/libsec-ril.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/lib/libsec-ril-dsds.so
"${PATCHELF}" --remove-needed libhidltransport.so $BLOB_ROOT/vendor/lib/libsec-ril.so
# Remove libhwbinder dependencie
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/lib/android.hardware.gnss@1.0.so
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/lib/android.hardware.gnss@1.1.so
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/lib/vendor.samsung.hardware.gnss@1.0.so
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/lib/vendor.samsung_slsi.hardware.ExynosHWCServiceTW@1.0.so
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/lib64/android.hardware.gnss@1.0.so
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/lib64/android.hardware.gnss@1.1.so
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/lib64/vendor.samsung.hardware.gnss@1.0.so
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/lib64/vendor.samsung_slsi.hardware.ExynosHWCServiceTW@1.0.so
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/vendor/bin/hw/android.hardware.drm@1.1-service.widevine
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/vendor/lib/libwvhidl.so
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/vendor/lib64/hw/vendor.samsung.hardware.gnss@1.0-impl.so
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/vendor/lib64/libsec-ril-dsds.so
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/vendor/lib64/libsec-ril.so
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/vendor/lib/libsec-ril-dsds.so
"${PATCHELF}" --remove-needed libhwbinder.so $BLOB_ROOT/vendor/lib/libsec-ril.so

# Protobuf
"${PATCHELF}" --replace-needed libprotobuf-cpp-lite.so libprotobuf-cpp-lite-v29.so $BLOB_ROOT/vendor/lib/libwvhidl.so
"${PATCHELF}" --replace-needed libprotobuf-cpp-lite.so libprotobuf-cpp-lite-v29.so $BLOB_ROOT/vendor/lib/mediadrm/libwvdrmengine.so

# Replace libvndsecril-client with libsecril-client
"${PATCHELF}" --replace-needed libvndsecril-client.so libsecril-client.so $BLOB_ROOT/vendor/lib/libwrappergps.so
"${PATCHELF}" --replace-needed libvndsecril-client.so libsecril-client.so $BLOB_ROOT/vendor/lib64/libwrappergps.so
"${PATCHELF}" --replace-needed libvndsecril-client.so libsecril-client.so $BLOB_ROOT/lib/libaudio-ril.so
"${PATCHELF}" --replace-needed libvndsecril-client.so libsecril-client.so $BLOB_ROOT/lib/hw/audio.primary.exynos8895.so

"${MY_DIR}/setup-makefiles.sh"
