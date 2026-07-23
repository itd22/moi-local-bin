#!/bin/bash

pdf-suspects-search() {
  local in="$1"
  if [[ -z "$in" ]]; then
    echo "Error: No file name provided." >&2
    echo "Usage: pdf-expand-linearized <input.pdf> [true|false]" >&2
    return 1
  fi

  if [[ ! -f "$in" || "$in" != *.pdf ]]; then
    echo "Error: File '$in' not found or is not a .pdf file." >&2
    return 1
  fi
  
  local expanded="/tmp/${1%.pdf}-qdf.pdf"
  local pdf_objects="/tmp/${1%.pdf}-objects.txt"
  
  qpdf --qdf --object-streams=disable --decrypt "$1" "${expanded}"
awk '/^[0-9]+ [0-9]+ obj/ { flag=1 } flag; /^[ \t]*stream[ \t]*$/ { flag=0; print "endobj\n" }' "${expanded}" > "${pdf_objects}"

  # wrong remove all content rg -U -P -v '(?ms)^[ \t]*stream[ \t]*\n.*?(?=^[ \t]*endobj)' "${expanded}" > "${pdf_objects}"


 rg -H -i '/(J(S\b|#53\b)|A(A\b|#41\b)|java_?script|open_?action|a(cro_?form|#63#72#6f#46#6f#72#6d)|launch|embeddedfile|encrypt)' "${pdf_objects}"

 local count
 count=$(rg --count-matches -i  '/(J(S\b|#53\b)|A(A\b|#41\b)|java_?script|open_?action|a(cro_?form|#63#72#6f#46#6f#72#6d)|launch|embeddedfile|encrypt)' "${pdf_objects}" || true)

 rm -f "${pdf_objects}"  "$expanded"
 return $((count % 254))
}

pdf-suspects-search "$1"
