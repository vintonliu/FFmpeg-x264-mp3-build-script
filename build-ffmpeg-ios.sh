#!/bin/sh

CWD=`pwd`
TARGET_OS=iOS

# absolute path to x264 library
X264="$CWD/build/$TARGET_OS/x264/install/all"
MP3_LAME="$CWD/build/$TARGET_OS/mp3lame/install/all"
FDKAAC="$CWD/build/$TARGET_OS/fdk-aac/install/all"
OPENSSL="$CWD/build/$TARGET_OS/openssl/install/all"

# check h264 lib 
has_x264=0
if [ ! -f "$X264/lib/libx264.a" ]; 
then
echo "no x264 lib,start to build x264"
# ./build-x264-ios.sh || exit 1
# has_x264=1
fi
# has_x264=1

# check mp3lame lib 
has_mp3lame=0
if [ ! -f "$MP3_LAME/lib/libmp3lame.a" ]; 
then
echo "no mp3lame lib,start to build mp3lame"
./build-lame-ios.sh || exit 1
fi
has_mp3lame=1

# check fdk-aac lib 
has_fdkaac=0
if [ ! -f "$FDKAAC/lib/libfdk-aac.a" ]; 
then
echo "no fdk-aac lib,start to build fdk-aac"
./build-fdk-aac-ios.sh || exit 1
fi
has_fdkaac=1

# check openssl lib
has_openssl=0
if [ ! -f "$OPENSSL/lib/libssl.a" ]
then
	echo "no openssl, start to build openssl ..."
	./build-ssl-ios.sh || exit 1
	echo "build openssl done."
fi
has_openssl=1

SOURCE="ffmpeg-4.2.4"
SOURCE_PATH="$CWD/$SOURCE"

OUTPUT_OBJECT="$CWD/build/$TARGET_OS/ffmpeg/object"
OUTPUT_INSTALL="$CWD/build/$TARGET_OS/ffmpeg/install"
THIN=$OUTPUT_INSTALL
FAT="$OUTPUT_INSTALL/all"

# rm -rf $CWD/build/$TARGET_OS/ffmpeg
rm -rf $OUTPUT_INSTALL

CONFIGURE_FLAGS="--enable-cross-compile \
                --disable-debug \
                --disable-programs \
                --disable-doc \
                --enable-pic \
                --enable-gpl \
                --enable-nonfree \
                --disable-zlib \
                --disable-bzlib \
                --disable-iconv \
                --disable-devices \
                --disable-avdevice \
                --disable-coreimage \
				--disable-everything \
                --enable-filters \
                --enable-fft \
                --enable-rdft \
                --enable-hwaccels \
                --enable-decoder=vorbis,flac \
                --enable-decoder=pcm_u8,pcm_s16le,pcm_s24le,pcm_s32le,pcm_f32le \
                --enable-decoder=pcm_s16be,pcm_s24be,pcm_mulaw,pcm_alaw \
                --enable-decoder=aac* \
                --enable-decoder=mp3* \
                --enable-protocol=rtmp* \
                --enable-protocol=file,crypto \
                --enable-demuxer=wav,mp3,aac,h264,mov \
                --enable-parser=aac,h264 \
                --enable-muxer=mp3,mp4,h264,mov,wav"

if [ $has_x264 -eq 1 ]
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-libx264"
fi

if [ $has_fdkaac -eq 1 ]
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-libfdk-aac --enable-encoder=libfdk_aac"
fi

if [ $has_mp3lame -eq 1 ]
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-libmp3lame --enable-encoder=libmp3lame"
fi

if [ $has_openssl -eq 1 ]
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-openssl"
fi

# avresample
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-avresample"

ARCHS="arm64 armv7 x86_64"
#ARCHS="arm64"

MIN_VERSION="9.0"

