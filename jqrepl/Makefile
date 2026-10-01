##
##  Makefile for 'jqrepl'; just type 'make' to get help
##

ME = $(word $(words $(MAKEFILE_LIST)), $(MAKEFILE_LIST))
EDITOR ?= nano
TAG = jqrepl
# your Docker Hub account, for `make publish` (e.g. make publish DOCKER_HUB_USER=you)
DOCKER_HUB_USER ?=
DOCKER_HUB_TAG = $(DOCKER_HUB_USER)/$(TAG)

define _PERL_SCRIPT
	BEGIN {
		use Term::ANSIColor qw(:constants);
		$$max = 0;
		print "\n    ", BRIGHT_BLUE UNDERLINE "Makefile targets:\n\n", RESET;
	}
	if (/([-_\w]+):.*#\s+(.*)/) {
		$$max = length($$1) if length($$1) > $$max;
		push @targets, "$$1:$$2";
	}
	END {
		for (@targets) {
			($$t, $$h) = split /:/;
			printf "    %smake %-$${max}s%s    %s\n", BOLD, $$t, RESET, $$h;
		}
		printf "\n";
	}
endef
export _PERL_SCRIPT

help:  # you're looking at it ;)
	@perl -nE "$$_PERL_SCRIPT" $(ME)

build:  # build the Docker image
	docker build -t $(TAG) .

run:  # run the Docker image
	docker run -it -e EDITOR=$(EDITOR) --rm $(TAG)

test:  # run smoke and integration tests
	bash tests/smoke/run.sh && bash tests/integration/run.sh

publish:  # push the image to Docker Hub as DOCKER_HUB_USER/<image>
	@test -n "$(DOCKER_HUB_USER)" || { echo "set DOCKER_HUB_USER to your Docker Hub account, e.g. 'make publish DOCKER_HUB_USER=yourname'" >&2; exit 2; }
	docker tag $(TAG) $(DOCKER_HUB_TAG)
	docker push $(DOCKER_HUB_TAG)
