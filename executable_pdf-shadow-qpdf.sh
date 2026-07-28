#!/bin/bash

# --- DEFAULT FALLBACK CONFIGURATION ---
DEFAULT_THRESHOLD=5000     # Dropped default to ~5KB to catch smaller embedded textures
DEFAULT_SUFFIX="-clean"
TEMP_QDF="repaired_structure_tmp.qdf"

# --- HELP MENU ---
show_help() {
    echo "Usage: $0 [options] <path_to_pdf>"
    echo "Options:"
    echo "  -t, --threshold <bytes>   Min byte size of shadow to remove (Default: $DEFAULT_THRESHOLD)"
    echo "  -s, --suffix <string>     Suffix for output filename (Default: $DEFAULT_SUFFIX)"
    echo "  -h, --help                Show this help menu"
    exit 0
}

# --- INITIALIZE VARIABLE CONFIGURATIONS ---
SIZE_THRESHOLD="$DEFAULT_THRESHOLD"
SUFFIX="$DEFAULT_SUFFIX"
INPUT_PATH=""

# --- PARSE COMMAND LINE ARGUMENTS ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--threshold)
            if [[ "$2" =~ ^[0-9]+$ ]]; then
                SIZE_THRESHOLD="$2"
                shift 2
            else
                echo "Error: Threshold must be a positive integer." >&2
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
        -*)
            echo "Error: Unknown option $1" >&2
            echo "Use -h or --help for instructions." >&2
            exit 1
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

# Dynamically construct the configurable output target name
OUTPUT_PATH="${INPUT_PATH%.*}${SUFFIX}.pdf"

# --- THE FUNCTION ---
remove_pdf_shadows_inspected() {
    if [ "$#" -ne 2 ]; then
        echo "Error: Wrong number of arguments." >&2
        return 1
    fi

    local input_file="$1"
    local output_file="$2"
    local temp_qdf="$TEMP_QDF"
    local size_threshold="$SIZE_THRESHOLD"

    for cmd in qpdf sed fix-qdf awk grep cp rm; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: Required system tool '$cmd' is not installed." >&2
            return 1
        fi
    done

    if [ ! -f "$input_file" ]; then
        echo "Error: Input file '$input_file' not found." >&2
        return 1
    fi

    echo "=== Configuration Diagnostics ==="
    echo "Target Threshold Weight : $size_threshold bytes"
    echo "Output Destination Mode  : $output_file"
    echo "================================="
    echo "=== Step 1: Inspecting PDF Image Objects ==="
    
    local large_objects=()
    
    # Improved multi-version robust parser regex to fetch sizes safely
    while read -r obj_id length; do
        if [[ -n "$obj_id" && "$length" =~ ^[0-9]+$ ]]; then
            if [ "$length" -gt "$size_threshold" ]; then
                echo "Found LARGE background object candidate: ID $obj_id ($length bytes)"
                large_objects+=("$obj_id")
            else
                echo "Preserving small diagram/logo object: ID $obj_id ($length bytes)"
            fi
        fi
    done < <(qpdf --show-pages "$input_file" --with-images 2>/dev/null | \
             grep -E "images:" -A 30 | grep -E "obj [0-9]+" | \
             awk '{for(i=1;i<=NF;i++) if($i=="obj") {print $(i+1), $(i+3)}}' | tr -d '(),[]a-zA-Z')

    # Fallback Option: Scan raw streams cleanly with robust spacing detection
    if [ ${#large_objects[@]} -eq 0 ]; then
        echo "Direct image mapping empty. Scanning raw stream objects..."
        while read -r obj_id length; do
            if [[ -n "$obj_id" && "$length" =~ ^[0-9]+$ ]]; then
                if [ "$length" -gt "$size_threshold" ]; then
                    echo "Found LARGE raw stream object candidate: ID $obj_id ($length bytes)"
                    large_objects+=("$obj_id")
                fi
            fi
        done < <(qpdf --show-objects "$input_file" 2>/dev/null | \
                 grep -E "stream" | awk '{print $2, $4}' | tr -d '(),[]a-zA-Z:')
    fi

    if [ ${#large_objects[@]} -eq 0 ]; then
        echo "No image objects exceeded the ${size_threshold} byte threshold. Profiling complete."
        echo "Copying original file over without modifications..."
        cp "$input_file" "$output_file"
        return 0
    fi

    echo "=== Step 2: Building Targeted Deletion Filter ==="
    local sed_filter=""
    for id in "${large_objects[@]}"; do
        echo "Targeting Object ID $id for complete extraction removal."
        sed_filter+="/\/Im${id}[^0-9]/d; /\/R${id}[^0-9]/d; "
    done
    sed_filter+="/\/XObject/d; /Do/d"

    echo "=== Step 3: Executing Structural Purification ==="
    if qpdf --qdf --object-streams=disable "$input_file" - | \
       sed -E "$sed_filter" | \
       fix-qdf > "$temp_qdf" 2>/dev/null; then
        
        if qpdf "$temp_qdf" "$output_file"; then
            echo "Success! Clean PDF generated at: $output_file"
            rm -f "$temp_qdf"
            return 0
        else
            echo "Error: Structural recovery assembly pass failed." >&2
            rm -f "$temp_qdf"
            return 1
        fi
    else
        echo "Error: Stream processing script extraction failure." >&2
        rm -f "$temp_qdf"
        return 1
    fi
}

# --- MAIN EXECUTION BLOCK ---
remove_pdf_shadows_inspected "$INPUT_PATH" "$OUTPUT_PATH"
exit $?

