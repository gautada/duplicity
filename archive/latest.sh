#!/usr/bin/env bash
set -euo pipefail
REPO="duplicity"
PROJECT="${REPO}%2F${REPO}"
API="https://gitlab.com/api/v4/projects/${PROJECT}/releases/permalink/latest"

tag="$(curl -fsSL "$API" | jq -r '.tag_name')"
version="${tag#rel.}"
echo "$version"
