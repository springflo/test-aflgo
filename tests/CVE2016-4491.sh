#!/bin/bash
pushd `pwd`
WORK=`pwd`
NAME=binutils
TEST_SUITE_DIR=$WORK/fuzzer-test-suite
DOWNLOAD_DIR=$WORK/binutils
if [ ! -d $DOWNLOAD_DIR ]; then
mkdir $DOWNLOAD_DIR
fi 
cd $DOWNLOAD_DIR
SUBJECT=$DOWNLOAD_DIR
TMP_DIR=$SUBJECT/temp
if [ -e $TMP_DIR/state ]; then
  echo "1" >$TMP_DIR/state
fi
#### valgind c++filt _Z1MA_aMMMMA_MMA_MMMMMMMMSt1MS_o11T0000000000t2M0oooozoooo
echo -e "cp-demangle.c:5394\ncp-demangle.c:4320" > $TMP_DIR/BBtargets.txt 
##echo core | sudo tee /proc/sys/kernel/core_pattern
## wget http://ftp.gnu.org/gnu/binutils/binutils-2.26.tar.gz
cd $DOWNLOAD_DIR/BUILD/
if [ ! -e obj-4491-3 ]; then 
	echo "Compile patched version."
	patch -p0 < ../patch-4491
	mkdir obj-4491-3; cd obj-4491-3
	../configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-ld
	make
	cp $DOWNLOAD_DIR/binutils-2.26/libiberty/cp-demangle.c $DOWNLOAD_DIR/BUILD/libiberty/cp-demangle.c
	cd $DOWNLOAD_DIR/BUILD/
	echo "Compile patched version done."
fi

AFLGO=/home/nfs/workspace/aflgo-origin
ADDITIONAL="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
export CC=$AFLGO/afl-clang-fast
export CXX=$AFLGO/afl-clang-fast++
export CFLAGS="-g3 $ADDITIONAL"
export CXXFLAGS="-g3  $ADDITIONAL"
export LDFLAGS="-ldl -lutil" 

echo "First Compile."
#rm -r obj-4491-1
#mkdir obj-4491-1; cd obj-4491-1;
#../configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-ld
#make 
echo "First Compile done."

cd $SUBJECT
TARGET=BUILD/obj-4491-1/binutils/cxxfilt

#### Clean up
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt

#### Generate distance

#$AFLGO/scripts/genDistance.sh $SUBJECT $TMP_DIR ${TARGET}

echo "Distance values:"
head -n5 $TMP_DIR/distance.cfg.txt
echo "..."
tail -n5 $TMP_DIR/distance.cfg.txt

CFLAGS="-DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error -distance=$TMP_DIR/distance.cfg.txt -outdir=$TMP_DIR"
CXXFLAGS="-distance=$TMP_DIR/distance.cfg.txt -outdir=$TMP_DIR"
cd $DOWNLOAD_DIR/BUILD/ 

echo "Second compile."
rm -r obj-4491-2
mkdir obj-4491-2; cd obj-4491-2; # work around because cannot run make distclean
../configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-ld
make
echo "Second compile done."

cd $SUBJECT 
TARGET=BUILD/obj-4491-2/binutils/cxxfilt
TIME=1m
echo "" > $SUBJECT/in/seeds
DIR_IN=$SUBJECT/in

TIME_RECORD_FILE=time${TIME}-${NAME}-aflgo-good.txt
if [ -f $TIME_RECORD_FILE ]; then
	rm $TIME_RECORD_FILE
fi

DIR_OUT=$DOWNLOAD_DIR/4491

ITER=1
for((i=1;i<=$((ITER));i++));
do
	if [ -d $DIR_OUT ]; then
		rm -rf $DIR_OUT
	fi
	/usr/bin/time -a -o $TIME_RECORD_FILE $AFLGO/afl-fuzz -S target_result -z exp -c $TIME -i $DIR_IN -o $DIR_OUT  $SUBJECT/${TARGET} 
	#gdb --args $AFLGO/afl-fuzz -S ${TARGET}_result -z exp -c $TIME -i $DIR_IN -o $DIR_OUT -E $TMP_DIR -x $AFLGO/dictionaries/png.dict $SUBJECT/${TARGET}_profiled @@
done
!
popd
