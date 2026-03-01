{-# LANGUAGE OverloadedStrings #-}

-- | JSON export logic for ASCII art assets.
module Export
  ( buildAsciiArt
  , exportToJson
  , exportBatch
  ) where

import           Data.Aeson.Encode.Pretty (encodePretty)
import qualified Data.ByteString.Lazy     as BL
import qualified Data.Map.Strict          as Map
import           System.Directory         (createDirectoryIfMissing)
import           System.FilePath          ((</>), takeBaseName, replaceExtension)
import           Types

-- | Build an AsciiArt value from conversion results.
-- Creates a single variant with the given name (defaulting to "default").
buildAsciiArt
  :: String      -- ^ ID
  -> String      -- ^ Display name
  -> String      -- ^ Category ("npc", "item", "room", "scene")
  -> [String]    -- ^ Tags
  -> String      -- ^ Variant name
  -> [String]    -- ^ ASCII lines (single frame)
  -> FilePath    -- ^ Original source file path
  -> AsciiArt
buildAsciiArt aid aname acat atags variantName asciiLines srcPath =
  AsciiArt
    { artId          = aid
    , artName        = aname
    , artTags        = atags
    , artCategory    = acat
    , artVariants    = Map.singleton variantName AsciiVariant
        { frames       = [asciiLines]
        , frameDelayMs = Nothing
        }
    , defaultVariant = variantName
    , source         = SourceInfo
        { originalFile    = srcPath
        , convertedWidth  = case asciiLines of
            []    -> 0
            (l:_) -> length l
        , convertedHeight = length asciiLines
        }
    }

-- | Export a single AsciiArt to a pretty-printed JSON file.
exportToJson :: FilePath -> AsciiArt -> IO ()
exportToJson outPath art = BL.writeFile outPath (encodePretty art)

-- | Batch export: write one JSON file per AsciiArt into the output directory.
-- Files are named <artId>.json.
exportBatch :: FilePath -> [AsciiArt] -> IO ()
exportBatch outDir arts = do
  createDirectoryIfMissing True outDir
  mapM_ writeOne arts
  where
    writeOne art = do
      let outPath = outDir </> artId art ++ ".json"
      exportToJson outPath art
