#!/bin/bash

# --- DEFAULT FALLBACK CONFIGURATION ---
DEFAULT_SUFFIX="-clean"
STAGE1_RAW="stage1_unpacked.qdf"
STAGE3_FIXED="stage3_rebuilt.qdf"

# --- HELP MENU ---
show_help() {
    echo "Usage: $0 [options] <path_to_pdf>"
    echo "Options:"
    echo "  -s, --suffix <string>     Suffix for output filename (Default: $DEFAULT_SUFFIX)"
    echo "  -h, --help                Show this help menu"
    exit 0
}

# --- PARSE COMMAND LINE ARGUMENTS ---
SUFFIX="$DEFAULT_SUFFIX"
INPUT_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
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

# Check that the file parameter was captured
if [[ -z "$INPUT_PATH" ]]; then
    echo "Error: Missing input file path parameter." >&2
    show_help
fi

# Dynamically construct the final output name
OUTPUT_PATH="${INPUT_PATH%.*}${SUFFIX}.pdf"

# --- DEPENDENCY CHECK ---
for cmd in qpdf sed fix-qdf; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required system tool '$cmd' is not installed." >&2
        exit 1
    fi
done

if [ ! -f "$INPUT_PATH" ]; then
    echo "Error: Input file '$INPUT_PATH' not found." >&2
    exit 1
fi

echo "=== Configuration Diagnostics ==="
echo "Target Book File        : $INPUT_PATH"
echo "Output Destination Mode : $OUTPUT_PATH"
echo "================================="

echo "Step 1: Unpacking PDF structural streams to disk..."
# Use explicit --qdf destination parameter instead of stdout streaming
if qpdf --qdf --object-streams=disable "$INPUT_PATH" "$STAGE1_RAW" 2>/dev/null; then
    
    echo "Step 2: Stripping background shadow/pattern paint tokens in-place..."
    # Modifies the stage 1 unpacked file directly on your drive via internal buffer tracking
    sed -i.bak -E '/\/XObject/d; /\/Im[0-9]+/d; /\/Pattern/d; /Do/d' "$STAGE1_RAW"

    echo "Step 3: Rebuilding structural byte cross-references to intermediate asset..."
    # fix-qdf natively accepts input and output file paths as trailing arguments without redirection
    if fix-qdf "$STAGE1_RAW" "$STAGE3_FIXED" 2>/dev/null; then
        
        echo "Step 4: Compiling final clean binary layout structure..."
        # Compile the isolated fixed stage straight to its absolute final endpoint destination 
        if qpdf "$STAGE3_FIXED" "$OUTPUT_PATH"; then
            echo "Success! Sanitize pass completed with discrete file isolation."
            echo "Cleaned textbook generated at: $OUTPUT_PATH"
            
            # Clean up all workspace assets
            rm -f "$STAGE1_RAW" "${STAGE1_RAW}.bak" "$STAGE3_FIXED"
            exit 0
        else
            echo "Error: Final structure binary generation failed." >&2
            rm -f "$STAGE1_RAW" "${STAGE1_RAW}.bak" "$STAGE3_FIXED"
            exit 1
        fi
    else
        echo "Error: fix-qdf structural rebuild pass failed." >&2
        rm -f "$STAGE1_RAW" "${STAGE1_RAW}.bak"
        exit 1
    fi
else
    echo "Error: Step 1 expansion failed." >&2
    exit 1
fi

