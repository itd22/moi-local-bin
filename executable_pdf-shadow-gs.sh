#!/bin/bash

# --- DEFAULT CONFIGURATIONS ---
DEFAULT_THRESHOLD="65"    # Default ImageMagick contrast threshold percentage
DEFAULT_SUFFIX="-clean"

show_help() {
    echo "Usage: $0 [options] <path_to_pdf>"
    echo "Options:"
    echo "  -t, --threshold <1-99>   Contrast threshold percentage (Default: $DEFAULT_THRESHOLD%)"
    echo "                           Lower (e.g. 55) preserves light drawings."
    echo "                           Higher (e.g. 75) aggressively burns dark paper shadow away."
    echo "  -s, --suffix <string>    Suffix for output filename (Default: $DEFAULT_SUFFIX)"
    echo "  -h, --help               Show this help menu"
    exit 0
}

# --- PARSE COMMAND LINE ARGUMENTS ---
THRESHOLD="$DEFAULT_THRESHOLD"
SUFFIX="$DEFAULT_SUFFIX"
INPUT_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--threshold)
            if [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -gt 0 ] && [ "$2" -lt 100 ]; then
                THRESHOLD="$2"
                shift 2
            else
                echo "Error: Threshold must be a percentage integer between 1 and 99." >&2
                exit 1
            fi
            ;;
        -s|--suffix)
            if [[ -n "$2" ]]; then
                SUFFIX="$2"
                shift 2
            else
                echo "Error: Suffix string cannot be empty." >&2
                exit 1
            fi
            ;;
        -h|--help)
            show_help
            ;;
        *)
            INPUT_PATH="$1"
            shift
            ;;
    esac
done

if [[ -z "$INPUT_PATH" ]]; then
    echo "Error: Missing input file path parameter." >&2
    show_help
fi

OUTPUT_PATH="${INPUT_PATH%.*}${SUFFIX}.pdf"

# --- DEPENDENCY CHECK ---
for cmd in gs magick qpdf rm; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required tool '$cmd' is not installed or not in PATH." >&2
        exit 1
    fi
done

if [ ! -f "$INPUT_PATH" ] || [ ! -r "$INPUT_PATH" ]; then
    echo "Error: Input file '$INPUT_PATH' not found or unreadable." >&2
    exit 1
fi

echo "=== Configured Diagnostics ==="
echo "Paper Bleach Threshold : ${THRESHOLD}%"
echo "Output Target File      : $OUTPUT_PATH"
echo "=============================="

# Temporary working assets
TEXT_LAYER="tmp_text_overlay.pdf"
BACKGROUND_LAYER="tmp_bleached_bg.pdf"

echo "Step 1: Extracting clean, selectable text layer..."
# Filter out the complex background, isolating native text/vectors
gs -dNOPAUSE -dBATCH -sDEVICE=pdfwrite \
   -dFILTERIMAGE=true \
   -sOutputFile="$TEXT_LAYER" \
   "$INPUT_PATH" &>/dev/null

echo "Step 2: Processing visual layer to burn off paper shadows..."
# Render background canvas at high density, force grayscale, and crush gray values
magick -density 300 "$INPUT_PATH" \
       -colorspace gray \
       -threshold "${THRESHOLD}%" \
       -type bilevel \
       "$BACKGROUND_LAYER"

echo "Step 3: Stitching searchable text back over clean drawings..."
# Merge the clean text layout perfectly over the bleached graphics layer
if qpdf "$BACKGROUND_LAYER" --overlay "$TEXT_LAYER" -- "$OUTPUT_PATH"; then
    echo "SUCCESS! Fully sanitized selectable PDF built at: $OUTPUT_PATH"
else
    echo "Error: Layer merging execution failed." >&2
    exit 1
fi

# Cleanup
rm -f "$TEXT_LAYER" "$BACKGROUND_LAYER"
exit 0

