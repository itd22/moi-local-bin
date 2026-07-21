#!/usr/bin/env bash

# 1. Ensure this is a valid Git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Error: Not a git repository. Execution stopped."
    exit 1
fi

# 2. Retrieve the latest tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null)

# 3. Ensure at least one tag exists
if [ -z "$LATEST_TAG" ]; then
    echo "❌ Error: No Git tags found. Execution stopped."
    exit 1
fi

# 4. Determine parent directory context and target file name
PARENT_DIR_NAME=$(basename "$PWD")
TARBALL_NAME="../${PARENT_DIR_NAME}.${LATEST_TAG}.tar.gz"

echo "📦 Preparing to archive files listed in Git..."
echo "📂 Target destination: $TARBALL_NAME"

# 5. Generate a flat tarball for direct overwriting
git ls-files -z | tar -caf "$TARBALL_NAME" \
    --null -T -

# 6. Verify successful creation
if [ $? -eq 0 ]; then
    echo "✅ Success! Tarball created successfully."
else
    echo "❌ Error: Failed to create the archive."
    exit 1
fi

