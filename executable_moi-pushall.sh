#!/bin/bash
set -euo pipefail

MESSAGE=""
TAG=""

usage()
{
    echo 'Usage: moi-pushall.sh -m "commit message" [-t tag]'
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m)
            [[ $# -ge 2 ]] || usage
            MESSAGE="$2"
            shift 2
            ;;
        -t)
            [[ $# -ge 2 ]] || usage
            TAG="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[[ -n "$MESSAGE" ]] || usage


SOURCE_DIR="$(chezmoi source-path)"

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
    echo "ERROR: $SOURCE_DIR is not a git repository"
    exit 1
fi


TAG_MISSING=()


check_untracked()
{
    local repo="$1"

    if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
        echo
        echo "ERROR: untracked files found in $repo"
        git ls-files --others --exclude-standard
        exit 1
    fi
}


tag_exists()
{
    local tag="$1"

    if git rev-parse "refs/tags/$tag" >/dev/null 2>&1; then
        return 0
    fi

    if git ls-remote --exit-code --tags origin \
        "refs/tags/$tag" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}


create_push_tag()
{
    local repo="$1"

    [[ -z "$TAG" ]] && return 0

    if tag_exists "$TAG"; then
        echo "WARNING: tag '$TAG' already exists in $repo"
        TAG_MISSING+=("$repo")
        return 0
    fi

    echo "Creating tag '$TAG' in $repo"

    git tag "$TAG"

    echo "Pushing tag '$TAG'"
    git push origin "refs/tags/$TAG"
}


push_if_ahead()
{
    local repo="$1"
    local ahead

    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)

    if [[ "$ahead" -gt 0 ]]; then
        echo "Pushing $ahead commit(s) from $repo"
        git push
        return 0
    fi

    echo "No commits to push from $repo"
    return 1
}


process_repo()
{
    local repo="$1"

    echo
    echo "== $repo =="

    check_untracked "$repo"

    if [[ -n "$(git status --porcelain)" ]]; then
        echo "Committing changes in $repo"

        git add .

        git commit \
            -m "$MESSAGE"
    else
        echo "No changes to commit in $repo"
    fi

    if push_if_ahead "$repo"; then
        create_push_tag "$repo"
    else
        echo "No push performed, no new commits"
    fi
}


cd "$SOURCE_DIR"


echo "== Processing submodules =="

git submodule foreach --recursive '
    process_repo "$name"
'


echo
echo "== Processing chezmoi source repository =="

process_repo "parent chezmoi repository"


echo
echo "== Tag summary =="

if [[ ${#TAG_MISSING[@]} -gt 0 ]]; then
    echo "Tag '$TAG' was already present in:"
    printf " - %s\n" "${TAG_MISSING[@]}"
elif [[ -n "$TAG" ]]; then
    echo "Tag '$TAG' created and pushed successfully everywhere"
fi


echo
echo "Done"
