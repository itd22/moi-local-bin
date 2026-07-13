#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 || "$1" != "-m" || -z "$2" ]]; then
    echo 'Usage: chezmoi-pushall -m "commit message"'
    exit 1
fi

MESSAGE="$2"

SOURCE_DIR="$(chezmoi source-path)"

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
    echo "Error: $SOURCE_DIR is not a git repository"
    exit 1
fi

cd "$SOURCE_DIR"


check_untracked()
{
    if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
        echo "ERROR: untracked files found in $(pwd)"
        git ls-files --others --exclude-standard
        exit 1
    fi
}


push_if_ahead()
{
    local ahead

    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)

    if [[ "$ahead" -gt 0 ]]; then
        echo "Pushing $ahead commit(s) from $(pwd)"
        git push
    else
        echo "No commits to push from $(pwd)"
    fi
}


echo "== Checking submodules =="

git submodule foreach --recursive '
    echo "--- $name ---"

    if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
        echo "ERROR: untracked files in submodule: $name"
        git ls-files --others --exclude-standard
        exit 1
    fi

    if [[ -n "$(git status --porcelain)" ]]; then
        echo "Committing changes in submodule: $name"
        git add .
        git commit -m "'"$MESSAGE"'"
    fi

    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)

    if [[ "$ahead" -gt 0 ]]; then
        echo "Pushing submodule: $name ($ahead commit(s))"
        git push
    else
        echo "Submodule up to date: $name"
    fi
'


echo "== Checking parent chezmoi repository =="

check_untracked

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Committing changes in chezmoi source repository"
    git add .
    git commit -m "$MESSAGE"
fi

push_if_ahead


echo "Done"
