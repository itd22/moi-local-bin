# /mnt/shared/pdf-parser.py -a -f --regex --search="/(JS|#4a#53|#4aS|J#53)\b" eff-ps.pdf
# /mnt/shared/pdf-parser.py -a -f eff-ps.pdf | rg -i "^\s*/(JS|#4a#53|#4aS|J#53|JavaScript|#4a#61#76#61#53#63#72#69#70#74)\b"

# gs -dNOPAUSE -dBATCH -sDEVICE=ps2write -sOutputFile=output.ps input.pdf
#gs -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=final.pdf output.ps


pdf-expand-linearize() {
  local in="$1"
  local print_time="${2:-false}" # Default to false if not provided

  # Check if a file name was given
  if [[ -z "$in" ]]; then
    echo "Error: No file name provided." >&2
    echo "Usage: pdf-expand-linearized <input.pdf> [true|false]" >&2
    return 1
  fi

  # Check if the file actually exists and is a PDF
  if [[ ! -f "$in" || "$in" != *.pdf ]]; then
    echo "Error: File '$in' not found or is not a .pdf file." >&2
    return 1
  fi

  local linearized="${in%.pdf}-linearized.pdf"
  local qdf="${in%.pdf}-qdf.pdf"

  # Record start time using the internal SECONDS counter
  local start_time=$SECONDS

  qpdf --qdf --object-streams=disable --decode-level=generalized --stream-data=uncompress "$in" "$qdf"
  qpdf --linearize --object-streams=generate "$qdf" "$linearized"
  rm -f  "$qdf"
  # Calculate and print elapsed time if requested
  if [[ "$print_time" == "true" ]]; then
    local elapsed=$((SECONDS - start_time))
    echo "Process completed in ${elapsed} seconds."
  fi
}

export -f  pdf-expand-linearize  
pdf-ps-pdf() {
  local in="$1"
  local print_time="${2:-false}" # Default to false if not provided

  # Check if a file name was given
  if [[ -z "$in" ]]; then
    echo "Error: No file name provided." >&2
    echo "Usage: pdf-expand-linearized <input.pdf> [true|false]" >&2
    return 1
  fi

  # Check if the file actually exists and is a PDF
  if [[ ! -f "$in" || "$in" != *.pdf ]]; then
    echo "Error: File '$in' not found or is not a .pdf file." >&2
    return 1
  fi

  local psf="${in%.pdf}.ps"
  local outpdf="${in%.pdf}-ps.pdf"

  # Record start time using the internal SECONDS counter
  local start_time=$SECONDS

  mutool draw -F ps -o $psf $in
  ps2pdf $psf $outpdf 
  rm -f  "$psf"
  # Calculate and print elapsed time if requested
  if [[ "$print_time" == "true" ]]; then
    local elapsed=$((SECONDS - start_time))
    echo "Process completed in ${elapsed} seconds."
  fi
}
pdf-expand-sanitize() {
  local in="$1"
  local print_time="${2:-false}" # Default to false if not provided

  # Check if a file name was given
  if [[ -z "$in" ]]; then
    echo "Error: No file name provided." >&2
    echo "Usage: pdf-expand-linearized <input.pdf> [true|false]" >&2
    return 1
  fi

  # Check if the file actually exists and is a PDF
  if [[ ! -f "$in" || "$in" != *.pdf ]]; then
    echo "Error: File '$in' not found or is not a .pdf file." >&2
    return 1
  fi

  local sanitized="${in%.pdf}-sanitized.pdf"
  local qdf="${in%.pdf}-qdf.pdf"

  # Record start time using the internal SECONDS counter
  local start_time=$SECONDS
  qpdf --qdf --object-streams=disable --decode-level=generalized --stream-data=uncompress "$in" "$qdf"
  /bin/python3 /home/sd/tools/pdfpz/pdf_sanitize.py   "$qdf"
  rm -f  "$qdf"
  # Calculate and print elapsed time if requested
  if [[ "$print_time" == "true" ]]; then
    local elapsed=$((SECONDS - start_time))
    echo "Process completed in ${elapsed} seconds."
  fi
}

export -f  pdf-expand-sanitize


