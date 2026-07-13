#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 || "$1" != "-m" || -z "$2" ]]; then
    echo "Usage: chezmoi pushall -m \"commit message\""
    exit 1
fi

MESSAGE="$2"

SOURCE_DIR="$(chezmoi source-path)"

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
    echo "Error: $SOURCE_DIR is not a git repository"
    exit 1
fi

cd "$SOURCE_DIR"

push_submodule=false

echo "== Checking submodules =="

git submodule foreach --recursive '
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "Changed submodule: $name"

        git add .

        git commit -m "'"$MESSAGE"'"
        git push

        exit 10
    fi
' || {
    rc=$?
    if [[ $rc -eq 10 ]]; then
        push_submodule=true
    else
        exit $rc
    fi
}

if [[ "$push_submodule" == false ]]; then
    echo "No submodule changes to push"
fi


echo "== Checking chezmoi source repository =="

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Changes detected in chezmoi source repository"

    git add .
    git commit -m "$MESSAGE"
    git push
else
    echo "No chezmoi source changes to push"
fi

echo "Done"
