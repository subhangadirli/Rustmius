#!/usr/bin/env bash
#
# Build a .rpm package for Rustmius (Fedora / RHEL / openSUSE family).
#
# Usage:
#   packages/rpm/build-rpm.sh
#
# Output: dist/rustmius-<version>-<release>.<arch>.rpm (in the repo root)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

PKG_NAME="rustmius"
VERSION="$(grep -m1 '^version' Cargo.toml | sed -E 's/.*"(.*)".*/\1/')"

command -v rpmbuild >/dev/null 2>&1 || {
    echo "!! rpmbuild not found. Install it with: sudo dnf install rpm-build rpmdevtools" >&2
    exit 1
}

echo ">> Packaging $PKG_NAME $VERSION (.rpm)"

# Private rpmbuild tree so this never touches ~/rpmbuild.
TOPDIR="$(mktemp -d)"
trap 'rm -rf "$TOPDIR"' EXIT
mkdir -p "$TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Snapshot the working tree (including uncommitted edits, like build-deb.sh
# building straight from target/release) into a source tarball. Name matches
# the spec's %autosetup -n rustmius-$VERSION.
tar --exclude=.git --exclude=target --exclude=dist \
    --transform "s,^,$PKG_NAME-$VERSION/," \
    -czf "$TOPDIR/SOURCES/$PKG_NAME-$VERSION.tar.gz" -- *

cp "packages/rpm/$PKG_NAME.spec" "$TOPDIR/SPECS/"

rpmbuild --define "_topdir $TOPDIR" -ba "$TOPDIR/SPECS/$PKG_NAME.spec"

mkdir -p dist
find "$TOPDIR/RPMS" -name '*.rpm' -exec cp -v {} dist/ \;
find "$TOPDIR/SRPMS" -name '*.rpm' -exec cp -v {} dist/ \;

echo ""
echo ">> Built RPM(s) in dist/:"
ls -1 dist/*.rpm
