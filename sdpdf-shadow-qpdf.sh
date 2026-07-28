# Deletes background raster images/shadows from hybrid PDFs using qpdf.
# Requires: qpdf, sed, and fix-qdf (usually bundled together with qpdf).
remove_pdf_shadows() {
    # 1. Ensure exactly two arguments are provided
    if [ "$#" -ne 2 ]; then
        echo "Error: Wrong number of arguments." >&2
        echo "Usage: remove_pdf_shadows <input.pdf> <output.pdf>" >&2
        return 1
    fi

    local input_file="$1"
    local output_file="$2"
    local temp_qdf="repaired_structure.qdf"

    # 2. Check dependencies before executing
    for cmd in qpdf sed fix-qdf; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: Required tool '$cmd' is not installed or not in PATH." >&2
            return 1
        fi
    done

    # 3. Verify input file existence
    if [ ! -f "$input_file" ]; then
        echo "Error: Input file '$input_file' not found." >&2
        return 1
    fi

    echo "Processing structure..."

    # 4. Execute the structural cleaning pipeline
    if qpdf --qdf --object-streams=disable "$input_file" - | \
       sed -E '/\/XObject/d; /\/Im[0-9]+/d; /Do/d' | \
       fix-qdf > "$temp_qdf" 2>/dev/null; then
        
        # 5. Compile the final clean PDF binary
        if qpdf "$temp_qdf" "$output_file"; then
            echo "Success! Clean PDF generated at: $output_file"
            rm -f "$temp_qdf"
            return 0
        else
            echo "Error: Final qpdf structural reconstruction failed." >&2
            rm -f "$temp_qdf"
            return 1
        fi
    else
        echo "Error: Stream decompression or text manipulation failed." >&2
        rm -f "$temp_qdf"
        return 1
    fi
}

