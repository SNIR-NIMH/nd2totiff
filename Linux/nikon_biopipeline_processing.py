import nd2
import os
import sys
import tempfile
from skimage.io import imsave
import argparse
from tqdm import tqdm
from glob import  glob
from joblib import  Parallel, delayed
import logging
import shutil
from datetime import  datetime

import platform
system = platform.system()


ROOT=os.path.realpath(os.path.dirname(__file__))
#logger = logging.getLogger(__name__)

edfscript = 'extended_depth_of_field_correction.py'
if system == 'Linux':
    stitchscript1 = 'nikon_biopipeline_stitch.sh'
    stitchscript2 = 'nikon_biopipeline_stitch'
elif system == 'Windows':
    stitchscript1 = 'nikon_biopipeline_stitch.exe'
    stitchscript2 = 'nikon_biopipeline_stitch.exe'
xmlscript = 'get_OMEXML.sh'
bf2raw = os.path.join('bioformats2raw-0.6.1','bin','bioformats2raw')
raw2tif = os.path.join('raw2ometiff-0.4.1','bin','raw2ometiff')
bftools = 'bftools'
if system == 'Linux':
    to3D1 = 'save2Dtiffstackto3D'
    to3D2 = 'save2Dtiffstackto3D.sh'
elif system == 'Windows':
    to3D1 = 'save2Dtiffstackto3D.exe'
    to3D2 = 'save2Dtiffstackto3D.exe'

def check_file(filename):
    x=os.path.isfile(os.path.join(ROOT,filename))
    y=os.path.isdir(os.path.join(ROOT,filename))
    if x == False and y==False:
        sys.exit('ERROR: {} is not found in the script directory {}'.format(filename,ROOT))


check_file(edfscript)
check_file(stitchscript1)
check_file(stitchscript2)
check_file(xmlscript)
check_file(bf2raw)
check_file(raw2tif)
check_file(to3D1)
check_file(to3D2)
check_file(bftools)





def EDF(inputfilename,outputdir, logfile):

    a = os.path.basename(inputfilename)
    a,_ = os.path.splitext(a)
    a = a + '_EDF.tif'
    outputname = os.path.join(outputdir,a)
    edfscript = 'extended_depth_of_field_correction.py'
    edfscript = os.path.join(ROOT, edfscript)
    if system == 'Linux':
        cmd = 'python ' + edfscript + ' -i="' + inputfilename + '" -o="' + outputname + '" > /dev/null 2>&1'
    elif system == 'Windows':
        cmd = 'python ' + edfscript + ' -i="' + inputfilename + '" -o="' + outputname + '" > NUL 2>&1'
    logging.info(cmd)
    #print(cmd)
    with open(logfile,'a') as f:
        print(cmd,file=f)
    os.system(cmd)


