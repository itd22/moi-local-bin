#!/bin/sh
# Manual DNF package checker
# Run:
#   ~/.local/bin/check-dnf-packages

missing=""

{{- range .dnf_packages }}

PACKAGE="{{ . }}"

if ! rpm -q "$PACKAGE" >/dev/null 2>&1; then
    missing="$missing $PACKAGE"
fi

{{- end }}

if [ -n "$missing" ]; then
    echo "Missing packages:"
    echo "$missing"
    echo
    echo "Please run:"
    echo "sudo dnf install$missing"
else
    echo "Packages installed:"
    echo "{{ range .dnf_packages }}{{ . }} {{ end }}"
fi