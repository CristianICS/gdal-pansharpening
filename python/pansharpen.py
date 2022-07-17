"""____________________________________________________________________________
Script Name:        pansharpen.py
Description:        Merge spatial PAN image component with spectral MUL image
                    component. HPF pansharpening method.
Requirements:       GDAL version >= "3.1.4", Dask, scipy, numpy
Outputs:            Pansharpened image.
____________________________________________________________________________"""
# Parameters
# -----------------------------------------------------------------------------
mul_img = "../test/mul.tif"
pan_img = "../test/pan.tif"
out_img = "../test/pansharp_py.tif"

# Main script
# -----------------------------------------------------------------------------
# Import packages
import os
import functions

cwd = os.path.abspath(os.path.join(__file__,os.pardir))
mul_img = os.path.abspath(os.path.join(cwd,mul_img))
pan_img = os.path.abspath(os.path.join(cwd,pan_img))
out_img = os.path.abspath(os.path.join(cwd,out_img))

# GDAL command to resize multispectral image
gdal_warp = (
    'gdalwarp -of GTiff -ot Float32 -r cubicspline',
    '-co COMPRESS=DEFLATE -co PREDICTOR=3',
    '-tr {resX} {resY}',
    '-te {xmin} {ymin} {xmax} {ymax} -t_srs EPSG:32642',
    '"{input_img}" "{output_img}" -overwrite'
)

# Get bbox [minx, miny, maxx, maxy, resx, resy]
bbox = functions.get_bbox(pan_img)

# Resizing MUL image
mulname = os.path.basename(mul_img)
muldir = os.path.dirname(mul_img)
mul_img_resized = os.path.join(
    os.path.normpath(muldir),
    mulname.split('.')[0] + '_resizePython.tif'
)

# Apply gdalwarp
if (not os.path.exists(mul_img_resized)):
    gdal_warp_resolved = ' '.join(gdal_warp).format(
        xmin = bbox[0],
        xmax = bbox[2],
        ymin = bbox[1],
        ymax = bbox[3],
        resX = bbox[4],
        resY = bbox[5],
        input_img = mul_img,
        output_img = mul_img_resized
    )
    print(gdal_warp_resolved)
    os.system(gdal_warp_resolved)


# Pansharpening
# -----------------------------------------------------------------------------
functions.pansharpening(mul_img_resized, pan_img, out_img)
