#!/usr/local/bin/perl
use warnings;
use strict;
use Test::More tests => 11;

BEGIN { use_ok("IkiWiki"); }

# note: yesno always accepts English even if localized.
# So no need to bother setting locale to C.

ok(IkiWiki::yesno("yes") == 1);
ok(IkiWiki::yesno("Yes") == 1);
ok(IkiWiki::yesno("YES") == 1);

ok(IkiWiki::yesno("no") == 0);
ok(IkiWiki::yesno("No") == 0);
ok(IkiWiki::yesno("NO") == 0);

ok(IkiWiki::yesno("1") == 1);
ok(IkiWiki::yesno("0") == 0);
ok(IkiWiki::yesno("mooooooooooo") == 0);

ok(IkiWiki::yesno(undef) == 0);
