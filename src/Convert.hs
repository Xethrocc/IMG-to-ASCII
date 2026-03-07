{-# LANGUAGE ScopedTypeVariables #-}

-- | Image loading, preprocessing, and ASCII conversion.
module Convert
  ( convertFile,
    imageToAscii,
    loadImage,
  )
where

import Codec.Picture
import Types (ConvertConfig (..))

-- | Load an image from disk. Supports PNG, JPG, BMP, GIF (first frame), TIFF.
loadImage :: FilePath -> IO (Either String DynamicImage)
loadImage = readImage

-- | Convert a DynamicImage to an 8-bit grayscale Image.
-- Uses JuicyPixels' built-in convertRGBA8 to handle all pixel formats
-- and safely deal with transparency (alpha = 0 becomes pure white).
toGrayscale :: DynamicImage -> Image Pixel8
toGrayscale dynImg =
  let rgba8 = convertRGBA8 dynImg
   in pixelMap luminanceRGBA8 rgba8
  where
    -- Standard luminance: 0.2126*R + 0.7152*G + 0.0722*B
    -- If alpha is fully transparent (0), force it to be bright white (255)
    -- so it maps to a blank space in our ASCII output.
    luminanceRGBA8 :: PixelRGBA8 -> Pixel8
    luminanceRGBA8 (PixelRGBA8 r g b a)
      | a == 0 = 255
      | otherwise = round (0.2126 * fromIntegral r + 0.7152 * fromIntegral g + 0.0722 * fromIntegral b :: Double)

-- | Resize an image to fit within maxW × maxH using nearest-neighbour sampling.
-- Accounts for terminal character aspect ratio (~2:1 — chars are taller than wide).
resizeToFit :: Int -> Int -> Image Pixel8 -> Image Pixel8
resizeToFit maxW maxH img
  | imgW <= 0 || imgH <= 0 = img
  | otherwise = generateImage samplePixel newW newH
  where
    imgW = imageWidth img
    imgH = imageHeight img

    -- Terminal chars are roughly 2× taller than wide, so we halve the
    -- effective height of the image to compensate.
    effH = fromIntegral imgH / 2.0 :: Double

    scaleW = fromIntegral maxW / fromIntegral imgW :: Double
    scaleH = fromIntegral maxH / effH
    scale = min scaleW scaleH

    newW = max 1 (round (fromIntegral imgW * scale))
    newH = max 1 (round (effH * scale))

    samplePixel x y =
      let srcX = min (imgW - 1) (round (fromIntegral x / scale))
          srcY = min (imgH - 1) (round (fromIntegral y * 2.0 / scale))
       in pixelAt img srcX srcY

-- | Convert a grayscale image to ASCII lines using the configured character ramp.
pixelsToAscii :: String -> Image Pixel8 -> [String]
pixelsToAscii ramp img =
  [ [mapPixel (pixelAt img x y) | x <- [0 .. imageWidth img - 1]]
    | y <- [0 .. imageHeight img - 1]
  ]
  where
    rampLen = length ramp
    -- Map a brightness value (0=black, 255=white) to a character.
    -- Index 0 of the ramp is the darkest character.
    mapPixel :: Pixel8 -> Char
    mapPixel p =
      let idx = fromIntegral p * (rampLen - 1) `div` 255
       in ramp !! min (rampLen - 1) idx

-- | Full conversion pipeline: DynamicImage → list of ASCII lines.
imageToAscii :: ConvertConfig -> DynamicImage -> [String]
imageToAscii cfg dynImg =
  let gray = toGrayscale dynImg
      resized = resizeToFit (cfgMaxWidth cfg) (cfgMaxHeight cfg) gray
   in pixelsToAscii (cfgCharRamp cfg) resized

-- | Convert a file from disk to ASCII lines.
convertFile :: ConvertConfig -> FilePath -> IO (Either String [String])
convertFile cfg path = do
  result <- loadImage path
  case result of
    Left err -> return (Left err)
    Right img -> return (Right (imageToAscii cfg img))
