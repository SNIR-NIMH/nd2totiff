Requirements:
1. pip install nd2
2. pip install opencv-python
2. Enable "Developer Mode" (requires admin access). 
    (a) Open Windows Settings.
    (b) Search for Developer settings or Go to Update & Settings then For developers.
    (c) Toggle the Developer Mode setting, at the top of the "For developers" page
3. Install Matlab Compiler Runtime (MCR) for R2022a (v 9.12) (requires admin access).
    (a) Download from here, https://www.mathworks.com/products/compiler/matlab-runtime.html
    (b) Install to a suitable location.
    (c) If installed with admin access, it is automatically added to system PATH.
4. If Java JDK is not already installed, install Java JDK-11 
   (a) Download openjdk-11.0.2_windows-x64_bin.zip. It can be downloaded from 
   here without a login https://www.openlogic.com/openjdk-downloads
   (b) Extract to some folder, e.g. C:\Program Files\Java\jdk-11
5. Add that folder to Windows PATH
   (a) Search for Edit Environ Variables (requires admin access). 
   (b) Edit the "System variables" Path (not the User variables Path)
   (c) Add a new path and add C:\Program Files\Java\jdk-11

Pytiff isn't supported on Windows (or is it too complicated to compile from source?).
Therefore, import pytiff is commented out inside extended_depth_of_field_correction.py
