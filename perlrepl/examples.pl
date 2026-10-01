# perlrepl - try different expressions above the #DATA marker
#
# Uncomment any example below to try it out, or write your own.
#
# print if /error/i;          # grep-like
# s/foo/bar/g; print;         # sed-like (-n is auto-added; with #ARGS -p, drop the print)
# print "$.: $_";             # line-numbered output
# chomp; print join ",", reverse split /\s+/; print "\n";

chomp; print uc($_) . "\n";

#DATA
hello world
foo bar
baz
