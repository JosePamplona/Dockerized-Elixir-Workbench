#!/bin/bash
# Stamps the workbench seal onto a cartridge cover.
#
# The seal is the one element the image generator must never draw (see
# the README beside this script), so it is composited here
# instead — which is also the only way its size stays identical across
# the shelf. Covers come out at different pixel widths, so the seal is
# scaled as a fraction of each cover's width rather than to a fixed size.
#
#   ./assets/covers/stamp.sh clustering --corner br
#
# Reads  assets/covers/art/<feature>.jpg      (the generated artwork)
# Writes assets/covers/sealed/<feature>.jpg   (the stamped cover)

set -euo pipefail

# CONFIGURATION ================================================================

  COVERS_DIR="$( cd "$( dirname "$0" )" && pwd )"
  ART_DIR="$COVERS_DIR/art"
  SEALED_DIR="$COVERS_DIR/sealed"
  SEAL="$COVERS_DIR/seal.png"

  # Both are fractions of the cover's width, so every seal lands at the
  # same relative size and inset whatever the cover's resolution.
  SIZE=0.24
  MARGIN=0.04
  CORNER="br"
  QUALITY=92

  # Text formatting codes
  C1="\x1B[38;5;1m" # Dark-red
  B="\x1B[1m"       # Bold
  R="\x1B[0m"       # Reset

# FUNCTIONS ====================================================================

  if [ "$(echo -e)" == "" ]; then echo() { command echo -e "$@"; } fi

  terminate() { echo "${B}${C1}Error${R} $@"; echo; exit 1; }

  usage() {
    echo "${B}Stamps the workbench seal onto a cartridge cover.${R}"
    echo
    echo "  ./$(basename $0) FEATURE [OPTIONS]"
    echo
    echo "  FEATURE            Cover to stamp: reads art/FEATURE.jpg,"
    echo "                     writes sealed/FEATURE.jpg."
    echo "  -c, --corner C     br | bl | tr | tl (default: $CORNER). Pick the"
    echo "                     quiet corner of the artwork, per cover."
    echo "  -s, --size F       Seal width as a fraction of the cover's"
    echo "                     width (default: $SIZE)."
    echo "  -m, --margin F     Inset from both edges, same units"
    echo "                     (default: $MARGIN)."
    echo "      --art PATH     Read this artwork instead of art/FEATURE.jpg."
    echo "  -o, --output PATH  Write here instead of sealed/FEATURE.jpg."
    echo "  -h, --help         This."
    echo
    exit 0
  }

  # gravity <CORNER>
    # ImageMagick's name for each corner.
  gravity() {
    case "$1" in
      br) echo SouthEast ;;
      bl) echo SouthWest ;;
      tr) echo NorthEast ;;
      tl) echo NorthWest ;;
      *)  terminate "Unknown corner '$1'. Use br, bl, tr or tl." ;;
    esac
  }

# SCRIPT =======================================================================

[ $# -gt 0 ] || usage

FEATURE=""
ART=""
OUTPUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)   usage ;;
    -c|--corner) CORNER="$2"; shift 2 ;;
    -s|--size)   SIZE="$2";   shift 2 ;;
    -m|--margin) MARGIN="$2"; shift 2 ;;
    --art)       ART="$2";    shift 2 ;;
    -o|--output) OUTPUT="$2"; shift 2 ;;
    -*)          terminate "Unknown option '$1'." ;;
    *)           FEATURE="$1"; shift ;;
  esac
done

[ -n "$FEATURE" ] || terminate "Missing the feature name. Try: --help"

ART="${ART:-$ART_DIR/$FEATURE.jpg}"
OUTPUT="${OUTPUT:-$SEALED_DIR/$FEATURE.jpg}"

command -v magick > /dev/null || \
  terminate "ImageMagick is required (the 'magick' command)."
[ -f "$SEAL" ] || terminate "The seal is missing: $SEAL"
[ -f "$ART" ]  || terminate "No artwork at $ART"

mkdir -p "$(dirname "$OUTPUT")"

GRAVITY=$(gravity "$CORNER")
COVER_WIDTH=$(magick identify -format "%w" "$ART")

# Integer pixels from the fractions, rounded.
SEAL_WIDTH=$(  awk -v w="$COVER_WIDTH" -v f="$SIZE"   'BEGIN{printf "%d", w*f+0.5}')
INSET=$(       awk -v w="$COVER_WIDTH" -v f="$MARGIN" 'BEGIN{printf "%d", w*f+0.5}')

magick "$ART" \
  \( "$SEAL" -resize "${SEAL_WIDTH}x" \) \
  -gravity "$GRAVITY" -geometry "+${INSET}+${INSET}" \
  -composite -quality "$QUALITY" "$OUTPUT"

echo "Stamped ${B}$(basename "$OUTPUT")${R}:" \
  "seal ${SEAL_WIDTH}px wide (${SIZE} of ${COVER_WIDTH}px)," \
  "inset ${INSET}px, corner ${CORNER}."
