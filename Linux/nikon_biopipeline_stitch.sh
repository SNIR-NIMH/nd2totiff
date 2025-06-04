#!/bin/bash
exe_name=$0
exe_dir=`dirname "$0"`

if [ $# -lt "3" ]; then
    echo "Usage:
    ./nikon_biopipeline_stitch.sh  XMLFile  EDFDIR  OUTPUTDIR  

 XMLFile       The OMEXML file generated from the ND2 file. Use the get_OMEXML.sh
               script to generate the OMEXML.xml file
               
 EDFDIR        The EDF directory created by nikon_biopipeline_EDF.sh script
               where all EDFs from all channels are located. If you have used
               nikon_biopipeline_noEDF.sh script to create each of the focus points
               separately, use the ZStackLoop_0xx folders as EDFDIR
               
 OUTPUTDIR     Output directory where stitched images will be written with CXX.tif
              format, i.e. one channel per file. Existing files with same names 
              *WILL* be overwritten, so use an empty directory if needed.
              
 UID           (Optional) A unique id for the image that will be appended
               at the end of each channel. This is useful if there are many
               ZStackLooop images. 

 

    "
    exit 1
fi
  
  
export MCR_INHIBIT_CTF_LOCK=1
export MCR_CACHE_ROOT=/tmp/mcr_${USER}_${RANDOM}
mkdir -p ${MCR_CACHE_ROOT}
MCRROOT=/usr/local/matlab-compiler/v912
LD_LIBRARY_PATH=.:${MCRROOT}/runtime/glnxa64 ;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/bin/glnxa64 ;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/sys/os/glnxa64;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/sys/opengl/lib/glnxa64;
export LD_LIBRARY_PATH;

args=
while [ $# -gt 0 ]; do
  token=$1
  args="${args} ${token}" 
  shift
done
#RAND=`echo $RANDOM`
#RAND=$((RAND % 30))  
#sleep $RAND

${exe_dir}/nikon_biopipeline_stitch $args

rm -rf ${MCR_CACHE_ROOT}
