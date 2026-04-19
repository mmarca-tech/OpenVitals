#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: scripts/release.sh <version>  (e.g. 0.2.0)}"

if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Error: version must be in X.Y.Z format" >&2
    exit 1
fi

MAJOR=$(echo "$VERSION" | cut -d. -f1)
MINOR=$(echo "$VERSION" | cut -d. -f2)
PATCH=$(echo "$VERSION" | cut -d. -f3)
VERSION_CODE=$((MAJOR * 10000 + MINOR * 100 + PATCH))

sed -i "s/versionCode = [0-9]*/versionCode = $VERSION_CODE/" app/build.gradle.kts
sed -i "s/versionName = \"[^\"]*\"/versionName = \"$VERSION\"/" app/build.gradle.kts

git add app/build.gradle.kts
git commit -m "chore: release $VERSION"
git tag "v$VERSION"
git push origin main "v$VERSION"

echo "Released v$VERSION (versionCode $VERSION_CODE)"
