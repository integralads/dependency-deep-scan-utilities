#!/bin/bash
# Copyright 2021-2022 Integral Ad Science, Inc.
# MIT License - https://github.com/integralads/dependency-deep-scan-utilities/blob/master/README.md
set -eo pipefail

function checkDependencyFormat() {
  while read -er line; do
    # support for comments and blank lines
    if [ -z "${line:-}" ] || grep '^ *#.*' <<< "${line:-}" &> /dev/null; then
      continue
    fi

    # check format for maven group/artifact
    if ! grep '^[^:]\+:[^:]\+:[^:]*$' <<< "$line" &> /dev/null; then
      echo 'ERROR: scan-for-dependencies.txt has an invalid line. Must be a maven group:artifact format.' >&2
      echo 'Malformed line (quotes added to find spaces):' >&2
      echo "    '$line'"
      echo 'Example of a valid line (group:artifact:extension):' >&2
      echo '    org.apache.logging.log4j:log4j-core:jar' >&2
      exit 1
    fi
  done < scan-for-dependencies.txt
}

function getDependencyListForSearching() {
  grep -o '^[^:]\+:[^:]\+:[^:]*$' scan-for-dependencies.txt
}

function isArchived() {
  if [ ! -f "${1%%/*}".txt ]; then
    return 1
  fi
  ! grep "^$1\$" "${1%%/*}".txt >& /dev/null
}

function searchGroupArtifactFormat() {
    local group
    local artifact
    local format
    group="$1"
    artifact="$2"
    format="${3:-}"
    grep -o "${group}:${artifact}:.*" | \
      grep -v '[.0-9]\+ *-> *[.0-9]\+' | \
      awk -F: -v format="${format:-}" '$3 == format { print $4; next }; !($3 == format) { print $3 }' | \
      grep -o '^[.0-9]\+' | sed 's/\.$//' | sort -u | xargs echo | tr ' ' '|' || echo
}

function findDependencies() {
  local group
  local artifact
  local format
  local version
  local dependency_list
  dependency_list="$(getDependencyListForSearching)"
  while read -er line; do
    echo "${dependency_list}" | xargs -n1 | while read -er searchArtifact; do
      group="$(cut -d: -f1 <<< "${searchArtifact}")"
      artifact="$(cut -d: -f2 <<< "${searchArtifact}")"
      format="$(cut -d: -f3 <<< "${searchArtifact}")"
      version="$(echo "$line" | searchGroupArtifactFormat "${group}" "${artifact}" "${format:-}")"
      if [ -n "${version:-}" ]; then
        echo "${group},${artifact},${version}"
      fi
    done
  done | sort -u
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
    getDependencyListForSearching > grep-scan-for-dependencies.txt
    grep -f grep-scan-for-dependencies.txt -- "${files[@]}" || echo
  else
    echo
  fi

}

# check the dependency search strings to ensure it is valid before attempting
# to walk through logs
checkDependencyFormat

echo 'Project,Group,Artifact,Version,Hosting,"Git URL"'
find "$@" -type f -name '*.java_version' | while read -er x; do
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
  getLogs "${repo_name}" | findDependencies | while read -er dependency; do
    if [ -z "${dependency:-}" ]; then
      continue
    fi
    echo "${project},${dependency},${hosting},${giturl}"
  done
done
