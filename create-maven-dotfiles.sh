#!/bin/bash
# Copyright 2021-2022 Integral Ad Science, Inc.
# MIT License - https://github.com/integralads/dependency-deep-scan-utilities/blob/master/README.md
set -euo pipefail
if [ -z "${1:-}" ]; then
  echo 'Must provide a Maven repository URL as the first argument.' >&2
  exit 1
fi

MAVEN_URL="$1"

cat > configs/dotfiles/settings.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<settings xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.1.0 http://maven.apache.org/xsd/settings-1.1.0.xsd" xmlns="http://maven.apache.org/SETTINGS/1.1.0"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <mirrors>
    <mirror>
      <mirrorOf>*</mirrorOf>
      <name>maven-public</name>
      <url>${MAVEN_URL}</url>
      <id>maven-public</id>
    </mirror>
  </mirrors>
</settings>
EOF

cat > configs/dotfiles/init.gradle <<EOF
allprojects {
    buildscript {
        repositories {
            mavenLocal()
            maven { url "${MAVEN_URL}" }
        }
    }
    repositories {
        mavenLocal()
        maven { url "${MAVEN_URL}" }
    }
}
EOF

echo 'The following dotfiles have been generated.' >&2
echo '    configs/dotfiles/init.gradle' >&2
echo '    configs/dotfiles/settings.xml' >&2
echo 'Feel free to modify them further for your needs.  They will be baked into the docker container performing log4j scans.' >&2
echo >&2
echo 'Next run the following make command to create the scanner docker image.' >&2
echo '    make docker' >&2
