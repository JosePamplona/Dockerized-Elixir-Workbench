#!/bin/bash
# Composes and stamps the back of a cartridge box.
#
# The back is composed, not generated (see the README beside this script):
# the generator makes only the plate, and every fact on the back — copy,
# screenshots, badge, legal line, seal — is typeset here. Positions are
# fractions of the plate's width, measured off the plate that came back
# and kept in <feature>/back/layout.env.
#
#   ./assets/covers/back.sh coveralls
#
# Reads  assets/covers/<feature>/art/back.jpg      (the generated plate)
#        assets/covers/<feature>/back/copy.md      (the copy, one ## per piece)
#        assets/covers/<feature>/back/shot-N.png   (real screenshots)
#        assets/covers/<feature>/back/layout.env   (measured positions)
# Writes assets/covers/<feature>/sealed/back.jpg   (the finished back)

set -euo pipefail

# CONFIGURATION ================================================================

  COVERS_DIR="$( cd "$( dirname "$0" )" && pwd )"

  # Layout defaults, as fractions of the plate's width. layout.env overrides.
  FRAMES="0.0604,0.1827,0.264,0.3736 0.3681,0.1827,0.265,0.3736 0.6772,0.1827,0.264,0.3736"
  CAPTION_Y=0.574
  HEAD_Y=0.628
  HEAD_SIZE=0.054
  PANEL="0.05,0.700,0.90,0.525"
  BLURB_Y=0.722
  FEAT_Y=0.955
  REQ_Y=1.128
  LEGAL_Y=1.285
  MARGIN=0.075
  SEAL_SIZE=0.12
  SEAL_MARGIN=0.03
  SEAL_CORNER=bl
  ACCENT="#B6F542"
  INK="#F2ECF7"
  MUTED="#CDBFDA"
  F_COND=Liberation-Sans-Narrow-Bold
  F_TEXT=Inter-Regular
  F_MONO=Liberation-Mono
  QUALITY=92

  C1="\x1B[38;5;1m"; B="\x1B[1m"; R="\x1B[0m"

# FUNCTIONS ====================================================================

  if [ "$(echo -e)" == "" ]; then echo() { command echo -e "$@"; } fi
  terminate() { echo "${B}${C1}Error${R} $@"; echo; exit 1; }

  usage() {
    echo "${B}Composes and stamps the back of a cartridge box.${R}"
    echo
    echo "  ./$(basename $0) FEATURE [OPTIONS]"
    echo
    echo "  FEATURE            Reads FEATURE/art/back.jpg and FEATURE/back/,"
    echo "                     writes FEATURE/sealed/back.jpg."
    echo "  -o, --output PATH  Write here instead."
    echo "  -h, --help         This."
    echo
    exit 0
  }

  px() { awk -v w="$W" -v f="$1" 'BEGIN{printf "%d", w*f+0.5}'; }

  # section <name>: the lines under "## <name>" in copy.md.
  section() {
    awk -v s="## $1" '$0==s {on=1; next} /^## / {on=0} on && NF {print}' "$COPY"
  }
  strip() { sed -e 's/`//g' -e 's/ · /  ·  /g'; }

# SCRIPT =======================================================================

[ $# -gt 0 ] || usage
FEATURE=""; OUTPUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)   usage ;;
    -o|--output) OUTPUT="$2"; shift 2 ;;
    -*)          terminate "Unknown option '$1'." ;;
    *)           FEATURE="$1"; shift ;;
  esac
done
[ -n "$FEATURE" ] || terminate "Missing the feature name. Try: --help"

PLATE="$COVERS_DIR/$FEATURE/art/back.jpg"
BACK="$COVERS_DIR/$FEATURE/back"
COPY="$BACK/copy.md"
OUTPUT="${OUTPUT:-$COVERS_DIR/$FEATURE/sealed/back.jpg}"

command -v magick > /dev/null || terminate "ImageMagick is required (the 'magick' command)."
[ -f "$PLATE" ] || terminate "No plate at $PLATE"
[ -f "$COPY" ]  || terminate "No copy at $COPY"
[ -f "$BACK/layout.env" ] && source "$BACK/layout.env"

W=$(magick identify -format "%w" "$PLATE")
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

HEADLINE=$(section Headline | strip)
BLURB=$(section Blurb | strip | tr '\n' ' ' | sed 's/  */ /g')
FEATURES=$(section Features | strip | sed 's/^- /•  /')
REQ=$(section Requirements | strip | sed 's/  ·  /\n/')
BADGE=$(section Badge | strip)
LEGAL=$(section Legal | strip | sed 's/ *$//')
mapfile -t CAPTIONS < <(section Screenshots | sed -E 's/^[0-9]+\. `[^`]*` — //' | strip)

X0=$(px $MARGIN); TEXT_W=$(px $(awk -v m="$MARGIN" 'BEGIN{print 1-2*m}'))
args=( "$PLATE" -background none )

