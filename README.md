# gdal-pansharpening-hpf
Perform High-Pass Filter (HPF) pansharpening formula in a multispectral image.
It's developed for both, R and Python languages.

## Technique
The HPF is applied following the formula created by Schowengerdt, 1980. 

F<sub>i,j</sub> = L<sub>i,j</sub> +
[ H<sub>i,j</sub> - mean(H<sub>i,j(w,h)</sub>) ]

where:

* F<sub>i,j</sub>: Fused image pixel in coords (i,j)
* L<sub>i,j</sub>: Pixel value from low spatial resolution image (resized to high resolution image)
* H<sub>i,j</sub>: Pixel value in high resolution image
* mean(H<sub>i,j(w,h)</sub>): stands for the local mean of high resolution
channel inside the window of w (width) x h (height) pixels centered at (i, j) (Yuhendra et al., 2012).
In other words, this value corresponds with pixel in i,j coords inside the image with
the spatial component of the high resolution image, which is derived from a convolutional filter.

**Important:** HPF technique is based on surface information, i.e.,
correlation between all image bands and its edges. These will remain unchanging.
However, the edges in landscapes with low surface energy (e.g. a plain) and 
anthropogenic use are based on the color, which varies between the bands.
**The HPF should be applied carefully over these flat surfaces.**

### Low resolution image

The L<sub>i,j</sub> parameter is derived warping the low resolution image by 
high image resolution and extent. The [`gdalwarp`](https://gdal.org/programs/gdalwarp.html)
tool should be applied:

```
gdalwarp -of GTiff -ot Float32 -r cubicspline -co COMPRESS=DEFLATE -co PREDICTOR=3
-tr {resX} {resY} -te {xmin} {ymin} {xmax} {ymax} -t_srs EPSG:32642
"{input_img}" "{output_img}" -overwrite
```

where:

- `resX` y `resY` are high res image resolution.
- `<xmin ymin xmax ymax>` are the bounding box (BBOX) coordinates of high res image.
*Note: When low res image BBOX was lower than high res image, the new resized
image extends to the last one with new nodata pixels.*

### High resolution image

Parameter mean(H<sub>i,j(w,h)</sub>) is computed with a
[convolve kernel](https://en.wikipedia.org/wiki/Kernel_(image_processing)).
The result is a new image with the ridge component of high resolution image.
Kernel size and coefficients affects to ridge detection.
A 5 x 5 kernel is applied (Gangkofner et al., 2007).

```
(
  -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1,
  -1, -1, 24, -1, -1,
  -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1
) / 25
```

## R

The high resolution's spatial component is computed by
[focal function](https://www.rdocumentation.org/packages/raster/versions/3.5-15/topics/focal)
from `raster` package. The *nodata* values in original image
are transformed into `NA` format. When `focal` function is applied,
if the *kernel* contains `NA` data it will return a `NA` data.

Formula is applied for each multispectral band which is transformed
in `rasterLayer` objects. The new pansharpened bands are saved in the
output directory, and then are merged in a new file.
Finally individual bands are removed.

## Python

Required modules:

- Scipy
- GDAL (installed in conda with `forge`)

Raster images are saved in `numpy` arrays with GDAL functions. The *nodata*
values are converted in `NaN` data, so if convolve kernel contains one of
these the output value will be a `NaN` data.

Spatial component of high resolution image is derived by `ndimage.convolve`
function from `scipy` package. Selected parameters:

- `mode='constant'` : Edges (i.e. pixels where applied *kernel*
exceed image limits) are matched to `cval`.
- `cval=np.nan` : The edges are interpreted as `NaN`. **Important:**
`NaN` data can only be inserted in arrays with type *float*.

HPF formula is applied as follows:

1. Create empty raster with same shape as original multispectral image.
2. Perform HPF formula for each band.
3. Transform `NaN` values to original *nodata* value.
4. Write each pansharpened band inside empty raster (step 1) 

## Test data

Multispectral (mul.tif) and Panchromatic (pan.tif) files are extracted from a World View 3 image, with resolutions of 1.24m (mul) and 0.3m (pan).

The images have radiometric and atmospheric corrections (DOS method - Chavez, 1989).

Python code performs the multispectral image resizing automatically, but the R code doesn't. To apply resizing the
[gdalwarp tool](https://gdal.org/programs/gdalwarp.html) could be applied.

```
gdalwarp -of GTiff -ot Float32 -r cubicspline -co COMPRESS=DEFLATE
-co PREDICTOR=3 -tr {pan_resX} {pan_resY}
-te {xmin ymin xmax ymax} -t_srs EPSG:32642 -overwrite
"disc:\path\test\mul.tif"
"disc:\path\test\mul_resize.tif"
```

*Note: Both -tr and -te options are filled with pan resolution and bounding box.*

## Workflow for python code (Recommended)

Install [miniconda](https://docs.conda.io/en/latest/miniconda.html) and
create new environment:

```
conda create -n pansharpening
```

Then activating the environment with `conda activate pansharpening`, and install
following packages:

- GDAL
    ```
    conda install -c conda-forge gdal
    ```
- Dask
    ```
    conda install -c conda-forge dask
    ```
- Scipy
    ```
    conda install -c conda-forge scipy
    ```

Finally run code with `python path/to/pyfile.py`.

## Further development

The resulted product is not as good as other pansharpening technics, e.g.,
"weighted" Brovey method. Test HPF with another *kernel* sizes to retrieve
the spatial component of the Panchromatic image.

![Comparison of PAN original image, derived HPF product and "weighted" Brovey
method computed with gdal_pansharpen tool.](pansharp_comp.png)

## References

Amro, I., Mateos, J., Vega, M., Molina, R., & Katsaggelos, A. K. (2011). A survey of classical methods and new trends in pansharpening of multispectral images. EURASIP Journal on Advances in Signal Processing, 2011(1), 79. https://doi.org/10.1186/1687-6180-2011-79

Chavez, P.S., 1989. Radiometric calibration of Landsat Thematic Mapper multispectral images. Photogrammetric engineering and remote sensing 55, 1285–1294.

Gangkofner, U. G., Pradhan, P. S., & Holcomb, D. W. (2007). Optimizing the High-Pass Filter Addition Technique for Image Fusion. Photogrammetric Engineering & Remote Sensing, 73(9), 1107-1118. https://doi.org/10.14358/PERS.73.9.1107

Schowengerdt, R. A. (1980). Reconstruction of Multispatial, MuItispectraI Image Data Using Spatial Frequency Content. Photogrammetric Engineering and Remote Sensing, 46(10), 1325-1334.

Yuhendra, Alimuddin, I., Sumantyo, J. T. S., & Kuze, H. (2012). Assessment of pan-sharpening methods applied to image fusion of remotely sensed multi-band data. International Journal of Applied Earth Observation and Geoinformation, 18, 165-175. https://doi.org/10.1016/j.jag.2012.01.013

