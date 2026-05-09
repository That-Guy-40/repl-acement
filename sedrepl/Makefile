##
##  Makefile for 'sedrepl'; just type 'make' to get help
##

ME = $(word $(words $(MAKEFILE_LIST)), $(MAKEFILE_LIST))
EDITOR ?= nano
TAG = sedrepl
DOCKER_HUB_TAG = ernstki/$(TAG)

define _PERL_SCRIPT
	BEGIN {
		use Term::ANSIColor qw(:REDIRECT);
		$$max = 0;
		print "\n    ", "Makefile targets:\n\n";
	}
	if (/([-_\w]+):.*#\s+(.*)/) {
		$$max = length($$1) if length($$1) > $$max;
		push @targets, "$$1:$$2";
	}
	END {
		for (@targets) {
			($$t, $$h) = split /:/;
			printf "    %s%-${max}s%s    %s\n", "", $$t, "", $$h;
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

publish:  # push the image to Docker Hub
	docker tag $(TAG) $(DOCKER_HUB_TAG)
	docker push $(DOCKER_HUB_TAG)