build_ffmpeg() {
	if [ ! `which yasm` ]
	then
		echo 'Yasm not found'
		if [ ! `which brew` ]
		then
			echo 'Homebrew not found. Trying to install...'
			ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" \
				|| exit 1
		fi
		echo 'Trying to install Yasm...'
		brew install yasm || exit 1
	fi
	if [ ! `which gas-preprocessor.pl` ]
	then
		echo 'gas-preprocessor.pl not found. Trying to install...'
		(curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
			-o /usr/local/bin/gas-preprocessor.pl \
			&& chmod +x /usr/local/bin/gas-preprocessor.pl) \
			|| exit 1
	fi

	for ARCH in $ARCHS
	do
		echo "*******************************************"
		echo "Building ffmpeg for $ARCH ..."
		echo "*******************************************"

		mkdir -p "$OUTPUT_OBJECT/$ARCH"
		cd "$OUTPUT_OBJECT/$ARCH"

		CFLAGS="-arch $ARCH -miphoneos-version-min=$MIN_VERSION"
		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		else
		    PLATFORM="iPhoneOS"
		    if [ "$ARCH" = "arm64" ]
		    then
		        EXPORT="GASPP_FIX_XCODE5=1"
		    fi

			if [ "$ARCH" = "armv7" ]
			then
				CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-asm"
			fi
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		# if [ $has_x264 -eq 1 ]
		# then
		# 	CFLAGS="$CFLAGS -I$X264/include"
		# 	LDFLAGS="$LDFLAGS -L$X264/lib"
		# fi

		if [ $has_fdkaac -eq 1 ]
		then
			CFLAGS="$CFLAGS -I$FDKAAC/include"
			LDFLAGS="$LDFLAGS -L$FDKAAC/lib"
		fi

		if [ $has_mp3lame -eq 1 ]
		then
			CFLAGS="$CFLAGS -I$MP3_LAME/include"
			LDFLAGS="$LDFLAGS -L$MP3_LAME/lib"
		fi

		if [ $has_openssl -eq 1 ]
		then
			CFLAGS="$CFLAGS -I$OPENSSL/include"
			LDFLAGS="$LDFLAGS -L$OPENSSL/lib"
		fi

		$SOURCE_PATH/configure \
		    --target-os=darwin \
		    --arch=$ARCH \
		    --cc="$CC" \
		    $CONFIGURE_FLAGS \
		    --extra-cflags="$CFLAGS" \
		    --extra-cxxflags="$CXXFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$THIN/$ARCH" \
		|| exit 1

		make -j8 install $EXPORT || exit 1
	done

    cd $CWD
}

combile_libs() {
	echo "building fat binaries..."
	mkdir -p $FAT/lib
	set - $ARCHS
	cd $THIN/$1/lib
	for LIB in *.a
	do
		echo lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB 1>&2
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB || exit 1
		lipo -i $FAT/lib/$LIB
	done
    cp -rf $THIN/$1/include $FAT

    cd $CWD
}

# copy libs
copy_libs() {
	echo "*******************************************"
	echo "Copy ffmpeg lib ..."
	echo "*******************************************"
	DST=$CWD/../refs/ios/ffmpeg/lib
	if [ -d $DST ]
	then
		rm -rf $DST
	fi
	mkdir -p $DST
	cp -rf $FAT/lib/*.a $DST/
}

copy_config() {
	DST=$CWD/../refs/ios/ffmpeg
    # DST=$CWD/../umcs/source/umcs/third_party/ffmpeg/include/config/ios
	for ARCH in $ARCHS; do
	  	echo "copy config for $ARCH ..."
		# Don't waste time on non-existent configs, if no config.h then skip.
        [ ! -e "$OUTPUT_OBJECT/$ARCH/config.h" ] && continue
        # for f in config.h config.asm libavutil/avconfig.h libavutil/ffversion.h libavcodec/bsf_list.c libavcodec/codec_list.c libavcodec/parser_list.c  libavformat/demuxer_list.c libavformat/muxer_list.c libavformat/protocol_list.c; do
        for f in config.h config.asm libavutil/avconfig.h libavutil/ffversion.h; do
            FROM="$OUTPUT_OBJECT/$ARCH/$f"
            TO="$DST/config/$ARCH/$f"
            if [ "$(dirname $f)" != "" ]; then mkdir -p $(dirname $TO); fi
            [ -e $FROM ] && cp -v $FROM $TO
        done
	done
}

build_ffmpeg || exit 1
combile_libs || exit 1
copy_libs || exit 1
copy_config || exit 1

echo Done
