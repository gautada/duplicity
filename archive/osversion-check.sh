#!/bin/sh
#
# Health check: verifies the running homepage version is consistent with the
# latest release on GitHub. Calls /usr/bin/container-version for the running
# version and /usr/bin/container-latest for the latest release tag.
# Passes if the running version STARTS WITH the latest release version,
# allowing for build-patch suffixes (e.g. 1.10.1-2 passes for 1.10.1).
# Returns 0 if versions match, non-zero otherwise.

# Get the version of the running homepage instance
CURRENT_VERSION=$(/usr/bin/container-version | tr -d '[:space:]')
if [ -z "${CURRENT_VERSION}" ]; then
  echo "Failed to get running app version from /usr/bin/container-version"
  exit 1
fi

# Get the latest release version from GitHub
LATEST_VERSION=$(/usr/bin/container-latest)
if [ -z "$LATEST_VERSION" ]; then
  echo "Failed to get latest release version from /usr/bin/container-latest"
  exit 1
fi

echo "Current version: ${CURRENT_VERSION}"
echo "Latest version:  ${LATEST_VERSION}"

# Pass if CURRENT_VERSION starts with LATEST_VERSION.
# Uses POSIX case pattern to handle build-patch suffixes.
# No subprocesses or external tools required.
case "${CURRENT_VERSION}" in
  "${LATEST_VERSION}"*)
    echo "Version check passed"
    exit 0
    ;;
  *)
    echo "Version check failed: ${CURRENT_VERSION} does not start with ${LATEST_VERSION}"
    exit 1
    ;;
esac
