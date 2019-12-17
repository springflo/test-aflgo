#!/bin/bash
pushd `pwd`
WORK=`pwd`
NAME=libpng-1.2.56
TEST_SUITE_DIR=$WORK/fuzzer-test-suite
DOWNLOAD_DIR=$WORK/libpng-1.2.56-738
if [ ! -d $DOWNLOAD_DIR ]; then
mkdir $DOWNLOAD_DIR
fi 
cd $DOWNLOAD_DIR
SUBJECT=$DOWNLOAD_DIR
TMP_DIR=$SUBJECT/temp
if [ -e $TMP_DIR/state ]; then
  echo "1" >$TMP_DIR/state
fi
echo -e "pngread.c:737\npngread.c:738\npngread.c:739" >$TMP_DIR/BBtargets.txt 
##echo core | sudo tee /proc/sys/kernel/core_pattern
##$TEST_SUITE_DIR/libpng-1.2.56/build.sh
##[ ! -e libpng-1.2.56.tar.gz ] && wget https://downloads.sourceforge.net/project/libpng/libpng12/older-releases/1.2.56/libpng-1.2.56.tar.gz
##git clone https://github.com/google/fuzzer-test-suite
##[ ! -e libpng-1.2.56 ] && tar xf libpng-1.2.56.tar.gz
##rm -rf ./BUILD
##cp -rf libpng-1.2.56 BUILD
AFLGO=/home/nfs/workspace/aflgo-origin

cd $DOWNLOAD_DIR/BUILD/
ADDITIONAL="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"

export CC=$AFLGO/afl-clang-fast
export CXX=$AFLGO/afl-clang-fast++

export CFLAGS="-g3 $ADDITIONAL"
export CXXFLAGS="-g3 $ADDITIONAL"
export LDFLAGS="-lpthread"
./configure 
make

cd $SUBJECT
TARGET=target
$CXX $CXXFLAGS $LDFLAGS -std=c++11 -v  $TEST_SUITE_DIR/libpng-1.2.56/target.cc $TEST_SUITE_DIR/examples/example-hooks.cc $DOWNLOAD_DIR/BUILD/.libs/libpng12.a -I $DOWNLOAD_DIR/BUILD/ -lz -o ${TARGET}_profiled

#### Clean up
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt

#### Generate distance

$AFLGO/scripts/genDistance.sh $SUBJECT $TMP_DIR ${TARGET}_profiled

echo "Distance values:"
head -n5 $TMP_DIR/distance.cfg.txt
echo "..."
tail -n5 $TMP_DIR/distance.cfg.txt


CFLAGS="-distance=$TMP_DIR/distance.cfg.txt -outdir=$TMP_DIR"
CXXFLAGS="-distance=$TMP_DIR/distance.cfg.txt -outdir=$TMP_DIR"
cd $DOWNLOAD_DIR/BUILD/
make clean && ./configure  && make

cd $SUBJECT 
$CXX $CXXFLAGS $LDFLAGS -std=c++11 -v  $TEST_SUITE_DIR/libpng-1.2.56/target.cc $TEST_SUITE_DIR/examples/example-hooks.cc $DOWNLOAD_DIR/BUILD/.libs/libpng12.a -I $DOWNLOAD_DIR/BUILD/ -lz -o ${TARGET}_profiled

TIME=1m
DIR_IN=$TEST_SUITE_DIR/libpng-1.2.56/seeds
#DIR_IN=$SUBJECT/in

TIME_RECORD_FILE=time${TIME}-${TARGET}-${NAME}-aflgo-good.txt
if [ -f $TIME_RECORD_FILE ]; then
	rm $TIME_RECORD_FILE
fi

DIR_OUT=$DOWNLOAD_DIR/out

ITER=40
for((i=1;i<=$((ITER));i++));
do
	if [ -d $DIR_OUT ]; then
		rm -rf $DIR_OUT
	fi
	/usr/bin/time -a -o $TIME_RECORD_FILE $AFLGO/afl-fuzz -S ${TARGET}_result -z exp -c $TIME -i $DIR_IN -o $DIR_OUT -x $AFLGO/dictionaries/png.dict $SUBJECT/${TARGET}_profiled @@
	#gdb --args $AFLGO/afl-fuzz -S ${TARGET}_result -z exp -c $TIME -i $DIR_IN -o $DIR_OUT -E $TMP_DIR -x $AFLGO/dictionaries/png.dict $SUBJECT/${TARGET}_profiled @@
done

popd
