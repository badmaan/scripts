#!/usr/bin/env bash
#
# Copyright (C) 2019 Rama Bondan Prakoso (rama982)
#
# Local Kernel Build Script

DEVICE=ginkgo
CONFIG="vendor/ginkgo-perf_defconfig"

# Clone toolchain
git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-5900059 clang
git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r50 stock
git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r50 stock_32

# Clone AnyKernel
git clone --depth=1 https://github.com/badmaan/AnyKernel3 -b $DEVICE

# Main environtment
KERNEL_DIR=$(pwd)
ZIP_DIR=$KERNEL_DIR/AnyKernel3
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb
PATH="${KERNEL_DIR}/clang/bin:${KERNEL_DIR}/stock/bin:${KERNEL_DIR}/stock_32/bin:${PATH}"
export KBUILD_COMPILER_STRING="$(${KERNEL_DIR}/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')"
export CROSS_COMPILE_ARM32=$(pwd)/stock_32/bin/
makeKernelClang () {
    export KBUILD_BUILD_USER="isamet"
    make O=out ARCH=arm64 $CONFIG
    make -j$(nproc --all) O=out \
                          ARCH=arm64 \
                          CC="clang" \
                          CLANG_TRIPLE=aarch64-linux-gnu- \
                          CROSS_COMPILE=aarch64-linux-android-

    if ! [ -a $KERN_IMG ]; then
        exit 1
    fi
}

modules () {
    # credit @adekmaulana
    VENDOR_MODULEDIR="$ZIP_DIR/modules/vendor/lib/modules"
    STRIP="$KERNEL_DIR/stock/bin/$(echo "$(find "$KERNEL_DIR/stock/bin" -type f -name "aarch64-*-gcc")" | awk -F '/' '{print $NF}' |\
                sed -e 's/gcc/strip/')"
    for MODULES in $(find "$KERNEL_DIR/out" -name '*.ko'); do
        "${STRIP}" --strip-unneeded --strip-debug "${MODULES}"
        "$KERNEL_DIR/out/scripts/sign-file" sha512 \
                "$KERNEL_DIR/out/certs/signing_key.pem" \
                "$KERNEL_DIR/out/certs/signing_key.x509" \
                "${MODULES}"
        case ${MODULES} in
                */wlan.ko)
            cp "${MODULES}" "${VENDOR_MODULEDIR}/qca_cld3_wlan.ko" ;;
        esac
    done
    echo -e "\n(i) Done moving modules"
}

makeZip () {
    cp $KERN_IMG $ZIP_DIR
    make -C $ZIP_DIR normal
}

cleanZip () {
    make -C $ZIP_DIR clean
}

# Build Kernel
time makeKernelClang
cleanZip
modules
makeZip
