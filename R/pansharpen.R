#' Melt spectral and spatial information with *Pansharpening*,
#' High-Pass Filter technique
#' 
#' @section Description:
#' 
#' Apply High-Pass Filter formula with `hpf.pansharpen()` function.
#' It's applied for each band and write them locally to save cache
#' storage. Then bands are merged into one mosaic. Lastly remove
#' individual pansharpened band.
#' 
#' @section Parameters:
#' 
#' - Path of panchromatic image
#' - Path of resized multiespectral image to panchromatic spatial res
#' It may contain several bands
#' - Output image path (dir + name)
#' - No data value (if exist, else write NA)
#' 
#' Packages ---------------------------
#' 
#' - raster https://rspatial.org/raster/pkg/index.html (docu)
#' 
#' Resizing MUL image can achieve using next command with GDAL:
#' 
#' gdalwarp -of GTiff -ot Float32 -r cubicspline -co COMPRESS=DEFLATE
#' -co PREDICTOR=3 -tr {pan_resX} {pan_resY}
#' -te {xmin ymin xmax ymax} -t_srs EPSG:32642 -overwrite
#' "D:\arqueologia_2022\gdal-pansharpening\test\mul.tif"
#' "D:\arqueologia_2022\gdal-pansharpening\test\mul_resizePython.tif" 
#' 
#' @section Pansharpening:
#' 
#' HPF Pansharpening is computed by hpf.pansharpening().
#' 
#' 1. Retrieve PAN spatial component
#' 2. Compute HPF function (Schowengerdt, 1998) with:
#' F = L + [H - mean(Hwj)]
#'   - F: New pixel in fused image
#'   - L: Pixel in low res resized
#'   - H: Pixel in panchromatic image
#'   - Hwj: Pixel inside PAN spatial component image
#' 3. Clamp pansharpened image to 0,1
#' https://www.rdocumentation.org/packages/raster/versions/3.5-15/topics/calc
#'

library('raster')
source("functions.R")

# Parameters ----------------------------------------------------

cwd = getwd()
pan_image <- path.cat(cwd, r"(../test/pan.tif)")
mul_image <- path.cat(cwd, r"(../test/mul_resize.tif)")
output    <- path.cat(cwd, r"(../test/pansharp_r.tif)")
nodata <- 0 # If it is unknown write NA

# Functions -----------------------------------------------------

# 1. Open raster file as layer
read.raster <- function(path, band) {
  r_layer <- raster(path, band = band)
  return(r_layer)
}

# 2. Pansharpening
hpf.pansharpen <- function(pan, mul, nband, filter = 'high'){
  # :pan:   Pansharpening image path 
  # :mul:   Multiespectral image path 
  # :nband: Multiespectral image band number to compute
  # :filter:
  # - 'high' Get PAN spatial component with High-pass filter
  # - 'low'  PAN spatial component with Amro et al. (2011) filter
  
  cat("..Open PAN image\n")
  band_pan <- read.raster(pan, 1)
  
  cat("..Extract spatial component\n")
  if (filter == 'low') {
    # Amro et al. (2011): PAN high spatial frequence is derived substracting
    # the PAN image with a low-pass filter from the original PAN image.
    
    # Low-pass filter
    weight.matrix <- matrix(rep(1, 9) / 9, nrow = 3, ncol = 3)
    pan_lowpass <-  focal(band_pan, weight.matrix, fun = sum, na.rm = T)
    
    # PAN spatial component
    pan_spatial <- pan_lowpass - band_pan
    
  } else if (filter == 'high') {
    
    # High-pass filter to PAN
    # Weight matrix as (Gangkofner et al., 2007)
    weight.matrix <- matrix(
      c(-1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1,
        -1, -1, 24, -1, -1,
        -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1) / 25,
      nrow = 5, ncol = 5
    )
    
    # PAN spatial component
    pan_spatial <- focal(band_pan, weight.matrix, fun = sum, na.rm = T)
  }
  
  # Start Pansharpening
  # Multiespectral bands are reading by band to store as a layer
  band_mul <- read.raster(mul, nband)
  
  cat("..Start HPF Pansharpening\n")
  hpf_result <- band_mul + (band_pan - pan_spatial)
  
  cat("..Clamp min/max as 0/1\n")
  fun <- function(x){ x[x <= 0 & x > 1] <- NA; return(x) }
  hpf_result_clamp <- calc(hpf_result, fun)
  
  return(hpf_result_clamp)

}

# 3. Export image
write.raster <- function(r_layer, out_path, nodata){
  if (is.na(nodata)) {
    
    raster::writeRaster(
      r_layer,
      out_path,
      bylayer = F,
      # Treat input raster as Float32 ones
      options=c("COMPRESS=DEFLATE", "PREDICTOR=3"),
      overwrite = T
    )
    
  } else {
    
    raster::writeRaster(
      r_layer,
      out_path,
      bylayer = F,
      # Treat input raster as Float32 ones
      options=c("COMPRESS=DEFLATE", "PREDICTOR=3"),
      overwrite = T,
      # No data value same as input layer
      NAflag = nodata
    )
    
  }
  
}

# 4. Group bands inside a raster mosaic
group.bands <- function(bands, output_path, nodata){
  
  # New raster stack with all bands
  cat("..Create rasterStack\n")
  mosaic <- raster::stack(bands)
  
  if (is.na(nodata)) {
    
    # Export as RasterBrick
    cat("..Export mosaic\n")
    raster::writeRaster(
      mosaic,
      output_path,
      # Treat input raster as Float32 ones
      bylayer = F, options=c("COMPRESS=DEFLATE", "PREDICTOR=3"),
      overwrite = T
    )
    
  } else {
    
    # Export as RasterBrick
    cat("..Export mosaic\n")
    raster::writeRaster(
      mosaic,
      output_path,
      # Treat input raster as Float32 ones
      bylayer = F, options=c("COMPRESS=DEFLATE", "PREDICTOR=3"),
      overwrite = T,
      NAflag=nodata
    )    
    
  }
  
  # Remove individual bands if mosaic exists
  if(file.exists(output_path)){
    unlink(bands)
    # R raster package creates tif.aux.xml file,
    # remove too
    unlink(paste0(out_bands,'.aux.xml'))
  }
  
}

# Start Pansharpening process -----------------------------------

# Check MUL raster number of bands
n_bands <- brick(mul_image)@file@nbands

# Save output names of computed bands to merge them before
out_bands <- c()

for(band in seq(1,n_bands)){
  
  cat(paste0("Pansharpening of band ", band,'\n'))
  cat("===================================================\n")
  pansharpened_band <- hpf.pansharpen(pan_image, mul_image, band)
  
  # Name of the new high resolution band
  # Split by extension to write suffix and extent separatelly
  name_split <- strsplit(basename(mul_image),'.',fixed = T)
  old_name <- name_split[[1]][1]
  extension <- name_split[[1]][2]
  
  new_name <- paste0(old_name,'_HPF_band_',band,'.',extension)
  new_path <- file.path(dirname(output),new_name)

  out_bands <- append(out_bands, new_path)
  
  # Write new band
  write.raster(pansharpened_band, new_path, nodata)
  rm(pansharpened_band) # Clear cache
  
}

group.bands(out_bands, output, nodata)

# Commented following http://adv-r.had.co.nz/Style.html
