{-# LANGUAGE OverloadedStrings #-}

-- | CLI entry point for img-to-ascii.
module Main (main) where

import           Convert              (convertFile)
import           Export               (buildAsciiArt, exportToJson, exportBatch)
import           Types                (ConvertConfig(..), defaultCharRamp)

import           Options.Applicative
import           System.Directory     (listDirectory)
import           System.FilePath      ((</>), takeBaseName, takeExtension)
import           Data.Char            (toLower)

-- | Supported image extensions.
imageExtensions :: [String]
imageExtensions = [".png", ".jpg", ".jpeg", ".bmp", ".tiff", ".tif"]

isImageFile :: FilePath -> Bool
isImageFile fp = map toLower (takeExtension fp) `elem` imageExtensions

-- --------------------------------------------------------------------------
-- CLI Options
-- --------------------------------------------------------------------------

data Mode
  = SingleMode SingleOpts
  | BatchMode  BatchOpts
  deriving (Show)

data SingleOpts = SingleOpts
  { sInput    :: FilePath
  , sOutput   :: Maybe FilePath
  , sWidth    :: Int
  , sHeight   :: Int
  , sId       :: Maybe String
  , sName     :: Maybe String
  , sTags     :: Maybe String
  , sCategory :: String
  , sVariant  :: String
  , sRamp     :: String
  } deriving (Show)

data BatchOpts = BatchOpts
  { bInputDir  :: FilePath
  , bOutputDir :: FilePath
  , bWidth     :: Int
  , bHeight    :: Int
  , bCategory  :: String
  , bVariant   :: String
  , bRamp      :: String
  } deriving (Show)

-- --------------------------------------------------------------------------
-- Parsers
-- --------------------------------------------------------------------------

singleParser :: Parser SingleOpts
singleParser = SingleOpts
  <$> argument str
      (  metavar "INPUT"
      <> help "Path to the input image file" )
  <*> optional (strOption
      (  long "output"
      <> short 'o'
      <> metavar "FILE"
      <> help "Output JSON file (omit to print ASCII to stdout)" ))
  <*> option auto
      (  long "width"
      <> short 'w'
      <> metavar "COLS"
      <> value 80
      <> showDefault
      <> help "Max width in characters" )
  <*> option auto
      (  long "height"
      <> short 'h'
      <> metavar "ROWS"
      <> value 40
      <> showDefault
      <> help "Max height in characters" )
  <*> optional (strOption
      (  long "id"
      <> metavar "ID"
      <> help "Asset ID (default: filename without extension)" ))
  <*> optional (strOption
      (  long "name"
      <> metavar "NAME"
      <> help "Display name (default: filename)" ))
  <*> optional (strOption
      (  long "tags"
      <> metavar "TAGS"
      <> help "Comma-separated tags" ))
  <*> strOption
      (  long "category"
      <> short 'c'
      <> metavar "CAT"
      <> value "item"
      <> showDefault
      <> help "Category: npc, item, room, scene" )
  <*> strOption
      (  long "variant"
      <> metavar "VARIANT"
      <> value "default"
      <> showDefault
      <> help "Variant name for this conversion" )
  <*> strOption
      (  long "ramp"
      <> metavar "CHARS"
      <> value defaultCharRamp
      <> help "Character ramp (darkest to brightest)" )

batchParser :: Parser BatchOpts
batchParser = BatchOpts
  <$> argument str
      (  metavar "INPUTDIR"
      <> help "Directory containing input images" )
  <*> strOption
      (  long "output"
      <> short 'o'
      <> metavar "OUTDIR"
      <> help "Output directory for JSON files" )
  <*> option auto
      (  long "width"
      <> short 'w'
      <> metavar "COLS"
      <> value 80
      <> showDefault
      <> help "Max width in characters" )
  <*> option auto
      (  long "height"
      <> short 'h'
      <> metavar "ROWS"
      <> value 40
      <> showDefault
      <> help "Max height in characters" )
  <*> strOption
      (  long "category"
      <> short 'c'
      <> metavar "CAT"
      <> value "item"
      <> showDefault
      <> help "Category for all converted images" )
  <*> strOption
      (  long "variant"
      <> metavar "VARIANT"
      <> value "default"
      <> showDefault
      <> help "Variant name for all conversions" )
  <*> strOption
      (  long "ramp"
      <> metavar "CHARS"
      <> value defaultCharRamp
      <> help "Character ramp (darkest to brightest)" )

modeParser :: Parser Mode
modeParser = subparser
  (  command "convert"
       (info (SingleMode <$> singleParser)
             (progDesc "Convert a single image to ASCII"))
  <> command "batch"
       (info (BatchMode <$> batchParser)
             (progDesc "Batch convert all images in a directory"))
  )

opts :: ParserInfo Mode
opts = info (modeParser <**> helper)
  (  fullDesc
  <> progDesc "Convert images to ASCII art and export as JSON"
  <> header "img-to-ascii — image to ASCII art converter" )

-- --------------------------------------------------------------------------
-- Main
-- --------------------------------------------------------------------------

main :: IO ()
main = do
  mode <- execParser opts
  case mode of
    SingleMode so -> runSingle so
    BatchMode  bo -> runBatch bo

runSingle :: SingleOpts -> IO ()
runSingle so = do
  let cfg = ConvertConfig
        { cfgMaxWidth  = sWidth so
        , cfgMaxHeight = sHeight so
        , cfgCharRamp  = sRamp so
        }
      aid  = maybe (takeBaseName (sInput so)) id (sId so)
      name = maybe (takeBaseName (sInput so)) id (sName so)
      tags = maybe [] (splitOn ',') (sTags so)

  result <- convertFile cfg (sInput so)
  case result of
    Left err -> putStrLn $ "Error: " ++ err
    Right asciiLines ->
      case sOutput so of
        Nothing  -> mapM_ putStrLn asciiLines
        Just out -> do
          let art = buildAsciiArt aid name (sCategory so) tags
                                  (sVariant so) asciiLines (sInput so)
          exportToJson out art
          putStrLn $ "Exported to: " ++ out

runBatch :: BatchOpts -> IO ()
runBatch bo = do
  let cfg = ConvertConfig
        { cfgMaxWidth  = bWidth bo
        , cfgMaxHeight = bHeight bo
        , cfgCharRamp  = bRamp bo
        }

  allFiles <- listDirectory (bInputDir bo)
  let imgFiles = filter isImageFile allFiles

  if null imgFiles
    then putStrLn "No image files found in the input directory."
    else do
      arts <- mapM (convertOne cfg) imgFiles
      let successes = [a | Right a <- arts]
          failures  = [(f, e) | (f, Left e) <- zip imgFiles arts]

      exportBatch (bOutputDir bo) successes

      putStrLn $ "Converted " ++ show (length successes) ++ "/" ++ show (length imgFiles) ++ " images."
      mapM_ (\(f, e) -> putStrLn $ "  FAILED: " ++ f ++ " — " ++ e) failures
  where
    convertOne cfg file = do
      let fullPath = bInputDir bo </> file
          aid      = takeBaseName file
      result <- convertFile cfg fullPath
      case result of
        Left err -> return (Left err)
        Right asciiLines ->
          return $ Right $ buildAsciiArt aid aid (bCategory bo) []
                                         (bVariant bo) asciiLines fullPath

-- | Split a string on a delimiter character.
splitOn :: Char -> String -> [String]
splitOn _ [] = []
splitOn delim s =
  let (word, rest) = break (== delim) s
  in  word : case rest of
    []     -> []
    (_:rs) -> splitOn delim rs
