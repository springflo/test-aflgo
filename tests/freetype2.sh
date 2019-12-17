#!/bin/bash
pushd `pwd`
WORK=`pwd`
TEST_SUITE_DIR=$WORK/fuzzer-test-suite
DOWNLOAD_DIR=$WORK/build_good_freetype2
cd $DOWNLOAD_DIR
SUBJECT=$DOWNLOAD_DIR
TMP_DIR=$SUBJECT/temp
echo -e "ttgload.c:1709\nttgload.c:1710\nttgload.c:1711" >$TMP_DIR/BBtargets.txt 
##echo core | sudo tee /proc/sys/kernel/core_pattern
##$TEST_SUITE_DIR/freetype2-2017/build.sh
##[ ! -e freetype2.tar.gz ] && git clone git://git.sv.nongnu.org/freetype/freetype2.git
##git clone https://github.com/google/fuzzer-test-suite
AFLGO=/home/nfs/workspace/aflgo

cd $DOWNLOAD_DIR/BUILD/
ADDITIONAL="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"

export CC=$AFLGO/afl-clang-fast
export CXX=$AFLGO/afl-clang-fast++

export CFLAGS="-g3 $ADDITIONAL"
export CXXFLAGS="-g3 $ADDITIONAL"
export LDFLAGS="-lpthread"
./autogen.sh
./configure --with-harfbuzz=no --with-bzip2=no --with-png=no
make clean 
make -j2

:<<!
cd $SUBJECT
TARGET=target
$CXX $CXXFLAGS $LDFLAGS -std=c++11 -v  $TEST_SUITE_DIR/freetype2/target.cc $TEST_SUITE_DIR/examples/example-hooks.cc $DOWNLOAD_DIR/BUILD/.libs/libpng12.a -I $DOWNLOAD_DIR/BUILD/ -lz -o ${TARGET}_profiled

# Clean up
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt

# Generate distance

#$AFLGO/scripts/genDistance.sh $SUBJECT $TMP_DIR ${TARGET}_profiled

echo "Distance values:"
head -n5 $TMP_DIR/distance.cfg.txt
echo "..."
tail -n5 $TMP_DIR/distance.cfg.txt


CFLAGS="-distance=$TMP_DIR/distance.cfg.txt -outdir=$TMP_DIR"
CXXFLAGS="-distance=$TMP_DIR/distance.cfg.txt -outdir=$TMP_DIR"
cd $DOWNLOAD_DIR/BUILD/
make clean && ./configure  && make

cd $SUBJECT 
$CXX $CXXFLAGS $LDFLAGS -std=c++11 -v  $TEST_SUITE_DIR/freetype2-2017/target.cc $TEST_SUITE_DIR/examples/example-hooks.cc $DOWNLOAD_DIR/BUILD/.libs/libpng12.a -I $DOWNLOAD_DIR/BUILD/ -lz -o ${TARGET}_profiled

$AFLGO/scripts/index_all_cfg_edges.py -d $TMP_DIR/dot-files
$AFLGO/tutorial/samples/test/vis-dot.sh $TMP_DIR/dot-files

TIME=1m
if [[ ! -d seeds ]]; then
  mkdir seeds
  git clone https://github.com/unicode-org/text-rendering-tests.git TRT
  # TRT/fonts is the full seed folder, but they're too big
  cp TRT/fonts/TestKERNOne.otf seeds/
  cp TRT/fonts/TestGLYFOne.ttf seeds/
  rm -fr TRT
fi

DIR_IN=$SUBJECT/seeds
DIR_OUT=$DOWNLOAD_DIR/out
if [ -d $DIR_OUT ]; then
  rm -rf $DIR_OUT
fi
/usr/bin/time -a -o time.txt $AFLGO/afl-fuzz -S ${TARGET}_result -z exp -c $TIME -i $DIR_IN -o $DIR_OUT -E $TMP_DIR -x $AFLGO/dictionaries/png.dict $SUBJECT/${TARGET}_profiled @@
!
popd
