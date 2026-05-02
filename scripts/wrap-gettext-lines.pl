#!/usr/bin/env perl
# After merge -X theirs: restore gettext around user-visible strings.
# Pass 1: You(" -> You(_("   (insert _( before the format string's opening quote)
# Pass 2: _("..."); -> _("..."));   (close gettext + caller when first pass left one ); )
use strict;
use warnings;

my @macros = qw(
  Raw_printf verbalize You_feel You_cant
  pline You Your Norep There impossible panic exercise Withering feel_hint
);
my $m = join '|', map { quotemeta $_ } @macros;

while (<>) {
  unless (/^\s*(?:$m)\s*\(\s*_\("/) {
    s/\b($m)\s*\(\s*(")/$1 . '(_(' . $2/ge;
    # Do not match N_(" — second pass only applies to _(" gettext macro.
    s/(?<!N)_\("((?:[^"\\]|\\.)*)"\);/_("$1"\)\);/g;
  }
  print;
}