pdf-expand-sanitize-all() {
  local print_time="${2:-false}" # Default to false if not provided
  local start_time=$SECONDS

  parallel -j+0   pdf-expand-sanitize  ::: *.pdf || return

  # Calculate and print elapsed time if requested
  if [[ "$print_time" == "true" ]]; then
    local elapsed=$((SECONDS - start_time))
    echo "Process completed in ${elapsed} seconds."
  fi
}

pdf-expand-linearize-all() {
  local print_time="${2:-false}" # Default to false if not provided
  local start_time=$SECONDS

  parallel -j+0   pdf-expand-linearize  ::: *.pdf || return

  # Calculate and print elapsed time if requested
  if [[ "$print_time" == "true" ]]; then
    local elapsed=$((SECONDS - start_time))
    echo "Process completed in ${elapsed} seconds."
  fi
}

pdf-didier-scan-all() {
  local print_time="${2:-false}" # Default to false if not provided
  local start_time=$SECONDS

  parallel -j+0   /bin/python /home/sd/.local/bin/scan_report_didier.py  ::: *.pdf || return

  # Calculate and print elapsed time if requested
  if [[ "$print_time" == "true" ]]; then
    local elapsed=$((SECONDS - start_time))
    echo "Process completed in ${elapsed} seconds."
  fi
}

pdf-sanitize-all (){ 
    local print_time="${2:-false}"
    local start_time=$SECONDS
    local targets=()

    # Collect matching files that haven't been sanitized yet
    for file in *-linearized.pdf; do
        [[ -e "$file" ]] || continue
        local sanitized="${file%.pdf}-sanitized.pdf"
        if [[ ! -e "$sanitized" ]]; then
            targets+=("$file")
        fi
    done

    # Exit early if there are no new files to process
    if (( ${#targets[@]} == 0 )); then
        echo "No new files to sanitize." >&2
        return 0
    fi

    parallel -j+0 /bin/python "$HOME/tools/pdfpz/pdf_sanitize.py" {} ::: "${targets[@]}" || return

    if [[ "$print_time" == "true" ]]; then
        local elapsed=$((SECONDS - start_time))
        echo "Process completed in ${elapsed} seconds."
    fi
}


qpdfc() {
  [[ $# -lt 2 ]] && {
    echo "Usage: qpdfc <input.pdf> <pages...>"
    echo "Examples:"
    echo "  qpdfc book.pdf 1-15 20 30-45"
    echo "  qpdfc doc.pdf 2-3 7 10-12"
    echo "  qpdfc scan.pdf 42"
    return 1
  }

  local input="$1"
  shift
  local raw_ranges=("$@")

  # Normalize and collect all page numbers to find min/max
  local all_pages=()
  local normalized_ranges=()

  for r in "${raw_ranges[@]}"; do
    # Accept both "5" and "5-5"
    if [[ $r =~ ^([0-9]+)$ ]]; then
      normalized_ranges+=("${BASH_REMATCH[1]}-${BASH_REMATCH[1]}")
      all_pages+=("${BASH_REMATCH[1]}")
    elif [[ $r =~ ^([0-9]+)-([0-9]+)$ ]]; then
      normalized_ranges+=("$r")
      local start=${BASH_REMATCH[1]}
      local end=${BASH_REMATCH[2]}
      for ((i = start; i <= end; i++)); do all_pages+=("$i"); done
    else
      echo "Invalid range: $r" >&2
      return 1
    fi
  done

  # Sort and unique to find true first and last page
  read first last <<<$(
    printf '%s\n' "${all_pages[@]}" | sort -n | head -1 | tr '\n' ' '
    printf '%s\n' "${all_pages[@]}" | sort -n | tail -1
  )

  # Base name
  local base="${input%.pdf}"
  [[ "$base" == "$input" ]] && base="${input%.*}"

  # Short pretty output: only first-last
  local output="${base}-p$(printf "%03d" "$first")-p$(printf "%03d" "$last").pdf"

  # Build correct qpdf range string: comma-separated
  local pages_spec=$(
    IFS=,
    echo "${normalized_ranges[*]}"
  )

  # Full command
  local cmd="qpdf \"$input\" --pages . \"$pages_spec\" -- \"$output\""

  # Show info
  echo "Input         : $input"
  echo "Pages selected: ${raw_ranges[*]}"
  echo "First → Last  : $first → $last"
  echo "Output        : $output"
  echo -e "\nRunning:\n→ $cmd\n"

  # Execute
  eval "$cmd" && echo "Created: $output"
}
