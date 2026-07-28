# Removes large background paper shadow images from hybrid PDFs based on byte size inspection.
# Preserves selectable text and small diagram images/logos under the specified threshold.
remove_pdf_shadows_inspected() {
    if [ "$#" -ne 2 ]; then
        echo "Error: Wrong number of arguments." >&2
        echo "Usage: remove_pdf_shadows_inspected <input.pdf> <output.pdf>" >&2
        return 1
    fi

    local input_file="$1"
    local output_file="$2"
    local temp_qdf="repaired_structure.qdf"
    
    # Define "large image" threshold in bytes (e.g., 51200 bytes = 50KB)
    # Background paper textures are usually hundreds of KB or several MB.
    local size_threshold=51200 

    for cmd in qpdf sed fix-qdf; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: Required tool '$cmd' is not installed." >&2
            return 1
        fi
    done

    if [ ! -f "$input_file" ]; then
        echo "Error: Input file '$input_file' not found." >&2
        return 1
    fi

    echo "=== Step 1: Inspecting PDF Image Objects ==="
    
    # Extract object numbers, types, and uncompressed stream lengths from qpdf
    # Filter for image XObjects and extract their ID and length
    local large_objects=()
    
    while read -r obj_id length; do
        if [ "$length" -gt "$size_threshold" ]; then
            echo "Found LARGE background object candidate: ID $obj_id ($length bytes)"
            large_objects+=("$obj_id")
        else
            echo "Preserving small diagram/logo object: ID $obj_id ($length bytes)"
        fi
    done < <(qpdf --show-pages "$input_file" --with-images 2>/dev/null | \
             grep -E "images:" -A 20 | grep -E "obj [0-9]+" | \
             awk '{print $4, $6}' | sed 's/[^0-9 ]//g')

    # If no large background objects are found, default to scanning the raw stream objects
    if [ ${#large_objects[@]} -eq 0 ]; then
        echo "Direct image mapping empty. Scanning raw stream objects..."
        while read -r obj_id length; do
            if [ "$length" -gt "$size_threshold" ]; then
                echo "Found LARGE raw stream object candidate: ID $obj_id ($length bytes)"
                large_objects+=("$obj_id")
            fi
        done < <(qpdf --show-objects "$input_file" 2>/dev/null | \
                 grep -E "stream" | awk '{print $2, $4}' | sed 's/[^0-9 ]//g')
    fi

    if [ ${#large_objects[@]} -eq 0 ]; then
        echo "No image objects exceeded the ${size_threshold} byte threshold. Profiling complete."
        echo "Copying original file over without modifications..."
        cp "$input_file" "$output_file"
        return 0
    fi

    echo "=== Step 2: Building Targeted Deletion Filter ==="
    # Construct a dynamically generated sed regex matching only the large object references
    local sed_filter=""
    for id in "${large_objects[@]}"; do
        echo "Targeting Object ID $id for complete extraction removal."
        sed_filter+="/\/Im${id}[^0-9]/d; /\/R${id}[^0-9]/d; "
    done
    # Append global structural catch filters to ensure the Do drawing command drops
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

