Requirements:
1. pip install nd2
2. pip install pytiff 
    (a) It requires a GCC compiler (preferably 11.x)
    (b) and libtiff-4.x. 
    The code is tested with GCC-11.3.0 and libtiff 4.6.0, can be downloaded from here,
    https://download.osgeo.org/libtiff/tiff-4.6.0.zip
    Compile libtiff-4.6.0, install to a local folder, and add the lib folder in 
    your LD_LIBRARY_PATH and include folder in CPATH variable. Installation of pytiff
    requires libtiff.so and tiffconf.h/tiff.h/tiffio.h
3. pip install opencv-python
4. bioformats2raw-0.6.1, download from here,
    (a) https://github.com/glencoesoftware/bioformats2raw/releases/download/v0.6.1/bioformats2raw-0.6.1.zip
    (b) Unzip into this folder
5. raw2ometiff-0.4.1, download from here,
    (a) https://github.com/glencoesoftware/raw2ometiff/releases/download/v0.4.1/raw2ometiff-0.4.1.zip
    (b) Unzip into this folder
6. bftools package, 
    (a) Either unzip the provided bftools.zip containing Bioformats 6.6.1
    OR
    (b) Download suitable bftools.zip from here https://github.com/ome/bioformats/releases
7. Matlab Compiler Runtime (MCR) for R2022a (v 9.12)
    (a) Download from here, https://www.mathworks.com/products/compiler/matlab-runtime.html
    (b) Install into a suitable location, e.g. /home/user/my_mcr_folder/
     Default is /usr/local/matlab-compiler/
    (c) Change the installation locations inside nikon_biopipeline_stitch.sh and
    save2Dtiffstackto3D.sh scripts, i.e. change the following line,
    MCRROOT=/usr/local/matlab-compiler/v912
    to
    MCRROOT=/home/user/my_mcr_folder/v912
    Note, the MCRROOT must contain the path to the "v912" folder.
8. If Java is not already installed, install Java JDK-11 
   (a) Download openjdk-11 for 64bit Linux. It can be downloaded from 
   here without a login https://www.openlogic.com/openjdk-downloads
   (b) Extract to some folder and add that folder (containing bin and lib)
   to the environment variable JAVA_HOME
    
* The specific versions of bioformats2raw, bftools, and raw2ometiff are of no 
particular significance. They just have been frozen for a long time and work as expected.
* Technically, pytiff isn't required if compiling libtiff is too much of a hassle.
Simply use the extended_depth_of_field_correction.py script from Windows folder.
* Administrator access is not required and not recommended.
