#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 /absolute/path/to/icon-1024.png"
  exit 1
fi

SOURCE="$1"
if [ ! -f "$SOURCE" ]; then
  echo "Source file not found: $SOURCE"
  exit 1
fi

DEST_DIR="/Users/rahul/Coding/AnagramStack/AnagramStack/AnagramStackClient/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$DEST_DIR"

# Validate source dimensions are 1024x1024
DIMENSIONS=$(sips -g pixelWidth -g pixelHeight "$SOURCE" | awk '/pixelWidth|pixelHeight/ {print $2}' | tr '\n' ' ')
if [ "$DIMENSIONS" != "1024 1024 " ]; then
  echo "Source icon must be exactly 1024x1024 px. Found: $DIMENSIONS"
  exit 1
fi

# Normalize to a no-alpha PNG because App Store rejects transparent marketing icons.
OPAQUE_SOURCE="/tmp/anagramstack-icon-opaque.png"
sips -s format jpeg "$SOURCE" --out /tmp/anagramstack-icon-opaque.jpg >/dev/null
sips -s format png /tmp/anagramstack-icon-opaque.jpg --out "$OPAQUE_SOURCE" >/dev/null
rm -f /tmp/anagramstack-icon-opaque.jpg

# iPhone/iPad + App Store sizes
# format: filename size scale
SPECS=(
  "icon-20@2x.png 20 2"
  "icon-20@3x.png 20 3"
  "icon-29@2x.png 29 2"
  "icon-29@3x.png 29 3"
  "icon-40@2x.png 40 2"
  "icon-40@3x.png 40 3"
  "icon-60@2x.png 60 2"
  "icon-60@3x.png 60 3"
  "icon-20-ipad@1x.png 20 1"
  "icon-20-ipad@2x.png 20 2"
  "icon-29-ipad@1x.png 29 1"
  "icon-29-ipad@2x.png 29 2"
  "icon-40-ipad@1x.png 40 1"
  "icon-40-ipad@2x.png 40 2"
  "icon-76@1x.png 76 1"
  "icon-76@2x.png 76 2"
  "icon-83.5@2x.png 83.5 2"
  "icon-1024.png 1024 1"
)

for spec in "${SPECS[@]}"; do
  set -- $spec
  filename="$1"
  size="$2"
  scale="$3"

  if [ "$size" = "1024" ]; then
    cp "$OPAQUE_SOURCE" "$DEST_DIR/$filename"
    continue
  fi

  pixel_size=$(awk "BEGIN { printf \"%d\", $size * $scale }")
  sips -z "$pixel_size" "$pixel_size" "$OPAQUE_SOURCE" --out "$DEST_DIR/$filename" >/dev/null
  echo "Generated $filename (${pixel_size}x${pixel_size})"
done

cat > "$DEST_DIR/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon-20@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "20x20" },
    { "filename" : "icon-20@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "20x20" },
    { "filename" : "icon-29@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "29x29" },
    { "filename" : "icon-29@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "29x29" },
    { "filename" : "icon-40@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "40x40" },
    { "filename" : "icon-40@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "40x40" },
    { "filename" : "icon-60@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "60x60" },
    { "filename" : "icon-60@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "60x60" },

    { "filename" : "icon-20-ipad@1x.png", "idiom" : "ipad", "scale" : "1x", "size" : "20x20" },
    { "filename" : "icon-20-ipad@2x.png", "idiom" : "ipad", "scale" : "2x", "size" : "20x20" },
    { "filename" : "icon-29-ipad@1x.png", "idiom" : "ipad", "scale" : "1x", "size" : "29x29" },
    { "filename" : "icon-29-ipad@2x.png", "idiom" : "ipad", "scale" : "2x", "size" : "29x29" },
    { "filename" : "icon-40-ipad@1x.png", "idiom" : "ipad", "scale" : "1x", "size" : "40x40" },
    { "filename" : "icon-40-ipad@2x.png", "idiom" : "ipad", "scale" : "2x", "size" : "40x40" },
    { "filename" : "icon-76@1x.png", "idiom" : "ipad", "scale" : "1x", "size" : "76x76" },
    { "filename" : "icon-76@2x.png", "idiom" : "ipad", "scale" : "2x", "size" : "76x76" },
    { "filename" : "icon-83.5@2x.png", "idiom" : "ipad", "scale" : "2x", "size" : "83.5x83.5" },

    { "filename" : "icon-1024.png", "idiom" : "ios-marketing", "scale" : "1x", "size" : "1024x1024" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "✅ App icon set created at: $DEST_DIR"
