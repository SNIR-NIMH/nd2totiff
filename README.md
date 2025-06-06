# Nikon Biopipeline ND2 to TIFF converion


<!-- ABOUT THE PROJECT -->
## About The Project

Nikon Biopipeline provides Widefield images using arbitrarily drawn ROIs.
This pipeline takes an unstitched tiled .nd2 file with multiple channels and multiple focal
points and does the following,
1. convert the nd2 file to tifs
2. for every tile, apply focus correction [[1]](#1) on the multiple z-planes using
```
https://github.com/sjawhar/focus-stacking
```
3. stitch the focus corrected tiles to create multi-channel 2D TIFF images.
4. generate a pyramidal TIFF for fast QA using NGFF converter,
```
https://github.com/glencoesoftware/NGFF-Converter
```
The stitching code is written in Matlab, and all the source files are also provided.


<!--Prerequisites -->
## Prerequisites
* Python 3.10: The code is tested on Anaconda 2023.03-1 version, which can be downloaded from here,
```
https://repo.anaconda.com/archive/
```
* Matlab Compiler Runtime (MCR): 64-bit Linux/Windows MCR installer for MATLAB 2022a (v912) is required
```
https://www.mathworks.com/products/compiler/matlab-runtime.html
```
* Java: If Java is not installed, download JDK-11 either from Oracle website with login, or from a login-free source
```
https://www.openlogic.com/openjdk-downloads
```
* Bioformats bftools.zip package: Either use the provided bftools 6.6.1 version or download from here
```
https://github.com/ome/bioformats/releases
```
* bioformats2raw-0.6.1: To convert 3D tiff to OMEZARR format
```
https://github.com/glencoesoftware/bioformats2raw/releases/download/v0.6.1/bioformats2raw-0.6.1.zip
```
* raw2ometiff-0.4.1: To convert OMEZARR to 3D pyramidal tiff
```
https://github.com/glencoesoftware/raw2ometiff/releases/download/v0.4.1/raw2ometiff-0.4.1.zip
```

## Installation

Detailed installation instructions for both Linux and Windows versions are provided in the corresponding README files 
within Linux or Windows folders. Windows installation will require
administrator privilege, which Linux installation can be done as a regular user.


<!-- USAGE EXAMPLES -->
## Usage
After all successful installations, the conversion can be done via a GUI. Run the following command in a terminal
on Linux or an Anaconda prompt on Windows after changing to the relevant folder (pushd C:/myfolder/nd2totiff)
```
python nikon_biopipeline_processing_gui.py
```
It should bring up a GUI
<p align="center">
  <img src="https://github.com/SNIR-NIMH/nd2totiff/blob/main/imgs/GUI.png" height="250"/>  
</p>

The input can either be a folder containing multiple ND2 files or a single ND2 file.
If input is a folder, any ND2 file within it containing the word "Overview" will not be processed
as they are not the tiled images. Only images with the word "Region" will be processed. These are 
hardcoded in the *nikon_biopipeline_processing.py* script into L344-356. Feel free to change the 
check strings as needed.

Only 4 images are processed in parallel (hardcoded). Each image can use any number of CPUs, the
default is kept at 12. Change it according to the computer spec.

For command line usage, use
```
python nikon_biopipeline_processing.py -h
usage: nikon_biopipeline_processing.py [-h] -i INPUT -o OUTPUTDIR [-n NUMCPU]

EDF & Stitching of ND2 files to Pyramidal TIF

options:
  -h, --help    show this help message and exit
  -i INPUT      Input ND2 file or a folder containing multiple ND2 files. If it is a folder, then the
                ND2 files will be processed 4 at a time, each using NUMCPU parallel processes.
  -o OUTPUTDIR  Output folder
  -n NUMCPU     (Optional) Number of CPUs to use for parallel processing for each image. Default 12
```

<!-- Example Data -->
## Example Data
Two example datasets are provided, one small (11027x12842x3px) and one big (62308x92310x2px).
```
http://hpc.nih.gov/~NIMH_MHSNIR/smalldata.zip
http://hpc.nih.gov/~NIMH_MHSNIR/bigdata.zip
```
The small one has 6x7 mosaic with 38 tiles, each 1952x1952px, having 0.32 x 0.32 µm resolution.
The big one has 29x43 mosaic with 1005 tiles, each 2304x2304px, having 0.16 x 0.16 µm µm resolution.

<p align="center">
  <img src="https://github.com/SNIR-NIMH/nd2totiff/blob/main/imgs/bigdata.png" height="500"/>  
</p>

<!-- NOTES -->
## Notes

1. While converting non-pyramidal tif to OMEZARR, the following tile height and width are used
   in bioformats2raw,
   ```
    -h 8192 -w 8192
   ```
   As opposed to the default 1024, we specifically used tile size of 8192
   to reduce the number of zarr files, while increasing each file size from 2MB
   to 128MB. This decreases total file write time, specially on
   spinning disks as less number of files are to be written in a folder. However,
   for very large images, the default Java heap space can be limited and
   *java.lang.OutOfMemoryError: Java heap space* can occur. To fix it, either set the
   JAVA_OPTS environment variable to accommodate max 100GB RAM.
   ```
   setenv JAVA_OPTS "-Xms10g -Xmx100g"
   ```
   or change the tile height and width back to 1024.

<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTACT -->
## Contact

Snehashis Roy - email@snehashis.roy@nih.gov

<p align="right">(<a href="#readme-top">back to top</a>)</p>


<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- REFERENCE -->
## References
<a id="1">[1]</a> 
W. Wang, F. Chang (2011)
A Multi-focus Image Fusion Method Based on Laplacian Pyramid.
Journal of Computers.
https://doi.org/10.4304/jcp.6.12.2559-2566

https://www.oalib.com/research/2334325

