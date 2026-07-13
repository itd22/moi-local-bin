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


check_untracked()
{
    local repo="$1"

    if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
        echo "ERROR: untracked files in $repo"
        git ls-files --others --exclude-standard
        exit 1
    fi
}


remote_tag_exists()
{
    local tag="$1"

    git ls-remote --exit-code --tags origin \
        "refs/tags/$tag" >/dev/null 2>&1
}


local_tag_exists()
{
    local tag="$1"

    git rev-parse "refs/tags/$tag" >/dev/null 2>&1
}


verify_clean()
{
    local repo="$1"

    if [[ -n "$(git status --porcelain)" ]]; then
        echo "ERROR: repository not clean after operation: $repo"
        git status
        exit 1
    fi
}


push_commits()
{
    local repo="$1"

    local ahead

    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)

    if [[ "$ahead" -gt 0 ]]; then
        echo "$repo: pushing $ahead commit(s)"
        git push
    else
        echo "$repo: no commits to push"
    fi
}


apply_tag()
{
    local repo="$1"

    [[ -z "$TAG" ]] && return


    echo "$repo: checking tag $TAG"


    if remote_tag_exists "$TAG"; then
        echo "$repo: remote tag already exists"
        return
    fi


    if local_tag_exists "$TAG"; then
        echo "$repo: local tag exists, pushing it"
    else
        echo "$repo: creating annotated tag"

        git tag \
            -a "$TAG" \
            -m "$MESSAGE"
    fi


    git push origin "refs/tags/$TAG"


    if remote_tag_exists "$TAG"; then
        echo "$repo: tag verified on remote"
    else
        echo "ERROR: $repo tag push failed verification"
        exit 1
    fi
}


process_repo()
{
    local repo="$1"


    echo
    echo "========== $repo =========="


    check_untracked "$repo"


    if [[ -n "$(git status --porcelain)" ]]; then
        echo "$repo: committing changes"

        git add .

        git commit \
            -m "$MESSAGE"
    else
        echo "$repo: no changes"
    fi


    push_commits "$repo"


    verify_clean "$repo"


    apply_tag "$repo"
}



export MESSAGE TAG
export -f check_untracked
export -f remote_tag_exists
export -f local_tag_exists
export -f verify_clean
export -f push_commits
export -f apply_tag
export -f process_repo


cd "$SOURCE_DIR"


echo "========== SUBMODULES =========="

git submodule foreach --recursive '
    process_repo "$name"
'


echo
echo "========== PARENT =========="

process_repo "parent chezmoi repository"


echo
echo "commit/push/tag completed successfully"
