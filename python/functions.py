"""____________________________________________________________________________
Script Name:        functions.py
Description:        Functions to handle raster images and perform pansharpening.
Prerequisites:      GDAL version "3.1.4" or greater
____________________________________________________________________________"""
import os
from osgeo import gdal
from multiprocessing.pool import ThreadPool
import numpy as np
import dask
from dask import array as da
from scipy import ndimage

# Save raster image as numpy array
def read_raster(path: str, nodata=None):
    """
    Parse raster as numpy array with raster dimensions.
    Important: The nodata value will be replaced as
    numpy.nan data.

    Important: The default datatype is float32

    Example: Raster with 5 bands, 30 rows and 25 columns
    generates an array with shape (5,30,30).

    :path: Dirpath with image to read.
    :nodata: No data value (float or int).

    return the array with the image and its properties.
    """
    # init dask as threads (shared memory is required)
    dask.config.set(pool=ThreadPool(1))

    raw_image = []
    src_ds = gdal.Open(str(path), gdal.GA_ReadOnly)
    n_bands = src_ds.RasterCount

    projection = src_ds.GetProjection()
    geoTrans = src_ds.GetGeoTransform()

    # Write each band in a numpy array
    for band in range(1,n_bands + 1):
        # Transform image band into numpy array
        ds = src_ds.GetRasterBand(band).ReadAsArray().astype(np.float32)
        # Fill nodata values with NaN
        ds[ds == nodata] = np.nan
        # Add band to a list
        raw_image.append(ds)

    # Merge each dimension (bands) in n dimension array (n = number of bands)
    raw_image_np = da.stack(raw_image).rechunk(('auto'))
    return (raw_image_np, projection, geoTrans)

def get_bbox(path: str) -> dict:
    """
    Return the bounding box of a raster plus its
    resolution.
    https://gis.stackexchange.com/a/201320

    :path: Raster path
    return [minx, miny, maxx, maxy, resx, resy]
    """
    src_ds = gdal.Open(str(path), gdal.GA_ReadOnly)
    geoTrans = src_ds.GetGeoTransform()
    # Get BBOX parameters
    resX = geoTrans[1]
    resY = geoTrans[5]
    # ulx, uly is the upper left corner
    # lrx, lry is the lower right corner
    ulx = geoTrans[0]
    uly = geoTrans[3]
    lrx = ulx + (src_ds.RasterXSize * resX)
    lry = uly + (src_ds.RasterYSize * resY)

    bbox = [ulx,lry,lrx, uly, resX,resY]
    return bbox

def high_pass_filter(array):
    """
    Obtain a numpy array with convolve image

    :array: 3D Numpy array with format (n_bands,rows,columns)
    """
    # Create high pass filter to extract spatial component of PAN img
    # 5x5 Weight matrix as (Gangkofner et al., 2007)
    highPassMatrix = np.array([
        [-1, -1, -1,-1, -1],
        [-1, -1, -1,-1, -1],
        [-1, -1, 24, -1, -1],
        [-1, -1, -1,-1, -1],
        [-1, -1, -1,-1, -1],
    ]) / 25

    # Kernel in 3D (repeat kernel for each image band)
    # The convolve function only works if kernel shape is equal
    # array shape.
    k = []

    for b in range(0,array.shape[0]):
        k.append(highPassMatrix)
    k = np.stack(k)

    # Apply convolve automatically with scipy
    convolve_image = ndimage.convolve(array,k,mode='constant',cval=np.nan)

    return convolve_image

def pansharpening(mul_resize: str, pan: str, outPath: str, nodata):
    """
    Compute pansharpening with High Pass Filter technique

    :mul_resize: MUL image resized path.
    :pan: Original PAN image path
    :outPath: File output path
    :nodata: Raster nodata value.
    """
    # init dask as threads (shared memory is required)
    dask.config.set(pool=ThreadPool(1))

    # PAN image
    pan_arr, projection, geoTrans = read_raster(pan, nodata)

    # PAN spatial component
    pan_spatial = high_pass_filter(pan_arr)

    # MUL resized image
    mul_arr = read_raster(mul_resize)[0]

    # Retrieve BBOX coordinates
    bbox_pan = get_bbox(pan)

    # Perform pansharpening
    n_bands = mul_arr.shape[0] # MUL's band number
    rows = mul_arr.shape[1]
    columns = mul_arr.shape[2]

    # Create empty raster
    creation_options = ['COMPRESS=DEFLATE','PREDICTOR=3']
    tmp_file = os.path.normpath(outPath)
    driver = gdal.GetDriverByName("GTiff")
    out_img = driver.Create(
        str(tmp_file),
        columns,
        rows,
        n_bands,
        gdal.GDT_Float32,
        options=creation_options
    )

    print(f"Start image {os.path.basename(mul_resize)} pansharpening:")

    # Pan image has 3D size, get the first band (and the only one)
    pan_arr2d = pan_arr[0,:,:]
    pan_spatial2d = pan_spatial[0,:,:]
    # Compute pansharpening on each MUL band
    for i in range(0, n_bands):
        band = mul_arr[i,:,:]

        print(f"..Band {i+1}, shape ", band.shape)

        # HPF pansharpening function
        pansharpen = band + (pan_arr2d - pan_spatial2d)
        # Replace NaN values with nodata
        pansharpen[np.isnan(pansharpen)] = nodata

        # Save band
        print("..Write band")
        pansharpen_band = out_img.GetRasterBand(i+1)
        if nodata is not None:
            pansharpen_band.SetNoDataValue(nodata)
        pansharpen_band.WriteArray(np.array(pansharpen))

    # set projection and geotransform
    if geoTrans is not None:
        out_img.SetGeoTransform(geoTrans)
    if projection is not None:
        out_img.SetProjection(projection)
    out_img.FlushCache()
