#!/bin/bash
# Copyright 2021-2022 Integral Ad Science, Inc.
# MIT License - https://github.com/integralads/dependency-deep-scan-utilities/blob/master/README.md

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo 'ERROR: must set GITHUB_TOKEN environment variable with org:read and repo scopes.' >&2
  exit 1
fi

set -euo pipefail

function checksum() {
  if type -P shasum &> /dev/null; then
    shasum -a 512 "$@"
  elif type -P sha512sum &> /dev/null; then
    sha512sum "$@"
  else
    echo 'ERROR: could not find a SHA512 checksum utility...' >&2
    exit 1
  fi
}

if [ ! -f "cloneable.jar" ]; then
  curl -sSfLO https://github.com/samrocketman/cloneable/releases/download/0.8/cloneable.jar
  curl -sSfL https://github.com/samrocketman/cloneable/releases/download/0.8/cloneable.jar.sha512sum |
    checksum -c -
fi

find . -maxdepth 2 -type f -name '*.giturl' -exec cat {} + |
  grep -F -- git@github.com: |
  cut -d: -f2 | cut -d/ -f1 |
  sort -u | while read org; do

    echo "Getting repository list for ${org}." >&2
    java -jar cloneable.jar -o "${org}" \
      --skip-archived-repos --skip-empty-repos \
      "$@" | \
      sed "s#^#${org}/#" > "${org}".txt
done
