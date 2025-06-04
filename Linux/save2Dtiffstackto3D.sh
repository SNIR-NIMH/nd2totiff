#!/bin/bash
exe_name=$0
exe_name=`readlink -f $exe_name`
exe_dir=`dirname "$exe_name"`

if [ $# -lt "2" ]; then
  echo "Usage:
  ./save2Dtiffstackto3D.sh INPUT_TIF_DIR OUTPUT_TIF COMPRESS  OUTPUTTYPE
  
  INPUT_TIF_DIR   A directory containing multiple tif files , e.g. /home/user/some_folder/
  OUTPUTTIF       Output 3D tif file, e.g., /home/user/some_file.tif
  COMPRESS        yes or no flag, if the output tif image is compressed or not
  OUTPUTTYPE      (Optional) Either uint16 (default) or float32.
  
  ** This is a memory \"inefficient\" 2D-to-3D conversion script. The total required
  memory is the total size of the tif file. For memory efficient 2D-to-3D tif 
  conversion for files that are bigger than available RAM, use save4dTiff.sh script.
  "
  exit 1
fi
MCRROOT=/usr/local/matlab-compiler/v912
export MCR_INHIBIT_CTF_LOCK=1  
export MCR_CACHE_ROOT=/tmp/mcr_${USER}_${RANDOM}
mkdir -p ${MCR_CACHE_ROOT}


args=
while [ $# -gt 0 ]; do
    token=$1
    args="${args} ${token}" 
    shift
done

LD_LIBRARY_PATH=.:${MCRROOT}/runtime/glnxa64 ;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/bin/glnxa64 ;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/sys/os/glnxa64;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/sys/opengl/lib/glnxa64;
export LD_LIBRARY_PATH;

${exe_dir}/save2Dtiffstackto3D $args
rm -rf ${MCR_CACHE_ROOT}

