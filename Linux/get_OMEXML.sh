#!/bin/bash

exe_name=$0
exe_dir=`dirname "$0"`

check_modules () {  # check if ANTs binaries are correctly added to $PATH
    FUNC=$1    
    if ! [ -x "$(command -v "$FUNC")" ]; then
        echo "
    Error: $FUNC is not installed. Please add $FUNC to PATH.
        "
        exit 1
    fi
}

get_extension (){
    NAME=$1    
    EXT=`echo $NAME | tr "."  "\n" |tail -1`  # trim by dot, get the last one, but does not work for tar.gz, which
    # gives only .gz. But this should be fine for practical purpose
    echo $EXT
    
}
BF2RAW=${exe_dir}/bioformats2raw-0.6.1/bin/bioformats2raw
XMLINDENT=${exe_dir}/bftools/xmlindent
check_modules $BF2RAW
check_modules $XMLINDENT


if [ $# -lt "2" ];then
    echo "Usage:
    ./get_OMEXML.sh  INPUT   OUTPUT.xml
    
    INPUT     A nd2/czi file from where the OMEXML file will be obtained
    OUTPUT    Output OMEXML xml file
    
    "
    exit 1
fi

INPUT=$1
OUTPUT=$2
ext=`get_extension $OUTPUT`



if [ "$ext" != "xml" ] && [ "$ext" != "XML" ];then
    echo "ERROR: Output must be an xml file."
    exit 1
fi
X=`dirname $OUTPUT`
mkdir -p $X

TMPDIR=`mktemp -u`
#echo "Temporary directory $TMPDIR"
# xmlindent is from bftools package, add its locations to $PATH

#echo $BF2RAW -c null -h 1024 -w 1024 --max_workers 2 --no-nested -r 0 --target-min-size=512 -p \"$INPUT\" $TMPDIR 
$BF2RAW -c null -h 1024 -w 1024 --max_workers 2 --no-nested -r 0 --target-min-size=512 -p "$INPUT" $TMPDIR > /dev/null


${XMLINDENT} $TMPDIR/OME/METADATA.ome.xml > $OUTPUT
#mv -vf $TMPDIR/OME/METADATA.ome.xml  $OUTPUT

rm -rf $TMPDIR