# Screenshots into the plate's frames, with the period treatment.
n=0
for rect in $FRAMES; do
  n=$((n+1))
  IFS=, read -r fx fy fw fh <<< "$rect"
  x=$(px $fx); y=$(px $fy); w=$(px $fw); h=$(px $fh)
  [ -f "$BACK/shot-$n.png" ] || terminate "No screenshot at $BACK/shot-$n.png"
  magick -size "${w}x${h}" xc:none -fill "rgba(0,0,0,0.15)" \
    -draw "$(awk -v h="$h" -v w="$w" 'BEGIN{for(yy=0;yy<h;yy+=3) printf "rectangle 0,%d %d,%d ", yy, w, yy}')" \
    "$TMP/scan-$n.png"
  magick "$BACK/shot-$n.png" -resize "${w}x${h}^" -gravity north -extent "${w}x${h}" \
    -blur 0x0.3 -modulate 100,92,100 "$TMP/scan-$n.png" -composite "$TMP/shot-$n.png"
  args+=( "$TMP/shot-$n.png" -gravity northwest -geometry "+${x}+${y}" -composite )
  args+=( -font "$F_MONO" -pointsize "$(px 0.0155)" -fill "$MUTED"
          -size "${w}x" caption:"${CAPTIONS[$((n-1))]:-}" -geometry "+${x}+$(px $CAPTION_Y)" -composite )
done

# Headline.
args+=( -gravity northwest -font "$F_COND" -pointsize "$(px $HEAD_SIZE)" -fill "$ACCENT"
        -size "${TEXT_W}x" caption:"$HEADLINE" -geometry "+${X0}+$(px $HEAD_Y)" -composite )

# The copy panel: the even field the plate may not bring. An empty PANEL
# in layout.env skips it, for a plate that brought its own field.
if [ -n "$PANEL" ]; then
  IFS=, read -r pxf pyf pwf phf <<< "$PANEL"
  PX=$(px $pxf); PY=$(px $pyf); PW=$(px $pwf); PH=$(px $phf)
  magick -size "${PW}x${PH}" xc:none -fill "rgba(14,6,22,0.62)" -draw "roundrectangle 0,0 $((PW-1)),$((PH-1)) 6,6" \
    -stroke "rgba(220,210,230,0.35)" -strokewidth 1 -fill none -draw "roundrectangle 1,1 $((PW-2)),$((PH-2)) 6,6" \
    "$TMP/panel.png"
  args+=( "$TMP/panel.png" -geometry "+${PX}+${PY}" -composite )
fi
args+=( -font "$F_TEXT" -pointsize "$(px 0.0235)" -fill "$INK" -interline-spacing "$(px 0.006)"
        -size "${TEXT_W}x" caption:"$BLURB" -geometry "+${X0}+$(px $BLURB_Y)" -composite )
args+=( -font "$F_COND" -pointsize "$(px 0.030)" -fill "$INK" -interline-spacing "$(px 0.011)"
        -size "${TEXT_W}x" caption:"$FEATURES" -geometry "+${X0}+$(px $FEAT_Y)" -composite )

# Requirements flash (left) and badge (right), one row.
RW=$(px 0.56); RH=$(px 0.078)
magick -size "${RW}x${RH}" xc:none -fill "rgba(0,0,0,0.35)" -stroke "$ACCENT" -strokewidth 2 \
  -draw "rectangle 1,1 $((RW-2)),$((RH-2))" \
  -gravity center -stroke none -fill "$ACCENT" -font "$F_COND" -pointsize "$(px 0.023)" -interline-spacing "$(px 0.004)" \
  -annotate +0+0 "$REQ" "$TMP/req.png"
args+=( "$TMP/req.png" -gravity northwest -geometry "+${X0}+$(px $REQ_Y)" -composite )
BW=$(px 0.26)
magick -size "${BW}x${RH}" xc:"#1a1020" -stroke "$INK" -strokewidth 2 -fill none \
  -draw "rectangle 1,1 $((BW-2)),$((RH-2))" \
  -gravity center -stroke none -fill "$INK" -font "$F_COND" -pointsize "$(px 0.032)" \
  -annotate +0+0 "$BADGE" "$TMP/badge.png"
args+=( "$TMP/badge.png" -gravity northwest -geometry "+$(( X0 + TEXT_W - BW ))+$(px $REQ_Y)" -composite )

# Legal line in the strip, between the seal and the barcode.
args+=( -gravity northwest -font "$F_MONO" -pointsize "$(px 0.0145)" -fill "$MUTED"
        -size "$(px 0.52)x" caption:"$LEGAL" -geometry "+$(px 0.18)+$(px $LEGAL_Y)" -composite )

magick "${args[@]}" -quality "$QUALITY" "$TMP/composed.jpg"
"$COVERS_DIR/stamp.sh" "$FEATURE" --art "$TMP/composed.jpg" -o "$OUTPUT" \
  -c "$SEAL_CORNER" -s "$SEAL_SIZE" -m "$SEAL_MARGIN" > /dev/null
echo "Composed ${B}$(basename "$OUTPUT")${R}: ${n} frames, seal ${SEAL_SIZE} ${SEAL_CORNER}, ${W}px wide."
