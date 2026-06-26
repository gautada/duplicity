#!/usr/bin/env bash
set -euo pipefail

pkg="${1:-}"

if [[ -z "$pkg" ]]; then
  echo "Usage: $0 <debian-package-name>" >&2
  echo "Example: $0 duplicity" >&2
  exit 1
fi

version="$(
  apt-cache policy "$pkg" |
    awk '/Candidate:/ {print $2}'
)"

# shellcheck disable=SC3014
if [[ -z "$version" || "$version" == "(none)" ]]; then
  echo "Package not found in configured APT repositories: $pkg" >&2
  exit 2
fi

echo "$version"
