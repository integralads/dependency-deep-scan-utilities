#!/bin/bash -l
# Copyright 2021-2022 Integral Ad Science, Inc.
# MIT License - https://github.com/integralads/dependency-deep-scan-utilities/blob/master/README.md
set -exo pipefail

# https://stackoverflow.com/questions/58991966/what-java-security-egd-option-is-for
export MAVEN_OPTS GRADLE_OPTS
MAVEN_OPTS='-Djava.security.egd=file:/dev/./urandom'" ${MAVEN_OPTS:-}"
GRADLE_OPTS='-Djava.security.egd=file:/dev/./urandom'" ${GRADLE_OPTS:-}"

java_versions=(
  openjdk8
  openjdk11
  openjdk17
  openjdk7
)

function canonical() {
  if grep -- '^/' <<< "$1" &> /dev/null; then
    echo "$1"
  else
    echo "$PWD"/"$1"
  fi
}

passthrough_args=()
# hack to run in docker container
output_dir=""
repo_dir=""
cache_dir=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      output_dir="$(canonical "${2%/}")"
      passthrough_args+=( "$1" "$output_dir")
      shift
      shift
      ;;
    --repo)
      repo_dir="$(canonical "${2%/}")"
      passthrough_args+=( "$1" "$repo_dir")
      shift
      shift
      ;;
    --cache)
      cache_dir="$(canonical "${2%/}")"
      passthrough_args+=( "$1" "$cache_dir")
      shift
      shift
      ;;
    *)
      echo "bad argument found: $1" >&2
      exit 1
      ;;
  esac
done

if [ ! -d /home/scanuser ]; then
  docker run -t --rm \
    -v "$repo_dir:$repo_dir" \
    -v "$output_dir:$output_dir" \
    -v "$cache_dir:/cache:ro" \
    -v "$cache_dir:/cache-rw:rw" \
    -v "$(canonical $0)":"$(canonical $0)" \
    deep-scanner:latest \
    bash -l "$(canonical $0)" "${passthrough_args[@]}"
  exit $?
fi

export TMP_DIR="$(mktemp -d)"
function initiateJavaToolchain() {
    case "${1:-}" in
        openjdk7)
            JAVA_HOME="$(find /usr/lib/jvm -maxdepth 1 -type d -name 'java-1.7*')"
            ;;
        openjdk8)
            JAVA_HOME="$(find /usr/lib/jvm -maxdepth 1 -type d -name 'java-1.8*')"
            ;;
        openjdk11)
            JAVA_HOME="$(find /usr/lib/jvm -maxdepth 1 -name 'java-11*')"
            ;;
        openjdk17)
            JAVA_HOME="$(find /usr/lib/jvm -maxdepth 1 -name 'java-17*')"
            ;;
        *)
          echo "Invalid Java version: '${1:-}'"
          exit 1
          ;;
    esac
    PATH="${JAVA_HOME}/bin:${PATH}"
    export JAVA_HOME PATH
}

function clone_code() (
  cd "$1"
  git config --get remote.origin.url > "$2"
  cd "${TMP_DIR}"
  if [ ! -d "$repo_name" ]; then
    git clone "$1"
  fi
)

function pull_maven_cache() {
  if [ -x mvnw ]; then
    mvn=( ./mvnw )
  else
    mvn=( mvn )
  fi
  mvn+=( -Dmaven.main.skip=true -Dmaven.test.skip=true test-compile dependency:resolve )
  if [ -f ~/.m2/settings.xml ]; then
    cp -f ~/.m2/settings.xml ~/.m2/settings.xml.bak
  fi
  cp -f /cache/cache-settings.xml ~/.m2/settings.xml
  "${mvn[@]}" || true
  if [ -f ~/.m2/settings.xml.bak ]; then
    mv -f ~/.m2/settings.xml.bak ~/.m2/settings.xml
  fi
}

function scan_pom() (
  cd "${TMP_DIR}/$repo_name"
  if [ -x mvnw ]; then
    mvn=( ./mvnw )
  else
    mvn=( mvn )
  fi
  mvn+=( -Dmaven.main.skip=true -Dmaven.test.skip=true test-compile )
  if [ -f "${2%.*}".java_version ]; then
    (
      initiateJavaToolchain "$(< "${2%.*}".java_version)"
      pull_maven_cache
      "${mvn[@]}" dependency:resolve
      "${mvn[@]}" dependency:tree > "$2"
    ) ||
    (
      touch "$output_dir/${repo_name}".failed
    )
  else
    for java_version in "${java_versions[@]}"; do
      # if success then don't try any more Java
      # if failure try  other versions of Java
      if ( \
          initiateJavaToolchain "${java_version}"; \
          pull_maven_cache; \
          "${mvn[@]}" dependency:resolve; \
          "${mvn[@]}" dependency:tree > "$2"; \
          echo "${java_version}" > "${2%.*}".java_version; \
          ); then
        # success so remove the failed marker file
        rm -f "$2".failed
        break
      else
        touch "$output_dir/${repo_name}".failed
      fi
    done
  fi
)

