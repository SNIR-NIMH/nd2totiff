import os, sys
os.environ['OPENBLAS_NUM_THREADS'] = '4'
# See https://stackoverflow.com/questions/52026652/openblas-blas-thread-init-pthread-create-resource-temporarily-unavailable
# If running multiple EDF scripts, OpenBLAS error can occur
from skimage.io import imread, imsave
import logging
from PIL import Image
from tqdm import  tqdm
from pytiff import  Tiff
logging.getLogger('requests').setLevel(logging.CRITICAL)
import argparse
from glob import glob
import gc

import numpy as np
PATH=os.path.dirname(__file__)
PATH=os.path.join(PATH,'focus-stacking')

# I have made many changes in the __init__.py file from the original Github content.
# So use the modified one from Biowulf, don't use the original ones. Original one WILL NOT work
# because it was meant for color images
if os.path.isdir(PATH) == False:
    sys.exit('ERROR: focus-stacking is not found. Please download it from here : '
             'https://github.com/sjawhar/focus-stacking and put in the same folder as this script')
sys.path.append(PATH)
import focus_stack as stk
import time
#from dask import delayed
import psutil
from multiprocessing import Process, Queue
#import libtiff
#libtiff.libtiff_ctypes.suppress_warnings()

def read_part_tif(input,I1,I2,J1,J2,k,bkend):
    if os.path.isfile(input):
        if bkend == 'pytiff':
            handle = Tiff(input)
            handle.set_page(k)
            x = np.asarray(handle[I1:I2, J1:J2], dtype=np.uint16)
            handle.close()
        else:
            x = imread(input,img_num=k, is_ome=False, plugin='tifffile')
            x = x[I1:I2, J1:J2]
    else:
        filelist = sorted(glob(os.path.join(input, '*.tif')))
        x = np.asarray(imread(filelist[k], is_ome=False), dtype=np.uint16) # Reading 2D file is always faster for imread
        x = x[I1:I2, J1:J2]

        #return x
    Q.put(x)



