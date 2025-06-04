import numpy as np
import cv2
import  sys
from .pyramid import get_pyramid_fusion

ENERGY_SOBEL = "sobel"
ENERGY_LAPLACIAN = "laplacian"

CHOICE_PYRAMID = "pyramid"
CHOICE_MAX = "max"
CHOICE_AVERAGE = "average"

def stack_focus(
    images,
    choice = CHOICE_PYRAMID,
    energy = ENERGY_LAPLACIAN,
    pyramid_min_size = 32,
    kernel_size = 5,
    blur_size = 5,
    smooth_size = 32
):

    images = np.array(images, dtype=images[0].dtype)


    #aligned_images, gray_images = align(images)

    # ===================================================================================================

    # Assume that input images are already gray scale, so the first coordinate is number of images, and len(images)=3, DxHxW
    dim = list(images.shape)
    #dim.append(3)
    aligned_images = images
    gray_images = images

    #aligned_images = np.zeros(dim, dtype=images[0].dtype)
    #for c in range(0,3):
    #    aligned_images[:,:,:,c] = images

    #print(aligned_images.shape)
    #print(gray_images.shape)

    # ===================================================================================================


    if choice == CHOICE_PYRAMID:
        #print('Generating pyramid levels.')
        stacked_image = get_pyramid_fusion(aligned_images, pyramid_min_size)
        #print(np.amax(stacked_image))
        return  stacked_image
        #return cv2.convertScaleAbs(stacked_image)  # This is only for converting to 8bit.
    else:
        if energy == ENERGY_SOBEL:
            print('Step 1/5: Generating SOBEL maps.')
            energy_map = get_sobel_map(gray_images)
        else:
            print('Step 2/5: Generating Laplacian maps.')
            energy_map = get_laplacian_map(gray_images, kernel_size, blur_size)

        if smooth_size > 0:
            print('Step 3/5: Smoothing energy maps.')
            energy_map = smooth_energy_map(energy_map, smooth_size)

        print('Step 4/5: Generating focus map.')
        focus_map = get_focus_map(energy_map, choice)
        print('Step 5/5: Blending focus maps with images.')
        stacked_image = blend(aligned_images, focus_map)
        return stacked_image
        #return cv2.convertScaleAbs(stacked_image)

def align(images, iterations = 500, epsilon = 1e-5):
    def _get_homography(image_1, image_2):
        warp_matrix = np.eye(3, 3, dtype=np.float32)
        criteria = (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, iterations,  epsilon)
        _, homography = cv2.findTransformECC(image_1, image_2, warp_matrix, cv2.MOTION_HOMOGRAPHY, criteria, inputMask=None, gaussFiltSize=5)
        return homography
    
    def _warp(image, shape, homography):
        return cv2.warpPerspective(image, homography, shape, flags=cv2.INTER_LINEAR + cv2.WARP_INVERSE_MAP)
    
    def _convert_to_grayscale(image):
        if len(image.shape) == 3:

            return cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        else:

            return image  # 2D image, so already grascale
    
    gray_images = np.zeros(images.shape[:-1], dtype=np.uint16)
    gray_image_shape = gray_images[0].shape[::-1]
    
    aligned_images = np.zeros(images.shape, dtype=images.dtype)
    
    aligned_images[0] = images[0]
    gray_images[0] = _convert_to_grayscale(images[0])
    for index in range(1, images.shape[0]):
        image2_gray = _convert_to_grayscale(images[index])
        homography = _get_homography(gray_images[0], image2_gray)
        
        gray_images[index] = _warp(image2_gray, gray_image_shape, homography)
        aligned_images[index] = _warp(images[index], gray_image_shape, homography)

    return aligned_images, gray_images

def get_sobel_map(images):
    energies = np.zeros(images.shape, dtype=np.float32)
    for index in range(images.shape[0]):
        image = images[index]
        energies[index] = np.abs(cv2.Sobel(image, cv2.CV_32F, 1, 0)) + np.abs(cv2.Sobel(image, cv2.CV_32F, 0, 1))
            
    return energies

def get_laplacian_map(images, kernel_size, blur_size):
    laplacian = np.zeros(images.shape, dtype=np.float32)
    for index in range(images.shape[0]):
        gaussian = cv2.GaussianBlur(images[index], (blur_size, blur_size), 0)
        laplacian[index] = np.abs(cv2.Laplacian(gaussian, cv2.CV_32F, ksize = kernel_size))
        
    return laplacian

def smooth_energy_map(energies, smooth_size):
    smoothed = np.zeros(energies.shape, dtype=energies.dtype)
    if (smooth_size > 0):
        for index in range(energies.shape[0]):
            smoothed[index] = cv2.bilateralFilter(energies[index], smooth_size, 25, 25)
            
    return smoothed

def get_focus_map(energies, choice):
    if (choice == CHOICE_AVERAGE):
        tile_shape = np.array(energies.shape)
        tile_shape[1:] = 1

        sum_energies = np.tile(np.sum(energies, axis=0), tile_shape)
        return np.divide(energies, sum_energies, where=sum_energies!=0)
    
    focus_map = np.zeros(energies.shape, dtype=np.float32)
    best_layer = np.argmax(energies, axis=0)
    for index in range(energies.shape[0]):
        focus_map[index] = best_layer == index

    return focus_map

def blend(images, focus_map):
    return np.sum(images.astype(np.float32) * focus_map[:, :, :, np.newaxis], axis=0).astype(images.dtype)
