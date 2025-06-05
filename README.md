# Nikon Biopipeline ND2 to TIFF converion


<!-- ABOUT THE PROJECT -->
## About The Project

Nikon Biopipeline provides Widefield images using arbitrarily drawn ROIs.
This pipeline takes an unstitched .nd2 file with multiple channels and focal
points and 
1. applies focus correction  on the multiple z-planes
   https://github.com/sjawhar/focus-stacking

2. stitches the tiles to create multi-channel 2D TIFF images
3. generates a pyramidal TIFF for faster QA using NGFF converter
   https://github.com/glencoesoftware/NGFF-Converter


<!-- GETTING STARTED -->
## Getting Started



### Prerequisites
* Python ND2 library https://pypi.org/project/nd2/
```
pip install nd2
pip install opencv-python
```
* Matlab Compiler Runtime (MCR): Download the 64-bit Linux MCR installer for MATLAB 2023a (v914).
```
https://www.mathworks.com/products/compiler/matlab-runtime.html
```
* Java JDK-11: Either download from Oracle website with login, or from a free source
```
https://www.openlogic.com/openjdk-downloads
```
* Bioformats bftools.zip package: Either use the provided bftools 6.6.1 version or download from here
```
https://github.com/ome/bioformats/releases
```
* bioformats2raw-0.6.1
```
https://github.com/glencoesoftware/bioformats2raw/releases/download/v0.6.1/bioformats2raw-0.6.1.zip
```
* raw2ometiff-0.4.1
```
https://github.com/glencoesoftware/raw2ometiff/releases/download/v0.4.1/raw2ometiff-0.4.1.zip
```

### Installation

1. Install the MCR (v914) to somewhere suitable. For Linux, 

2. Add the MCR installation path, i.e. the v912 directory, to all of the included shell scripts' MCRROOT variable. 
In each of the 16 shell scripts, replace the line containing ```MCRROOT=/usr/local/matlab-compiler/v912```
to the path where the MCR is installed, e.g.,
```
MCRROOT=/home/user/MCR/v912
```
if the MCR is installed in ```/home/user/MCR```.

3. Install ANTs binaries and add the binary path to shell \$PATH
```
export PATH=/home/user/ANTs-2.2.0/install/bin:${PATH}
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- USAGE EXAMPLES -->
## Usage



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