if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Fix focus of Widefield images (NOT applicable for Lightsheet images)',
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('-i', required=True, action='store', dest='INPUT', type=str,
                        help='Input tiff image, either a 3D tif or a folder containing multiple tifs. The tifs '
                             'must correspond to the same slice, but with different focal regions.')
    parser.add_argument('-o', dest='OUTPUT', type=str, required=True,
                        help='A tif image, e.g., /home/user/somefile.tif')
    parser.add_argument('-c', dest='COMPRESS', type=int, required=False, default=1,
                        help='compression, either 1 (compression with Deflate) or 0 (no compression).')
    parser.add_argument('--float', dest='FLOAT', action = 'store_true',
                        help='If mentioned, the final image will be saved as FLOAT. Without this '
                             'argument, default format is UINT16')
    parser.add_argument('--chunks', dest='CHUNKS', nargs='+', type=int, default=[1, 1],
                        help='Number of chunks in height and width, default --chunks 1 1, i.e. no chunking. '
                             'Use chunking if the image size is too big.')
    parser.add_argument('--backend', dest='BACKEND', default='pytiff',
                        help='Either use pytiff or skimage (scikit-image io.imread) to read images. OME-TIFF images usually can not be '
                             'read with pytiff, use skimage in that case. Default is pytiff (faster). Note that skimage is '
                             'usually slower than pytiff')
    result = parser.parse_args()

    t1 = time.time()
    if str(result.BACKEND).lower() not in ['pytiff','skimage']:
        print('ERROR: Backend must be pytiff or skimage. You entered {} '.format(result.BACKEND))
        sys.exit()


    if os.path.isfile(result.INPUT):
        if str(result.BACKEND).lower() == 'pytiff':  # pytiff isn't supported on Windows
            handle = Tiff(result.INPUT)
            dim = (handle.size[0], handle.size[1], handle.number_of_pages)
            handle.close()
        else:
            #img = Image.open(result.INPUT)
            #k = img.n_frames
            #img = np.asarray(img)
            #dim = (img.shape[0], img.shape[1], k)

            # imread will read the whole image, but Pillow's Image.Open will only read the header.
            # So Pillow is definitely faster than imread. But in some cases, Pillow will fail to read
            # So it is safe to use imread to read the header
            img = np.asarray(imread(result.INPUT, plugin='tifffile'), dtype=np.uint16)
            dim = np.array(img).shape
            if dim[2] != 3: # If there are 3 z-slices/focus planes, imread considers it as an RGB image
                dim = (dim[1],dim[2],dim[0])  # skimage.io has channel first except for color images
            del img
            gc.collect()



    elif os.path.isdir(result.INPUT):
        filelist=sorted(glob(os.path.join(result.INPUT,'*.tif')))

        x=imread(filelist[-1], is_ome=False) # imread is way faster than pytiff's Tiff
        dim = list(x.shape)
        dim = [dim[0],dim[1],len(filelist)]

    else:
        sys.exit('ERROR: Input image {} does not exist.'.format(result.INPUT))

    print('Input image size = {} (HxWxD)'.format(dim))

    if result.COMPRESS > 0:
        result.COMPRESS='zlib'


    if result.CHUNKS[0] == 1 and result.CHUNKS[1] ==1:
        stack =[]
        if os.path.isfile(result.INPUT):
            if str(result.BACKEND).lower() == 'pytiff':
                handle = Tiff(result.INPUT)
        print('Reading file {}'.format(result.INPUT))
        for k in range(dim[2]):
            if os.path.isfile(result.INPUT):
                if str(result.BACKEND).lower() == 'pytiff':
                    handle.set_page(k)
                    stack.append(np.asarray(handle[:], dtype=np.uint16))
                else:
                    # If there are 3 z-slices/focus planes, imread considers it as an RGB image
                    if dim[2] != 3:
                        stack.append(np.asarray(imread(result.INPUT, img_num=k, is_ome=False, plugin='tifffile'), dtype=np.uint16))
                    else:
                        a = imread(result.INPUT, is_ome=False) # a is XY3 image, automatically considered as RGB is dim[2]==3
                        for u in range(dim[2]):
                            stack.append(a[:,:,u])
            else:
                stack.append(np.asarray(imread(filelist[k], is_ome=False, plugin='tifffile'), dtype=np.uint16))
        if os.path.isfile(result.INPUT):
            if str(result.BACKEND).lower() == 'pytiff':
                handle.close()
        print('Running EDF:')
        stacked = stk.stack_focus(images = stack, pyramid_min_size=256,
                choice = stk.CHOICE_PYRAMID,# these are not used when choice is Pyramid, but kept any way
                energy = stk.ENERGY_LAPLACIAN,
                kernel_size = 5, blur_size = 5, smooth_size = 32)
        if len(stacked.shape) == 3:
            stacked = stacked[:,:,0]

        if result.FLOAT == False:
            stacked[stacked<0] = 0
            stacked[stacked>65535]=65535
            stacked = np.asarray(stacked, dtype=np.uint16)
            print('Writing {} in UINT16 format'.format(result.OUTPUT))
        else:
            print('Writing {} in FLOAT32 format'.format(result.OUTPUT))
        dim=stacked.shape
        if 2 * np.prod(dim) < 4 * (1024 ** 3):
            imsave(result.OUTPUT, stacked, check_contrast=False, compression=result.COMPRESS, bigtiff=False)
        else:
            imsave(result.OUTPUT, stacked, check_contrast=False, compression=result.COMPRESS, bigtiff=True)


    else: # assume very big image, use memory efficient reading
        print('Number of chunks in height and width = %d x %d' %(result.CHUNKS[0], result.CHUNKS[1]))
        bkend = str(result.BACKEND).lower()
        d0 = dim[0]//result.CHUNKS[0]
        d1 = dim[1] // result.CHUNKS[1]
        padval = 128  # a small padding value for overlapping slices
        if d0<=padval or d1<=padval:
            sys.exit('ERROR: Too many chunks. Please reduce number of chunks or don''t use chunking for small images.')
        if result.FLOAT == False:
            outvol = np.zeros([dim[0], dim[1]], dtype=np.uint16)
        else:
            outvol = np.zeros([dim[0], dim[1]], dtype=np.float32)
        for i in range(0,result.CHUNKS[0]):
            for j in range(0,result.CHUNKS[1]):


                I1 = i*d0
                if i+1<result.CHUNKS[0]:
                    I2 = (i+1)*d0
                else:
                    I2 = dim[0]

                J1 = j*d1
                if j+1<result.CHUNKS[1]:
                    J2 = (j+1)*d1
                else:
                    J2 = dim[1]
                print('\n\nWorking on chunk %d x %d (chunk size = %d x %d) :' % (i + 1, j + 1,I2-I1, J2-J1))

                stack = []
                Q = Queue()
                print('Reading image:')

                for k in tqdm(range(dim[2])):  # Read image through a multiprocess which will destroy memory after returning
                                               # DO NOT use a return statement in function
                    if i>0 and j>0 and i+1<result.CHUNKS[0] and j+1<result.CHUNKS[1]:  # padding does not work on boundary chunks
                        p1 = Process(target=read_part_tif,
                                     args=(result.INPUT, I1 - padval, I2 + padval, J1 - padval, J2 + padval, k, bkend))
                    else:
                        p1 = Process(target=read_part_tif, args=(result.INPUT, I1, I2, J1, J2, k, bkend))
                    p1.start()
                    x = Q.get()
                    #print(x.shape)
                    p1.join()
                    stack.append(x)

                    #stack.append(read_part_tif(result.INPUT,I1,I2,J1,J2,k))
                    #print(psutil.Process(os.getpid()).memory_info().rss / 1024 ** 2)

                print('Running EDF:')
                stacked = stk.stack_focus(images=stack, pyramid_min_size=256,
                                          choice=stk.CHOICE_PYRAMID,
                                          # these are not used when choice is Pyramid, but kept any way
                                          energy=stk.ENERGY_LAPLACIAN,
                                          kernel_size=5, blur_size=5, smooth_size=32)
                if len(stacked.shape) == 3:
                    stacked = stacked[:, :, 0]

                if result.FLOAT == False:
                    stacked[stacked < 0] = 0
                    stacked[stacked > 65535] = 65535
                    stacked = np.asarray(stacked, dtype=np.uint16)

                if i > 0 and j > 0 and i + 1 < result.CHUNKS[0] and j + 1 < result.CHUNKS[1]:
                    stacked = stacked[128:-128,128:-128]
                outvol[I1:I2, J1:J2] = stacked


        if result.FLOAT == False:
            print('Writing {} in UINT16 format'.format(result.OUTPUT))
        else:
            print('Writing {} in FLOAT32 format'.format(result.OUTPUT))

        dim = outvol.shape
        if 2 * np.prod(dim) < 4 * (1024 ** 3):
            imsave(result.OUTPUT, outvol, check_contrast=False, compression=result.COMPRESS, bigtiff=False)
        else:
            imsave(result.OUTPUT, outvol, check_contrast=False, compression=result.COMPRESS, bigtiff=True)



    t2 = time.time()
    print('Total time taken = %d seconds' %(np.ceil(t2-t1)))