def edf_stitch_one_image(nd2file,outputdir,numcpu=8):
    if nd2file is not None:
        tmp = tempfile.NamedTemporaryFile()
        tmpname = tmp.name + ".nd2"
        print('Creating symlink of {} to {}'.format(nd2file,tmpname))
        os.symlink(nd2file, tmpname)  # This is absolutely essential because the filepath can contain space, which will
        # not work downstream in the os.system() commands

        ID, _ = os.path.splitext(os.path.basename(nd2file))

        os.makedirs(outputdir, exist_ok=True)

        logfile = ID + '.log.txt'
        logfile = os.path.join(outputdir, logfile)
        logging.basicConfig(handlers=[logging.StreamHandler(sys.stdout), logging.FileHandler(logfile, mode="w")],
                            level=logging.INFO, format='')

        a = nd2.ND2File(nd2file)  # Axes order NZCYX, N=number of tiles, Z=z/focal points, C=channel,
        logging.info(a.sizes)

        try:
            N = a.sizes['P']  # Number of tiles
        except:
            N = 1
        try:
            C = a.sizes['C']  # Number of channels
            rgb = False
        except:
            try:
                C = a.sizes['S']
                rgb = True
            except:
                C = 1
                rgb = False
        try:
            Z = a.sizes['Z']  # number of z, i.e. number of focal points
        except:
            Z = 1
            logging.info('WARNING: No z-slices, i.e. focal points, found. EDF is not necessary.')
        H = a.sizes['X']
        W = a.sizes['Y']

        if rgb:
            s = 'Image dimension (HxWxDxCxN) = ' + str(H) + 'x' + str(W) + 'x' + str(Z) + 'x' + str(C) + 'x' + str(N) + '(RGB)'
            logging.info(s)
            #logging.info('ROR: RGB image is not supported for the time being.')
            #sys.exit()
            # print('Image dimension (HxWxDxCxN) = {}x{}x{}x{}x{} (RGB)'.format(H,W,Z,C,N))
        else:
            s = 'Image dimension (HxWxDxCxN) = ' + str(H) + 'x' + str(W) + 'x' + str(Z) + 'x' + str(C) + 'x' + str(N)
            logging.info(s)
            # print('Image dimension (HxWxDxCxN) = {}x{}x{}x{}x{}'.format(H,W,Z,C,N))

        a.close()

        edfscript = 'extended_depth_of_field_correction.py'
        if system == 'Linux':
            stitchscript1 = 'nikon_biopipeline_stitch.sh'
            stitchscript2 = 'nikon_biopipeline_stitch'
        elif system == 'Windows':
            stitchscript1 = 'nikon_biopipeline_stitch.exe'
            stitchscript2 = 'nikon_biopipeline_stitch.exe'
        xmlscript = 'get_OMEXML.sh'
        bf2raw = os.path.join('bioformats2raw-0.6.1','bin','bioformats2raw')
        raw2tif = os.path.join('raw2ometiff-0.4.1', 'bin', 'raw2ometiff')
        if system == 'Linux':
            #to3D1 = 'save2Dtiffstackto3D'
            to3D2 = 'save2Dtiffstackto3D.sh'
        elif system == 'Windows':
            #to3D1 = 'save2Dtiffstackto3D.exe'
            to3D2 = 'save2Dtiffstackto3D.exe'

        tifdir = os.path.join(outputdir, 'tifs')
        edfdir = os.path.join(outputdir, 'EDF')
        bftools = os.path.join(ROOT, 'bftools')
        stitchdir = os.path.join(outputdir, 'stitched')

        xmlscript = os.path.join(ROOT, xmlscript)
        stitchscript1 = os.path.join(ROOT, stitchscript1)
        stitchscript2 = os.path.join(ROOT, stitchscript2)
        bf2raw = os.path.join(ROOT, bf2raw)
        raw2tif = os.path.join(ROOT, raw2tif)
        to3D2 = os.path.join(ROOT, to3D2)
        xmlindent = os.path.join(bftools,'xmlindent')

        os.makedirs(tifdir, exist_ok=True)
        os.makedirs(edfdir, exist_ok=True)
        os.makedirs(stitchdir, exist_ok=True)

        xmlfilename = ID + '.xml'
        xmlfilename = os.path.join(outputdir, xmlfilename)
        if system == 'Linux':
            s = xmlscript + ' ' + tmpname + ' ' + xmlfilename + ' |tee -a ' + logfile
            logging.info(s)
            print(s)
            os.system(s)
        elif system == 'Windows':
            x1 = tempfile.NamedTemporaryFile()
            x1 = x1.name
            s1 = bf2raw + ' -c null -h  1024 -w 1024 --max_workers  2 --no-nested -r 0 --target-min-size=512 -p ' + \
            ' --memo-directory="' + x1 + '"  "'  + nd2file  + '" ' + x1
            print(s1)
            logging.info(s1)
            os.system(s1)
            s2 = xmlindent + ' ' + os.path.join(x1,'OME','METADATA.ome.xml') + ' >  ' + xmlfilename
            logging.info(s2)
            print(s2)
            os.system(s2)
            shutil.rmtree(x1)



        x = nd2.imread(nd2file, dask=True)
        # print('Image shape : {}'.format(x.shape))
        s = 'Image shape : ' + str(x.shape)
        logging.info(s)

        if rgb is False:  # It is 5D image with NZCXY

            # nd2 to tif
            logging.info('Converting ND2 to tifs:')
            if Z>1:
                for n in tqdm(range(N)):
                    for c in range(0, C):
                        vol = x[n, :, c, :, :]
                        s = 'C' + str(c).zfill(2) + '_Tile' + str(n + 1).zfill(6) + '.tif'
                        s = os.path.join(tifdir, s)
                        imsave(s, vol, check_contrast=False, compression=0)
            else:
                for n in tqdm(range(N)):
                    for c in range(0, C):
                        vol = x[n, c, :, :]
                        s = 'C' + str(c).zfill(2) + '_Tile' + str(n + 1).zfill(6) + '.tif'
                        s = os.path.join(tifdir, s)
                        imsave(s, vol, check_contrast=False, compression=0)
        else:
            for n in tqdm(range(0, N)):
                for c in range(0, C):
                    vol = x[n, :, :, c]
                    s = 'C' + str(c).zfill(2) + '_Tile' + str(n + 1).zfill(6) + '.tif'
                    s = os.path.join(tifdir, s)
                    imsave(s, vol, check_contrast=False, compression=0)  # These are RGB 3 channel images, no EDF needed

        # EDF
        if Z > 1:
            logging.info('Computing EDF:')
            inputfilenames = sorted(glob(os.path.join(tifdir, '*.tif')))
            # print(len(inputfilenames))
            Parallel(n_jobs=numcpu)(delayed(EDF)(a, edfdir, logfile)
                                            for a in inputfilenames
                                            )
        else:
            logging.info('Copying tifs into EDF folder (no EDF needed):')
            inputfilenames = sorted(glob(os.path.join(tifdir, '*.tif')))
            for i in range(0,len(inputfilenames)):
                a = os.path.basename(inputfilenames[i])
                a, _ = os.path.splitext(a)
                a = a + '_EDF.tif'
                outputname = os.path.join(edfdir, a)
                shutil.copyfile(inputfilenames[i],outputname)


        logging.info('Stitching:')
        if system == 'Linux':
            s = stitchscript1 + ' ' + xmlfilename + ' ' + edfdir + ' ' + stitchdir + ' |tee -a ' + logfile
        elif system == 'Windows':
            s = stitchscript2 + ' ' + xmlfilename + ' ' + edfdir + ' ' + stitchdir
        logging.info(s)
        print(s)
        os.system(s)

        logging.info('Converting 2D slices to 3D tif to generate pyramid tif:')
        s1 = ID + '_stitched.tif'
        s2 = ID + '_stitched.ome.tif'
        stitchedfile = os.path.join(outputdir, s1)
        stitchedpyramidfile = os.path.join(outputdir, s2)
        if system == 'Linux':
            s = to3D2 + ' ' + stitchdir + ' ' + stitchedfile + ' no' + ' |tee -a ' + logfile
        elif system == 'Windows':
            s = to3D2 + ' ' + stitchdir + ' ' + stitchedfile + ' no'
        logging.info(s)
        print(s)
        os.system(s)

        logging.info('Bioformats2Raw: Converting to OMEZARR:')
        tmp = tempfile.NamedTemporaryFile()
        tmpname2 = os.path.basename(tmp.name)
        tmpdir = os.path.join(stitchdir, tmpname2)

        if system == 'Linux':
            s = bf2raw + ' -c null -h 8192 -w 8192 --max_workers ' + str(numcpu)  \
                + ' --no-nested -r 6 --target-min-size=1024  -p ' + \
                stitchedfile + ' ' + tmpdir + ' |tee -a ' + logfile
        elif system == 'Windows':
            s = bf2raw + ' -c null -h 8192 -w 8192 --max_workers ' + str(numcpu) \
                + ' --no-nested -r 6 --target-min-size=1024  -p ' + \
                stitchedfile + ' ' + tmpdir
        logging.info(s)
        print(s)
        os.system(s)

        logging.info('Raw2OMETIFF: Converting OMEZARR to pyramidal tif:')
        if system == 'Linux':
            s = raw2tif + ' --compression uncompressed  --max_workers=' + str(numcpu) + ' -p ' + tmpdir + ' ' + \
                stitchedpyramidfile + ' |tee -a ' + logfile
        elif system == 'Windows':
            s = raw2tif + ' --compression uncompressed  --max_workers=' + str(numcpu) + ' -p ' + tmpdir + ' ' + \
                stitchedpyramidfile
        logging.info(s)
        print(s)
        os.system(s)

        shutil.rmtree(tmpdir)
        #os.remove(stitchedfile)
        shutil.rmtree(tifdir)
        shutil.rmtree(edfdir)
        os.remove(xmlfilename)






