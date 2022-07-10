# gdal-pansharpening
Perform High-Pass Filter (HPF) pansharpening formula in a multispectral image.

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
In other words, the pixel value in i,j coords inside the image filled with
the spatial component of the high resolution image derived from a convolutional filter.

**Important:** HPF technique is based on surface information, i.e.,
correlation between all image bands and its edges. These will remain unchanging.
However, the edges in landscapes with low surface energy (e.g. a plain) and 
anthropogenic use are based on the color, which varies between the bands.
**The HPF should be applied carefully over these flat surfaces.**

### Low resolution image

The parameter L<sub>i,j</sub> is derived warping the low resolution image by 
high image resolution and extent. The `gdalwarp` tool should be applied:

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
