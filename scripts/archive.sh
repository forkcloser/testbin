#!/usr/bin/env bash
# Archive a staged directory as <dist>/<name>.tar.gz, the same bytes for the
# same files whoever builds them, wherever and whenever.
#   archive.sh <stage directory> <name> <dist directory>
# <stage directory>/<name> is what the archive holds. Nothing of the build is
# recorded: entries by name, the time SOURCE_DATE_EPOCH for every one, owner
# and group 0 without names, modes 755 or 644, and no name or time in the
# gzip header.
set -euo pipefail

stage=${1:?stage directory}
name=${2:?name}
dist=${3:?dist directory}
epoch=${SOURCE_DATE_EPOCH:?the time every entry gets}

# What cp left depends on the umask.
find "${stage}/${name}" -type d -exec chmod 755 {} +
find "${stage}/${name}" -type f -perm -u+x -exec chmod 755 {} +
find "${stage}/${name}" -type f ! -perm -u+x -exec chmod 644 {} +

mkdir -p "${dist}"
# Under another name until it is whole: a tar that fails leaves no archive.
part="${dist}/${name}.tar.gz.part"
trap 'rm -f "${part}"' EXIT
tar -C "${stage}" --sort=name --format=ustar --owner=0 --group=0 --numeric-owner \
  --mtime="@${epoch}" -cf - "${name}" | gzip -n -9 > "${part}"
mv -f "${part}" "${dist}/${name}.tar.gz"
echo "→ ${dist}/${name}.tar.gz"