parser = argparse.ArgumentParser(description='EDF & Stitching of ND2 files to Pyramidal TIF')

# Required inputs
parser.add_argument('-i', required=True, dest='INPUT', type=str,
                    help='Input ND2 file or a folder containing multiple ND2 files. If it is a folder, '
                         'then the ND2 files will be processed 4 at a time, each using NUMCPU parallel processes.')

parser.add_argument('-o', required=True, action='store', dest='OUTPUTDIR',
                    help='Output folder')
# Optional inputs
parser.add_argument('-n', required=False, action='store', type=int, dest='NUMCPU', default=12,
                    help='(Optional) Number of CPUs to use for parallel processing for each image. Default 12')


if len(sys.argv) < 2:
    parser.print_usage()
    sys.exit(1)

result = parser.parse_args()

result.INPUT = os.path.realpath(os.path.expanduser(result.INPUT))
result.OUTPUTDIR = os.path.realpath(os.path.expanduser(result.OUTPUTDIR))


if os.path.isdir(result.OUTPUTDIR) == False:
    os.makedirs(result.OUTPUTDIR, exist_ok=True)


start_time = datetime.now()
if os.path.isfile(result.INPUT):
    ID = os.path.basename(result.INPUT)
    ID, _ = os.path.splitext(ID)
    s = os.path.join(result.OUTPUTDIR, ID)
    edf_stitch_one_image(result.INPUT,s,result.NUMCPU)
    end_time = datetime.now()
    print('Total time taken to process 1 image: {}'.format(end_time - start_time))

elif os.path.isdir(result.INPUT):
    s=os.path.join(result.INPUT,'*.nd2')

    filelist = sorted(glob(s))
    checkstring = "Region"
    rmstring = "Overview"
    outputfolderlist=[None]*len(filelist)
    for i in range(len(filelist)):
        if checkstring in filelist[i] and rmstring not in filelist[i]:
            ID = os.path.basename(filelist[i])
            ID, _ = os.path.splitext(ID)
            s = os.path.join(result.OUTPUTDIR,ID)
            outputfolderlist[i] = s
        else:
            filelist[i] = None

    for i in range(len(filelist)):
        if filelist[i] is not None:
            print(filelist[i])

    #pprint(outputfolderlist)
    # Parallel process all files 4 at a time, hardcoded
    Parallel(n_jobs=4)(delayed(edf_stitch_one_image)(a, b, result.NUMCPU)
                                                  for a,b in zip(filelist,outputfolderlist)
                                                  )

    end_time = datetime.now()
    print('Total time taken to process {} images: {}'.format(len(filelist),end_time - start_time))