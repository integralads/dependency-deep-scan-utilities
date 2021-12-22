#!/bin/bash
# Copyright 2021-2022 Integral Ad Science, Inc.
# MIT License - https://github.com/integralads/dependency-deep-scan-utilities/blob/master/README.md
set -eo pipefail

function isArchived() {
  if [ ! -f "${1%%/*}".txt ]; then
    return 1
  fi
  ! grep "^$1\$" "${1%%/*}".txt >& /dev/null
}

function getLog4j() {
  grep -o 'org.apache.logging.log4j:log4j-core:.*' | \
    grep -v '[.0-9]\+ *-> *[.0-9]\+' | \
    awk -F: '$3 == "jar" { print $4; next }; !($3 == "jar") { print $3 }' | \
    grep -o '^[.0-9]\+' | sort -u | xargs echo | tr ' ' '|' || echo
}

function getLogs() {
  local files=()
  if [ -f "${1}".maven_dependencies ]; then
    files+=( "${1}".maven_dependencies )
  fi

  if [ -f "${1}".gradle_dependencies ]; then
    files+=( "${1}".gradle_dependencies )
  fi

  if [ -n "${files:-}" ]; then
    cat "${files[@]}"
  else
    echo
  fi

}

echo 'Project,log4j-core,Hosting,"Git URL"'
find "$@" -type f -name '*.java_version' | while read x; do
  repo_name="${x%.*}"
  if [ -e "${repo_name}.failed" ]; then
    echo "${repo_name}.failed exists.  Skipping..." >&2
    continue
  fi
  if isArchived "${repo_name}"; then
    continue
  fi
  if grep -i -- bitbucket "${repo_name}".giturl &> /dev/null; then
    hosting=Bitbucket
  else
    hosting=GitHub
  fi
  if [ ! -f "${repo_name}".giturl ]; then
    echo missing "${repo_name}".giturl >&2
    continue
  fi
  giturl="$(< "${repo_name}".giturl)"
  project="${giturl##*:}"
  project="${project%.git}"
  log4j="$(getLogs "${repo_name}" | getLog4j)"
  if [ -z "${log4j}" ]; then
    continue
  fi
  repo_name="${repo_name##*/}"
  if [ -n "${log4j:-}" ]; then
    echo "${project},${log4j},${hosting},${giturl}"
  fi
done
