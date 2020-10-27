#!/bin/sh
# if [ ! -d "${ANDROID_NDK_ROOT}" ];then
# echo error,no ANDROID_NDK_ROOT,set ANDROID_NDK_ROOT to NDK path
# exit 1
# fi

ANDROID_NDK_ROOT=~/android-ndk-r20
TOOLCHAIN=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64

CWD=`pwd`
SOURCE_PATH="$CWD/x264"

API_32=19
API_64=21
# 五种类型cpu编译链
android_abis=(
    # armeabi is no longer support build
#   "armeabi"
    "armeabi-v7a"
    "arm64-v8a"
    # "x86"
    # "x86_64"
)

platforms=(
	# "arm"
	"armv7a"
	"aarch64"
	"i686"
	"x86_64"
)

archs=(
	# "arm"
	"arm"
	"aarch64"
	"i686"
	"x86_64"
)

extra_cflags=(
    # "-march=armv5te -msoft-float -D__ANDROID__  -D__ANDROID_API__=$API -D__ARM_ARCH_5TE__ -D__ARM_ARCH_5TEJ__"
    "-march=armv7-a -mfloat-abi=softfp -mfpu=neon -mthumb -D__ANDROID__  -D__ANDROID_API__=$API_32 -D__ARM_ARCH_7__ -D__ARM_ARCH_7A__ -D__ARM_ARCH_7R__ -D__ARM_ARCH_7M__ -D__ARM_ARCH_7S__"
    "-march=armv8-a -D__ANDROID__  -D__ANDROID_API__=$API_64 -D__ARM_ARCH_8__ -D__ARM_ARCH_8A__"
    "-march=i686 -mtune=i686 -m32 -mmmx -msse2 -msse3 -mssse3 -D__ANDROID__  -D__ANDROID_API__=$API_32 -D__i686__"
    "-march=core-avx-i -mtune=core-avx-i -m64 -mmmx -msse2 -msse3 -mssse3 -msse4.1 -msse4.2 -mpopcnt -D__ANDROID__  -D__ANDROID_API__=$API_64 -D__x86_64__"
)

CONFIGURE_FLAGS="--enable-static \
				--enable-pic \
				--disable-opencl \
				--disable-cli \
				--enable-strip \
				--disable-win32thread"

OUTPUT_INSTALL="$CWD/build/android/x264/install"
OUTPUT_OBJECT="$CWD/build/android/x264/object"
rm -rf $CWD/build/android/x264

build_x264() {
	num=${#android_abis[@]}
	for((i=0; i<num; i++))
	do
		echo "*******************************************"
		echo "Building x264 for ${android_abis[i]} ......"
		echo "*******************************************"
		
		mkdir -p $OUTPUT_INSTALL/${android_abis[i]}
		mkdir -p $OUTPUT_OBJECT/${android_abis[i]}

		if [ "${android_abis[i]}" = "armeabi-v7a" ]
		then
			HOST=arm-linux
			CLANG_PREFIX=$TOOLCHAIN/bin/${platforms[i]}-linux-androideabi$API_32
		elif [ "${android_abis[i]}" = "arm64-v8a" ]
		then
			HOST=aarch64-linux-android
			CLANG_PREFIX=$TOOLCHAIN/bin/${platforms[i]}-linux-android$API_64
		elif [ "${android_abis[i]}" = "x86" ]
		then
			HOST=i686-linux-android
			CLANG_PREFIX=$TOOLCHAIN/bin/${platforms[i]}-linux-android$API_32
			CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-asm"
		elif [ "${android_abis[i]}" = "x86_64" ]
		then
			HOST=x86_64-linux-android
			CLANG_PREFIX=$TOOLCHAIN/bin/${platforms[i]}-linux-android$API_64
			CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-asm"
		fi

		SYSROOT=$TOOLCHAIN/sysroot
		if [ "${android_abis[i]}" = "armeabi-v7a" -o "${android_abis[i]}" = "armeabi" ]
		then
			CROSS_PREFIX=$TOOLCHAIN/bin/arm-linux-androideabi
		else
			CROSS_PREFIX=$TOOLCHAIN/bin/${platforms[i]}-linux-android
		fi

		cd $OUTPUT_OBJECT/${android_abis[i]}
		
		export CXX="$CLANG_PREFIX-clang++"
		export CC="$CLANG_PREFIX-clang"
		export NM="$CROSS_PREFIX-nm"
		export STRIP="$CROSS_PREFIX-strip"
		export RANLIB="$CROSS_PREFIX-ranlib"
		export AR="$CROSS_PREFIX-ar"
		export LDFLAGS="${extra_cflags[i]} -O3 -fPIC"
		export CFLAGS="${extra_cflags[i]} -O3 -fPIC --sysroot=${SYSROOT}"		
		
		echo "CC = $CC"
		echo "CXX = $CXX"
		echo "CFLAGS = $CFLAGS"
		echo "LDFLAGS = $LDFLAGS"

		$SOURCE_PATH/configure --prefix=$OUTPUT_INSTALL/${android_abis[i]} \
								$CONFIGURE_FLAGS \
								--host=$HOST \
								--cross-prefix=$CROSS_PREFIX- \
								--sysroot=$SYSROOT || exit 1

		make -j8 && make install # && make distclean
		echo "Installed: $OUTPUT_INSTALL/${android_abis[i]}"
	done

	cd $CWD
}

copy_lib() {
	echo "*******************************************"
	echo "Copy x264 lib ..."
	echo "*******************************************"
    num=${#android_abis[@]}
	for((i=0; i<num; i++))
    do
        DST_LIB=$CWD/../refs/android/lib/${android_abis[i]}
        if [ ! -d $DST_LIB ]
        then
            mkdir -p $DST_LIB
        fi

        # copy lib
        cp -rf $OUTPUT_INSTALL/${android_abis[i]}/lib/*.a $DST_LIB/
    done
}

build_x264 || exit 1
copy_lib || exit 1
cd $CWD

echo Done
