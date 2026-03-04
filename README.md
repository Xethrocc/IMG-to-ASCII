# img-to-ascii

A Haskell CLI tool that converts images into ASCII art and exports them as structured JSON files — designed for integration with text-based game engines. (Or rather 'my' text-based game engine)

## Features

- **Image → ASCII** — Converts PNG, JPG, BMP, TIFF images to ASCII art using brightness-to-character mapping
- **Terminal-aware resizing** — Automatically scales images to fit terminal dimensions with aspect-ratio correction
- **JSON export** — Structured output with ID, name, tags, category, and state-based variants
- **Batch conversion** — Convert an entire directory of images in one command
- **Configurable** — Custom dimensions, character ramps, categories, and variant names

## Installation

Requires [GHC](https://www.haskell.org/ghc/) and [Cabal](https://www.haskell.org/cabal/).

```bash
git clone https://github.com/Xethrocc/img-to-ascii.git
cd img-to-ascii
cabal build
```

## Usage

### Single Image → Terminal

```bash
cabal run img-to-ascii -- convert image.png
```

### Single Image → JSON

```bash
cabal run img-to-ascii -- convert wolf.jpg \
  -o wolf.json \
  --id wolf \
  --name "Wolf" \
  --category npc \
  --tags "enemy,animal" \
  --variant alive
```

### Batch Convert

```bash
cabal run img-to-ascii -- batch images/ -o output/ --category item
```

### Options

| Flag | Description | Default |
|---|---|---|
| `-o`, `--output` | Output file (single) or directory (batch) | stdout |
| `-w`, `--width` | Max width in characters | `80` |
| `-h`, `--height` | Max height in characters | `40` |
| `--id` | Asset ID | filename |
| `--name` | Display name | filename |
| `-c`, `--category` | Category: `npc`, `item`, `room`, `scene` | `item` |
| `--tags` | Comma-separated tags | none |
| `--variant` | Variant name | `default` |
| `--ramp` | Character ramp (darkest → brightest) | `@%#*+=-:.` |

## JSON Schema

Each exported file contains a self-contained ASCII art asset:

```json
{
  "id": "goblin_warrior",
  "name": "Goblin Warrior",
  "category": "npc",
  "tags": ["npc", "enemy", "goblin"],
  "defaultVariant": "alive",
  "variants": {
    "alive": {
      "frames": [["line1", "line2", "..."]],
      "frameDelayMs": null
    },
    "dead": {
      "frames": [["line1", "line2", "..."]],
      "frameDelayMs": null
    }
  },
  "source": {
    "originalFile": "goblin.png",
    "convertedWidth": 80,
    "convertedHeight": 40
  }
}
```

**Key design points:**

- **`variants`** — Map of state names to art. Use `"alive"` / `"dead"`, `"intact"` / `"destroyed"`, or any custom states
- **`frames`** — Each variant supports multiple frames for animation (GIF-to-ASCII)
- **`frameDelayMs`** — Milliseconds between frames (`null` for static art)
- **`id`** — Matches entity IDs in the game engine for automatic art lookup

## Architecture

```
src/
├── Main.hs      -- CLI with optparse-applicative (convert & batch subcommands)
├── Types.hs     -- AsciiArt, AsciiVariant, SourceInfo, ConvertConfig
├── Convert.hs   -- JuicyPixels pipeline: load → grayscale → resize → char-map
└── Export.hs     -- JSON construction and pretty-printed file export
```

### Conversion Pipeline

1. **Load** — `readImage` via JuicyPixels (supports PNG, JPG, BMP, GIF, TIFF)
2. **Grayscale** — `convertRGB8` + luminance formula (`0.2126R + 0.7152G + 0.0722B`)
3. **Resize** — Nearest-neighbour downscale to fit `maxW × maxH`, with 2:1 vertical compression for terminal character aspect ratio
4. **Map** — Each pixel brightness → character from configurable ramp

## Dependencies

| Package | Purpose |
|---|---|
| `JuicyPixels` | Image decoding (PNG, JPG, BMP, GIF, TIFF) |
| `aeson` + `aeson-pretty` | JSON serialisation |
| `optparse-applicative` | CLI argument parsing |

## Roadmap

- [ ] GIF → animated ASCII (multi-frame conversion)
- [ ] Multiple variants in one command (e.g. `--variant alive --variant dead`)
- [ ] `--invert` flag for light terminal backgrounds
- [ ] Game engine integration (auto-load JSON art files)

## License

MIT — see [LICENSE](LICENSE).
