#!/bin/bash
pushd `pwd`
WORK=`pwd`
NAME=libpng
TEST_SUITE_DIR=$WORK/fuzzer-test-suite
DOWNLOAD_DIR=$WORK/CVE-2015-8540
cd $DOWNLOAD_DIR
SUBJECT=$DOWNLOAD_DIR
TMP_DIR=$SUBJECT/temp
if [ -e $TMP_DIR/state ]; then
  echo "1" >$TMP_DIR/state
fi
echo -e "pngwutil.c:1286\npngwutil.c:1288\npngwutil.c:1290\npngwutil.c:1291" >$TMP_DIR/BBtargets.txt 
##echo core | sudo tee /proc/sys/kernel/core_pattern

AFLGO=/home/nfs/workspace/aflgo-origin

cd $DOWNLOAD_DIR/BUILD/
####
##git clone https://github.com/glennrp/libpng.git
##1.0.65
##git checkout 7c7e39e

ADDITIONAL="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"

export CC=$AFLGO/afl-clang-fast
export CXX=$AFLGO/afl-clang-fast++
export LD=$CXX

export CFLAGS="-g3 $ADDITIONAL"
export CXXFLAGS="-g3 $ADDITIONAL"
export LDFLAGS="-lpthread"
#./configure --disable-shared
#make clean && make 

cd $SUBJECT/BUILD/contrib/gregbook
TARGET=BUILD/contrib/gregbook/wpng
#make clean -f Makefile.wpng && make -f Makefile.wpng

##### Clean up
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt

#### Generate distance
cd $SUBJECT
#$AFLGO/scripts/genDistance.sh $SUBJECT $TMP_DIR ${TARGET}
echo "Distance values:"
head -n5 $TMP_DIR/distance.cfg.txt
echo "..."
tail -n5 $TMP_DIR/distance.cfg.txt

export AFL_USE_ASAN=1
CFLAGS="-distance=$TMP_DIR/distance.cfg.txt -outdir=$TMP_DIR"
CXXFLAGS="-distance=$TMP_DIR/distance.cfg.txt -outdir=$TMP_DIR"
cd $DOWNLOAD_DIR/BUILD/
#./configure --disable-shared && make clean all

cd $SUBJECT/BUILD/contrib/gregbook
#make clean -f Makefile.wpng && make -f Makefile.wpng

cd $SUBJECT
TIME=1m
#DIR_IN=$TEST_SUITE_DIR/libpng-1.2.56/seeds
#DIR_IN=$AFLGO/testcases/images/png
#echo "" > $SUBJECT/in/seeds.png
DIR_IN=$SUBJECT/in

TIME_RECORD_FILE=time${TIME}-${NAME}-aflgo-good.txt
if [ -f $TIME_RECORD_FILE ]; then
	rm $TIME_RECORD_FILE
fi

DIR_OUT=$DOWNLOAD_DIR/out

ITER=1
for((i=1;i<=$((ITER));i++));
do
	if [ -d $DIR_OUT ]; then
		rm -rf $DIR_OUT
	fi
	/usr/bin/time -a -o $TIME_RECORD_FILE $AFLGO/afl-fuzz -S target_result -z exp -c $TIME -i $DIR_IN -o $DIR_OUT -m none -x $AFLGO/dictionaries/png.dict $SUBJECT/${TARGET} @@
	#gdb --args $AFLGO/afl-fuzz -S ${TARGET}_result -z exp -c $TIME -i $DIR_IN -o $DIR_OUT -E $TMP_DIR -x $AFLGO/dictionaries/png.dict $SUBJECT/${TARGET}_profiled @@
done
!
popd
