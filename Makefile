# Copyright 2021-2022 Integral Ad Science, Inc.
# MIT License - https://github.com/integralads/dependency-deep-scan-utilities/blob/master/README.md
.PHONY: build check-docker csv docker find-no-repos

ifndef REPO_DIR
REPO_DIR := repos
endif
ifndef CACHE_DIR
CACHE_DIR := cache
endif
ifndef OUTPUT_DIR
OUTPUT_DIR := output
endif
ifndef PARALLEL
PARALLEL := 1
endif
ifndef MAVEN_VERSION
MAVEN_VERSION := 3.8.4
endif

help:
	@echo 'run in order:'
	@echo '    make build'
	@echo '    make progress'
	@echo '    make archive'
	@echo '    make reset-progress; Do NOT run after scan since it deletes files.  Run BEFORE a new scan.'
	@echo '    make docker'
	@echo 'alternate with customization:'
	@echo '    make build PARALLEL=10 REPO_DIR=path/to/bare/repos'

check-docker:
	@if ! docker images | grep deep-scanner &> /dev/null; then \
	echo 'Must run "make docker" to build the docker image for scanning code.' >&2; \
	exit 1; \
	fi

docker:
	docker build --build-arg MAVEN_VERSION="$(MAVEN_VERSION)" -t deep-scanner .

archive:
	find . -maxdepth 2 -type f -name '*.giturl' | cut -d/ -f2 | sort -u | xargs -- tar -czf results.tar.gz

build: check-docker repos find-no-repos $(CACHE_DIR) $(OUTPUT_DIR) 
	find $(REPO_DIR) -maxdepth 2 -type d -name '*.git' | \
	sed -e 's/\/\//\//g' | \
	xargs -P"$(PARALLEL)" -n1 -I'{}' -- bash dependency-scan.sh --cache "$(CACHE_DIR)" --output "$(OUTPUT_DIR)" --repo '{}'

interactive:
	docker run --rm -it -u root -v $(PWD):$(PWD) -w $(PWD) deep-scanner

progress:
	@echo 'Complete or in progress:'
	@find * -maxdepth 1 -type f -name '*.giturl' | wc -l
	@echo 'Failed scans:'
	@find * -maxdepth 1 -type f -name '*.failed' | wc -l
	@echo 'Number of containers running:'
	@docker ps -aq | wc -l

csv:
	./generate-csv.sh * > log4j-core-versions.csv

reset-progress:
	find * -maxdepth 1 -type f -name '*.giturl' -exec rm -f {} +
	find * -maxdepth 1 -type f -name '*.failed' -exec rm -f {} +

# make some directories for intermediate data
$(CACHE_DIR):
	mkdir -p "$(CACHE_DIR)"
	cp -f ./configs/cache-settings.xml "$(CACHE_DIR)"/
	cp -f ./configs/cache-init.gradle "$(CACHE_DIR)"/
	if [ "$$(uname)" = Linux ]; then \
	chown 1000:1000 "$(CACHE_DIR)" "$(CACHE_DIR)"/cache-settings.xml "$(CACHE_DIR)"/init.gradle; \
	fi
$(OUTPUT_DIR):
	mkdir -p "$(OUTPUT_DIR)"
	if [ "$$(uname)" = Linux ]; then chown 1000:1000 "$(OUTPUT_DIR)"; fi

repos:
	@if [ ! -d repos ]; then \
	echo 'There is no repos/ folder, see the README for how to clone your Git repositories.' >&2; \
	exit 1; \
	fi

find-no-repos:
	@if [ -z "$$(find repos -maxdepth 1 -name '*.git' | head -n1)" ]; then \
	echo 'The repos/ folder exists but there is no Git repository mirrors cloned.  Follow the README and clone your source code.' >&2; \
	exit 1; \
	fi
