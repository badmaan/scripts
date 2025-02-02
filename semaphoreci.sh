#!/usr/bin/env bash
#
# Copyright (C) 2018-2019 Rama Bondan Prakoso (rama982)
#
# SemaphoreCI Classic Kernel Build Script
# For sdm660

# Clone depedencies
git clone --depth=1 https://github.com/fabianonline/telegram.sh telegram
git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-5900059 clang
git clone --depth=1 https://github.com/rama982/AnyKernel3 -b $DEVICE
git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r50 stock
git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r50 stock_32

# Export var
export DEVICE
export CONFIG
export CHANNEL_ID
export TELEGRAM_TOKEN

# Main environtment
export TZ=":Asia/Jakarta"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
KERNEL_DIR=$(pwd)
ZIP_DIR=$KERNEL_DIR/AnyKernel3
DTBS=$KERNEL_DIR/out/arch/arm64/boot/dts/qcom
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz
CONFIG_PATH=$KERNEL_DIR/arch/arm64/configs/$CONFIG
PATH="${KERNEL_DIR}/clang/bin:${KERNEL_DIR}/stock/bin:${KERNEL_DIR}/stock_32/bin:${PATH}"
export KBUILD_COMPILER_STRING="$(${KERNEL_DIR}/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')"

# Install build package
install-package --update-new bc bash git-core gnupg build-essential ccache \
    zip curl make automake autogen autoconf autotools-dev libtool shtool python \
    m4 gcc libtool zlib1g-dev gcc-aarch64-linux-gnu flex

#TELEGRAM

TELEGRAM=telegram/telegram

pushKernel() {
	curl -F document=@$(echo $ZIP_DIR/*.zip)  "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
			-F chat_id="$CHANNEL_ID"
}

tg_channelcast() {
    "${TELEGRAM}" -c ${CHANNEL_ID} -H \
        "$(
            for POST in "${@}"; do
                echo "${POST}"
            done
        )"
}

tg_sendstick() {
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker" \
        -d sticker="CAADBQADCwADfmlfEgEtqXB1SD3FFgQ" \
        -d chat_id="$CHANNEL_ID"
}

pushInfo() {
    if [[ $DEVICE =~ "lavender" ]];
    then
        NAME="Redmi Note 7/7S"
    elif [[ $DEVICE =~ "ginkgo" ]];
    then
        NAME="Redmi Note 8"
    else
        NAME="Redmi Note 6 Pro"
    fi
    KERNEL=$(cat out/.config | grep Linux/arm64 | cut -d " " -f3)
    tg_sendstick
    tg_channelcast "New build available!" \
        "Device : <code>$NAME</code>" \
        "Toolchain : <code>${KBUILD_COMPILER_STRING}</code>" \
        "Branch : <code>${BRANCH}</code>" \
        "Commit Point : <code>$(git log --pretty=format:'"%h : %s"' -1)</code>"
}

# Build kernel

makeKernelGcc () {
    export KBUILD_BUILD_USER="ramakun"
    make O=out ARCH=arm64 $CONFIG
    make -j$(nproc --all) O=out \
                          ARCH=arm64 \
                          CROSS_COMPILE=aarch64-linux-android- \
                          CROSS_COMPILE_ARM32=arm-linux-androideabi-

    if ! [ -a $KERN_IMG ]; then
        tg_channelcast "<b>BuildCI report status:</b> There are build running but its error, please fix and remove this message!"
        exit 1
    fi
}

makeKernelClang () {
    export KBUILD_BUILD_USER="ramakun"
    make O=out ARCH=arm64 $CONFIG
    make -j$(nproc --all) O=out \
                          ARCH=arm64 \
                          CC=clang \
                          CLANG_TRIPLE=aarch64-linux-gnu- \
                          CROSS_COMPILE=aarch64-linux-android- \
                          CROSS_COMPILE_ARM32=arm-linux-androideabi-

    if ! [ -a $KERN_IMG ]; then
        tg_channelcast "<b>BuildCI report status:</b> There are build running but its error, please fix and remove this message!"
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
    cp $DTBS/*.dtb $ZIP_DIR/dtbs
    cp $KERN_IMG $ZIP_DIR/kernel
    make -C $ZIP_DIR normal
}

cleanZip () {
    make -C $ZIP_DIR clean
}

if [[ $BRANCH =~ "10" ]];
then
    makeKernelClang
    makeZip
    pushInfo
    pushKernel
else
    #Unify Build
    makeKernelClang
    modules
    sed -i 's/WLAN=m/WLAN=y/g' $CONFIG_PATH
    makeKernelClang
    makeZip
    pushInfo
    pushKernel
fi