function get_wrapper_url() {
  awk -F= '$1 == "distributionUrl" { print $2;exit}' < gradle/wrapper/gradle-wrapper.properties | sed -e 's/\\//g'
}

function prepare_gradle_wrapper() {
  cp -f /cache/init.gradle ~/.gradle/init.gradle
  wrapper_url="$(get_wrapper_url)"
  wrapper_zip="${wrapper_url##*/}"
  if [ ! -d /cache/wrapper ]; then
    mkdir -p /cache-rw/wrapper
  fi
  if [ ! -f /cache/wrapper/"${wrapper_zip}" ]; then
    curl -sSfLo /cache-rw/wrapper/"${wrapper_zip}" "${wrapper_url}"
  fi
  sed -i.bak -e 's#^\(distributionUrl=\).*#\1file\\:///cache/wrapper/'"${wrapper_zip}#" -- gradle/wrapper/gradle-wrapper.properties
  rm -f gradle/wrapper/gradle-wrapper.properties.bak
}

function pull_gradle_cache() {
  if [ -f ~/.gradle/init.gradle ]; then
    cp -f ~/.gradle/init.gradle ~/.gradle/init.gradle.bak
  fi
  cp -f /cache/cache-init.gradle ~/.gradle/init.gradle
  ./gradlew dependencies
  if [ -f ~/.gradle/init.gradle.bak ]; then
    mv -f ~/.gradle/init.gradle.bak ~/.gradle/init.gradle
  fi
}

function scan_gradle() (
  cd "${TMP_DIR}/$repo_name"
  prepare_gradle_wrapper
  if [ -f "${2%.*}".java_version ]; then
    (
      initiateJavaToolchain "$(< "${2%.*}".java_version)"
      pull_gradle_cache
      ./gradlew dependencies
      ./gradlew dependencies > "$2"
    ) ||
    (
      touch "$2".failed
    )
  else
    for java_version in "${java_versions[@]}"; do
      # if success then don't try any more Java
      # if failure try  other versions of Java
      if ( \
            initiateJavaToolchain "${java_version}"; \
            pull_gradle_cache; \
            ./gradlew dependencies; \
            ./gradlew dependencies > "$2"; \
            echo "${java_version}" > "${2%.*}".java_version; \
          ); then
        # success so remove the failed marker file
        rm -f "$2".failed
        break
      else
        touch "$output_dir/${repo_name}".failed
      fi
    done
  fi
)

function archive_caches() {
  for x in "${caches[@]}"; do
    rsync -a "${x}"/ "/cache-rw/${x##*/}"/
  done
}

function prepare_cache() {
  if [ ! -d "${cache_dir}/${1##*/}" ]; then
    mkdir -p "/cache-rw/${1##*/}"
  fi
  if [ ! -d "$1" ]; then
    mkdir -p "$1"
  fi
  if ! [ "$1" = ~/.m2/repository ]; then
    rsync -a "/cache/${1##*/}"/ "$1"/
  fi
  caches+=( "$1" )
}

caches=()
# archive caches for reuse when script exits
trap 'archive_caches' EXIT
repo_name="${repo_dir##*/}"
repo_name="${repo_name%.git}"
export output_dir repo_dir cache_dir repo_name

#
# Prepare repo
#
clone_code "$repo_dir" "$output_dir"/"${repo_name}.giturl"

#
# Maven scans
#
if [ -f "${TMP_DIR}/${repo_name}"/pom.xml ]; then
  prepare_cache ~/.m2/repository
  scan_pom "$repo_dir" "$output_dir/${repo_name}.maven_dependencies"
fi

#
# Gradle scans
#
if [ -f "${TMP_DIR}/${repo_name}"/gradlew ]; then
  prepare_cache ~/.m2/repository
  prepare_cache ~/.gradle/caches
  scan_gradle "$repo_dir" "$output_dir/${repo_name}.gradle_dependencies"
fi
