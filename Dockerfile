# Copyright 2021-2022 Integral Ad Science, Inc.
# MIT License - https://github.com/integralads/dependency-deep-scan-utilities/blob/master/README.md
FROM amazonlinux:2.0.20211001.0
MAINTAINER Sam Gleske <sgleske@integralads.com>

ARG MAVEN_VERSION=3.8.4

VOLUME /var/cache/yum
VOLUME /tmp
VOLUME /var/log

ADD configs/docker-scripts/* /usr/local/bin/

RUN set -ex; \
echo 'assumeyes=1' >> /etc/yum.conf; \
/usr/local/bin/reduced-log-run.sh -- yum makecache fast; \
/usr/local/bin/reduced-log-run.sh -- yum groupinstall "AWS Tools" "Development Tools"; \
/usr/local/bin/reduced-log-run.sh -- yum erase -y git; \
/usr/local/bin/reduced-log-run.sh -- yum install git2u intltool rsync

# Fix locale
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
RUN set -ex; \
/usr/local/bin/reduced-log-run.sh -- yum makecache fast; \
/usr/local/bin/reduced-log-run.sh -- yum install glibc-locale-source glibc-langpack-en; \
/usr/local/bin/reduced-log-run.sh -- yum reinstall glibc-common; \
localedef -i en_US -f UTF-8 en_US.UTF-8; \
echo -e 'LANG=en_US.utf-8\nLC_ALL=en_US.utf-8' >> /etc/environment; \
tee /etc/sysconfig/i18n <<<'"LANG=en_US.UTF-8"'

# Install container init process
RUN set -ex; \
curl -sSfLo /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.0/dumb-init_1.2.0_amd64; \
echo '81231da1cd074fdc81af62789fead8641ef3f24b6b07366a1c34e5b059faf363  /usr/local/bin/dumb-init' | sha256sum -c -; \
chmod 755 /usr/local/bin/dumb-init

# Install Maven 3.x
RUN set -ex; \
cd /opt/; \
MAVEN_URL="https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"; \
MAVEN_CHECKSUM="$( curl -sSfL "${MAVEN_URL}".sha512 | grep -o '^[0-9a-fA-F]\+' )"; \
MAVEN_ARCHIVE=/tmp/maven.tar.gz; \
curl -sSfLo "${MAVEN_ARCHIVE}" "${MAVEN_URL}"; \
sha512sum -c - <<< "${MAVEN_CHECKSUM}  ${MAVEN_ARCHIVE}"; \
tar -xzf "${MAVEN_ARCHIVE}"; \
find /opt/apache-maven* -maxdepth 0 -type d | xargs -n1 -I{} -- ln -s {} /opt/maven; \
echo 'export MAVEN_HOME=/opt/maven' >> /etc/profile.d/maven.sh; \
echo 'export PATH="${PATH}:${MAVEN_HOME}/bin"' >> /etc/profile.d/maven.sh

# Install Amazon corretto JDKs
# https://aws.amazon.com/corretto/
RUN set -ex; \
/usr/local/bin/reduced-log-run.sh -- rpm --import https://yum.corretto.aws/corretto.key; \
curl -sSfLo /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo; \
/usr/local/bin/reduced-log-run.sh -- yum makecache fast; \
/usr/local/bin/reduced-log-run.sh -- yum install -y java-1.7.0-openjdk-devel.x86_64 java-1.8.0-amazon-corretto-devel java-11-amazon-corretto-devel java-17-amazon-corretto-devel

# Add normal user and copy configs
ADD configs/dotfiles /usr/local/share/dotfiles
RUN set -ex; \
mkdir -p /etc/skel/{.m2,.gradle}; \
if [ -f /usr/local/share/dotfiles/settings.xml ]; then cp /usr/local/share/dotfiles/settings.xml /etc/skel/.m2/; fi; \
if [ -f /usr/local/share/dotfiles/init.gradle ]; then cp /usr/local/share/dotfiles/init.gradle /etc/skel/.gradle/; fi; \
adduser scanuser; \
mkdir -p ~scanuser/.m2 ~scanuser/.gradle; \
chown -R scanuser: ~scanuser


USER scanuser
WORKDIR /home/scanuser
ENV USER=scanuser HOME=/home/scanuser
ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD /bin/bash
