#!/bin/bash

# --- DEFAULT FALLBACK CONFIGURATION ---
DEFAULT_SUFFIX="-clean"
TEMP_QDF="repaired_structure_tmp.qdf"

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

# Dynamically construct the output target name
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

echo "Step 1: Unpacking PDF structural object streams..."
# We uncompress the object streams so text rendering rules are fully visible to sed
if qpdf --qdf --object-streams=disable "$INPUT_PATH" - > "$TEMP_QDF" 2>/dev/null; then
    
    echo "Step 2: Stripping background shadow/pattern paint tokens..."
    # Explicitly target internal structural dictionaries that paint background tints and gradients:
    # - Drops references to external graphic object forms (/XObject, /Im0-9)
    # - Purges inline background drawing operators (Do)
    # - Blocks canvas pattern dictionary bindings (/Pattern)
    sed -i.bak -E '/\/XObject/d; /\/Im[0-9]+/d; /\/Pattern/d; /Do/d' "$TEMP_QDF"

    echo "Step 3: Rebuilding structural byte cross-references..."
    # Re-align the edited text code stream back into a healthy binary PDF format
    if fix-qdf < "$TEMP_QDF" 2>/dev/null | qpdf - "$OUTPUT_PATH"; then
        echo "Success! Sanitize pass finished without pixel allocations."
        echo "Cleaned textbook generated at: $OUTPUT_PATH"
        rm -f "$TEMP_QDF" "${TEMP_QDF}.bak"
        exit 0
    else
        echo "Error: Final structure compression or cross-reference validation failed." >&2
        rm -f "$TEMP_QDF" "${TEMP_QDF}.bak"
        exit 1
    fi
else
    echo "Error: Initial object stream parsing failed." >&2
    rm -f "$TEMP_QDF"
    exit 1
fi

