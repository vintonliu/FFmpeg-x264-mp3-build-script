#!/bin/sh

CWD=`pwd`

PLATFORM=iOS
SOURCE="mp3lame"

OUTPUT_OBJECT="$CWD/build/$PLATFORM/mp3lame/object"
OUTPUT_INSTALL="$CWD/build/$PLATFORM/mp3lame/install"
THIN="$OUTPUT_INSTALL"
FAT="$OUTPUT_INSTALL/all"

rm -rf $CWD/build/$PLATFORM/mp3lame

CONFIGURE_FLAGS="--disable-shared --disable-frontend"
ARCHS="arm64 x86_64 armv7"
MIN_VERSION="9.0"

build_lame() {
	for ARCH in $ARCHS
	do
		echo "building lame on $ARCH ..."
		mkdir -p "$OUTPUT_OBJECT/$ARCH"
		cd "$OUTPUT_OBJECT/$ARCH"

		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    if [ "$ARCH" = "x86_64" ]
		    then
		    	SIMULATOR="-mios-simulator-version-min=$MIN_VERSION"
                HOST=x86_64-apple-darwin
		    else
		    	SIMULATOR="-mios-simulator-version-min=$MIN_VERSION"
                HOST=i386-apple-darwin
		    fi
		else
		    PLATFORM="iPhoneOS"
		    SIMULATOR="-mios-version-min=$MIN_VERSION"
            HOST=arm-apple-darwin
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang -arch $ARCH -miphoneos-version-min=$MIN_VERSION"
		
		CC=$CC $CWD/$SOURCE/configure \
		    $CONFIGURE_FLAGS \
            --host=$HOST \
		    --prefix="$THIN/$ARCH" || exit 1

		make -j8 install
	done

	cd $CWD
}

combile_lib() {
	echo "building fat binaries..."
	mkdir -p $FAT/lib
	set - $ARCHS

	cd $THIN/$1/lib
	for LIB in *.a
	do
		echo lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB 1>&2
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB || exit 1

		echo "************************************************************"
		lipo -i $FAT/lib/$LIB
	done

	cd $CWD
	cp -rf $THIN/$1/include $FAT
}

copy_lib() {
	echo "********* copy lame lib ********"
	DST=$CWD/../refs/ios
	cp -rf $FAT/lib/*.a $DST
}

build_lame || exit 1
combile_lib || exit 1
copy_lib

echo Done