##
##  Top-level Makefile for repl-acement; just type 'make' to get help.
##
##  Per-REPL suites live under each subproject (awkrepl/, sedrepl/, …); the
##  end-to-end suite under tests/e2e drives each REPL's real tmux UI.
##

ME = $(word $(words $(MAKEFILE_LIST)), $(MAKEFILE_LIST))
REPLS = awkrepl sedrepl jqrepl yqrepl mlrrepl perlrepl

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

test:  # run every subproject's suite, then the end-to-end suite
	@set -e; for d in $(REPLS); do \
	    echo "############ $$d ############"; \
	    $(MAKE) -C $$d test; \
	done
	@$(MAKE) e2e

unit:  # run only the per-REPL smoke + integration suites
	@set -e; for d in $(REPLS); do \
	    echo "############ $$d ############"; \
	    $(MAKE) -C $$d test; \
	done

e2e:  # run the live-UI end-to-end suite (needs tmux + entr)
	bash tests/e2e/run.sh

.PHONY: help test unit e2e
