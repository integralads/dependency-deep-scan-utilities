# Deep scanning for log4j

IAS created an open source project, [dependency-deep-scan-utilities][repo] which
detects log4j vulnerabilities ([CVE-2021-44228][CVE-2021-44228] and
[CVE-2021-45046][CVE-2021-45046]) in your source code.

Because of the widespread use of log4j, ease of exploit, and ability to perform
remote code execution, IAS open sourced this project to help everyone mitigate
this exploit.

dependency-deep-scan-utilities is a command line tool which you run against your
source code. dependency-deep-scan-utilities goes through every git repository
and uses Maven and Gradle to find transitive usage of vulnerable log4j-core in
order to detect when your code is susceptible to the log4shell security
vulnerability. Then dependency-deep-scan-utilities takes the resulting output of
all scans and creates a CSV file including the project, log4j-core version, and
Git clone URL so that teams can organize and prioritize mitigation.

### Table of Contents

- [Java and Build Tool Support](#java-and-build-tool-support)
- [Benchmarks](#benchmarks)
- [Prerequisite setup](#prerequisite-setup)
  - [Credentials](#credentials)
  - [Support for Corporate Maven Proxies](#support-for-corporate-maven-proxies)
  - [Clone bare repositories](#clone-bare-repositories)
    - [Manually cloning bare repositories](#manually-cloning-bare-repositories)
    - [Automatically clone GitHub repositories](#automatically-clone-github-repositories)
- [Getting started: Scan dependencies](#getting-started-scan-dependencies)
  - [Build Docker image](#build-docker-image)
  - [Run scan](#run-scan)
  - [Alternate Run Scan](#alternate-run-scan)
  - [Create CSV files](#create-csv-files)
- [How to update your CSV by rerunning scans](#how-to-update-your-csv-by-rerunning-scans)
- [Limitations](#limitations)
  - [Performance limitations](#performance-limitations)
  - [Build tool limitations](#build-tool-limitations)
    - [Maven 3.8](#maven-38)
    - [Gradle wrapper only](#gradle-wrapper-only)
    - [No SBT support](#no-sbt-support)
  - [No multi-project repositories](#no-multi-project-repositories)
- [License](#license)

# Benchmarks

This project takes roughly 3 hours to scan 2000 repositories.  This includes
rerunning the scan which would use dependencies cached to disk as part of
scanning.

# Java and Build Tool Support

OpenJDK Java support:

* OpenJDK 1.7
* OpenJDK 1.8 (provided by [Amazon Corretto][amazon-corretto])
* OpenJDK 11 (provided by [Amazon Corretto][amazon-corretto])
* OpenJDK 17 (provided by [Amazon Corretto][amazon-corretto])

Build tool support:

* Gradle (only with Gradle wrapper)
* Maven (assumes Maven 3.8 but can be customized)

# Prerequisite setup

### Credentials

All repositores are assumed to be [cloned with SSH using an SSH clone
URL][github-ssh].  This project assumes bare repositories have been cloned
already before running scans.  This is to enable wider suport for non-GitHub
hosted Git repositories.

For automatic repository cloning you'll need to create a [GitHub personal access
token][github-pat] with scopes `org:read` and `repo` for private repositories.
No scopes are necessary if all projects are public/open source.

### Support for Corporate Maven Proxies

Run the following script and provide your corporate proxy as an argument.

    ./create-maven-dotfiles.sh https://nexus.example.com/repository/maven-public/

It will create the following files.

    configs/dotfiles/init.gradle
    configs/dotfiles/settings.xml

Feel free to further edit these files for your corporate proxy needs.  Later
when you [Build the Docker image](#build-docker-image) these files will be
included as the default Maven and Gradle config files for dependency resolution.

### Clone bare repositories

This project scans bare repositories located in the `repos/` directory.  You
have a couple of options for cloning bare repositories.

- Manually cloning bare repositories
- Automatically clone GitHub repositories

Both of these options are discussed in this section below.

#### Manually cloning bare repositories

You can clone bare repositories into the `repos/` directory.  If you're working
with a single organization in GitHub or another source then you can

```
cd repo/
git clone --mirror git@host:namespace/repo.git
```
#### Automatically clone GitHub repositories

By default this project scans for bare repositories in the `repos/` directory
(which is ignored in Git).  `git clone --mirror URL` your git repositories for
scanning into that directory.  If you're using GitHub Enterprise or GitHub, then
you can use the [`cloneable` utility][cloneable] to mirror your bare repositories.

If you're using a self-hosted GitHub Enterprise, then set the following
environment variable.

```bash
export GITHUB_GRAPHQL_URL='https://[hostname]/api/graphql'
```

To run this script create a GitHub personal access token with scopes `org:read`
and `repo`.  The `--owner` can be a GitHub user or GitHub organization.

```bash
GITHUB_OWNER="<your user or org to clone repos>"
curl -LO https://github.com/samrocketman/cloneable/releases/download/0.8/cloneable.jar
mkdir repos
cd repos/
export GITHUB_TOKEN
read -ersp token: GITHUB_TOKEN
# skip empty repos, skip archived repos, and find compatible projects
java -jar ../cloneable.jar -buae -F pom.xml -F gradlew --owner "${GITHUB_OWNER}" \
  | xargs -r -n1 -P16 -- git clone --mirror
```

# Getting started: Scan dependencies

### Build Docker image

Before running any scans you'll need to build a docker image.  To build the
default docker image run the following command.

    make docker

If you'd like to customize the version of Maven 3.x used by the Docker image you
can run the following command.

    make docker MAVEN_VERSION=3.5.4

If you need a version of Maven other than 3.x you'll need to modify the
[`Dockerfile`](Dockerfile).

### Run scan

If your host is a Mac due to performance limitations we recommend running the
scan serially (see [Limitations](#limitations)).

    make build

If your host is Linux and at least 8 vCPUS with 32GB RAM then run 10 scans in
parallel.

    make build PARALLEL=10

Feel free to adjust your parallelism for your own hosts needs.  Parallelism of
`10` means 10 docker containers will be launched at a time to perform scans
until all repositories have been scanned.

### Alternate Run Scan

This section is for advanced use cases.  You can skip this if the prior section
for running scans is good enough for your organization.

If you do not wish to use the `repos/` directory and you already have a Git
repository backup with bare repositories... you can choose an alternate
directory providing the full path to the alternate bare repository location.

    make build PARALLEL=10 REPO_DIR=/alternate/repos/path

If you have multiple alternate repository paths and you don't want the scanning
results to conflict you can specify multiple scan scan results directories.

    make build PARALLEL=10 REPO_DIR=/alternate/repos/path1 OUTPUT_DIR=path1
    make build PARALLEL=10 REPO_DIR=/alternate/repos/path2 OUTPUT_DIR=path2

### Create CSV files

Once all of the dependency scanning is complete you can generate a CSV file
covering the whole org.

    make csv

The result of `Usage` will create a CSV file at the root of the repository.

    ls log4j-core-versions.csv

If you're working from a large Git backup and you'd like to limit what shows up
in the spreadsheet then you can run the following script.

```bash
./get-unarchived-repositories.sh

# alternately only show GitHub repositories contributed within the last year
./get-unarchived-repositories.sh --after 1y
```

Upload `log4j-core-versions.csv` to your favorite spreadsheet software and start
a coordinated approach to fixing log4j issues in your organization.

# How to update your CSV by rerunning scans

It makes sense to run a scan multiple times as teams patch their projects with a
new version of log4j-core.  You can rerun scans by resetting progress metadata
and then running another scan.

    make reset-progress
    make build
    make csv

You can get progress updates by running `make progress` as the scan progresses.

You can update your team spreadsheet with the new `log4j-core-versions.csv`.

# Limitations

### Performance limitations

Docker for Mac does not perform very well with Docker in parallel.  Running
`make build` (defaults to non parallel) is the recomendation when performing a
scan using Mac OS.

We highly recomend using a Linux host.  From there scanning can be parallelized
to launch separate docker containers per repository.  The maximum recommended
parallelism is 10 for a machine with 8 vCPUs and 32GB of RAM.

    make build PARALEL=10

If you open a second terminal you can see how quickly the scan is progressing by
running the following make command.

    make progress

### Build tool limitations

#### Maven 3.8

We use Maven 3.8 to scan repositories containing `pom.xml`.  If you need a lower
version but still a Maven 3.x version, then you can rebuild the docker image
with an older version of Maven 3.x.

    make docker MAVEN_VERSION=3.5.4

If Maven 3.x version of Maven is too new for your projects, then you'll need to
update the [`Dockerfile`](Dockerfile).  Change the maven installation commands
to whatever Maven version you need.

#### Gradle wrapper only

For gradle repositories, we only scan repositories using Gradle Wraper (if a
repo has a `./gradlew` script).  Due to incompatible differences across several
versions of Gradle it has been deemed too much work to try to account for all
the nuance.  Instead, update all projects missing Gradle wraper to use it.

#### No SBT support

SBT projects are not included at this time.  We may add support for them
eventually but for now SBT is excluded from scans.

#### No multi-project repositories

This assumes a single Git repository contains a single Maven or Gradle project
and only source code associated with the project.  Multi-module projects are
okay but multiple sub directories with independent projects is not supported by
this tool.

### Find projects excluded due to limitation

If you're on GitHub, then you can find which projects are using Gradle without
Gradle Wrapper or using SBT.

    java -jar cloneable.jar -F build.gradle -F build.sbt -E gradlew --owner "your GitHub org"

You could potentially find projects which may contain subfolders of build tools
if it doesn't have any build tools at its root.  If your company uses other
build tools then you may want to also exclude them in the following command.

    java -jar cloneable.jar -E pom.xml -E build.gradle -E build.sbt -E gradlew --owner "your GitHub org"

See `java -jar cloneable.jar --help` for additional usage and exclusion
capabilities.

# License

This project is MIT Licensed.  See [`COPYING.txt`](COPYING.txt) and
[`LICENSE.txt`](LICENSE.txt) for details.

[CVE-2021-44228]: https://nvd.nist.gov/vuln/detail/CVE-2021-44228
[CVE-2021-45046]: https://nvd.nist.gov/vuln/detail/CVE-2021-45046
[amazon-corretto]: https://aws.amazon.com/corretto/
[cloneable]: https://github.com/samrocketman/cloneable/releases/tag/0.8
[github-pat]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
[github-ssh]: https://docs.github.com/en/get-started/getting-started-with-git/about-remote-repositories#cloning-with-ssh-urls
[repo]: https://github.com/integralads/dependency-deep-scan-utilities
