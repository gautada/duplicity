#!/bin/sh
#
# This script checks if the container version matches the latest Debian release.
# It reads /etc/debian_version to get the current version and compares it
# against the latest Debian stable release version fetched via curl.
# Returns 0 if versions match, non-zero otherwise.

# Get current Debian version directly from /etc/debian_version
CURRENT_VERSION=$(/usr/bin/duplicity | awk '{print $2}')
if [ -z "$CURRENT_VERSION" ]; then
  echo "Failed to read application version"
  exit 1
fi

app_latest() {
  pkg="duplicity"
  suite="stable"
  arch="amd64"
  curl -fsSL "https://deb.debian.org/debian/dists/${suite}/main/binary-${arch}/Packages.xz" |
  xz -dc |
  awk -v pkg="$pkg" '
    BEGIN { RS=""; FS="\n" }
    {
      p=""; v="";
      for (i=1; i<=NF; i++) {
        if ($i ~ /^Package: /) p=substr($i,10);
        if ($i ~ /^Version: /) v=substr($i,10);
      }
      if (p == pkg) print v;
    }
  ' | sed 's/-.*//'
}

# Get latest Debian stable version from the Release file
LATEST_VERSION=$(app_latest)
if [ -z "${LATEST_VERSION}" ]; then
  echo "Failed to fetch latest application package version"
  exit 1
fi

echo "Current version: ${CURRENT_VERSION}"
echo "Latest version:  ${LATEST_VERSION}"

if [ "${CURRENT_VERSION}" = "${LATEST_VERSION}" ]; then
  echo "Version check passed"
  exit 0
else
  echo "Version check failed: versions do not match"
  exit 1
fi
