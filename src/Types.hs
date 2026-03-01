{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Core data types for ASCII art assets and conversion configuration.
module Types
  ( AsciiArt(..)
  , AsciiVariant(..)
  , SourceInfo(..)
  , ConvertConfig(..)
  , defaultConfig
  , defaultCharRamp
  ) where

import           Data.Aeson
import qualified Data.Map.Strict as Map
import           GHC.Generics    (Generic)

-- | The default character ramp from darkest to brightest.
-- Works well on dark terminal backgrounds.
defaultCharRamp :: String
defaultCharRamp = "@%#*+=-:. "

-- | Configuration for the image-to-ASCII conversion.
data ConvertConfig = ConvertConfig
  { cfgMaxWidth  :: Int      -- ^ Maximum width in characters
  , cfgMaxHeight :: Int      -- ^ Maximum height in characters
  , cfgCharRamp  :: String   -- ^ Character ramp (darkest to brightest)
  } deriving (Show, Eq)

-- | Sensible defaults: 80×40 terminal, standard ramp.
defaultConfig :: ConvertConfig
defaultConfig = ConvertConfig
  { cfgMaxWidth  = 80
  , cfgMaxHeight = 40
  , cfgCharRamp  = defaultCharRamp
  }

-- | Metadata about the original image source.
data SourceInfo = SourceInfo
  { originalFile    :: FilePath
  , convertedWidth  :: Int
  , convertedHeight :: Int
  } deriving (Show, Eq, Generic)

instance ToJSON SourceInfo
instance FromJSON SourceInfo

-- | A single variant of ASCII art (e.g. "alive", "dead", "intact").
-- Contains one or more frames (list of lines each).
data AsciiVariant = AsciiVariant
  { frames       :: [[String]]   -- ^ List of frames; each frame is a list of lines
  , frameDelayMs :: Maybe Int    -- ^ Delay between frames in ms (Nothing = static)
  } deriving (Show, Eq, Generic)

instance ToJSON AsciiVariant
instance FromJSON AsciiVariant

-- | Top-level ASCII art asset with metadata and state-based variants.
data AsciiArt = AsciiArt
  { artId          :: String                     -- ^ Unique identifier
  , artName        :: String                     -- ^ Human-readable display name
  , artTags        :: [String]                   -- ^ Flexible tags for categorisation
  , artCategory    :: String                     -- ^ "npc", "item", "room", "scene"
  , artVariants    :: Map.Map String AsciiVariant -- ^ State name -> variant
  , defaultVariant :: String                     -- ^ Which variant to show by default
  , source         :: SourceInfo                 -- ^ Conversion metadata
  } deriving (Show, Eq, Generic)

-- Custom JSON instances so the output keys match our schema exactly.
instance ToJSON AsciiArt where
  toJSON art = object
    [ "id"             .= artId art
    , "name"           .= artName art
    , "tags"           .= artTags art
    , "category"       .= artCategory art
    , "variants"       .= artVariants art
    , "defaultVariant" .= defaultVariant art
    , "source"         .= source art
    ]

instance FromJSON AsciiArt where
  parseJSON = withObject "AsciiArt" $ \o -> AsciiArt
    <$> o .: "id"
    <*> o .: "name"
    <*> o .: "tags"
    <*> o .: "category"
    <*> o .: "variants"
    <*> o .: "defaultVariant"
    <*> o .: "source"
