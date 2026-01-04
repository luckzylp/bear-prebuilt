#!/usr/bin/env bash
set -e
set -u
set -o pipefail

LATEST_TAG=$(curl -fsSL \
  https://api.github.com/repos/rizsotto/Bear/releases/latest \
  | jq -r .tag_name)

LAST_BUILT=$(cat last_built_tag 2>/dev/null || echo "")

echo "Latest Bear: $LATEST_TAG"
echo "Last built : $LAST_BUILT"

if [[ "$LATEST_TAG" != "$LAST_BUILT" ]]; then
  echo "changed=true" >> "$GITHUB_OUTPUT"
  echo "tag=$LATEST_TAG" >> "$GITHUB_OUTPUT"
else
  echo "changed=false" >> "$GITHUB_OUTPUT"
fi
