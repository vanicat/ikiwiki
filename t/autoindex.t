#!/usr/local/bin/perl
package IkiWiki;

use warnings;
use strict;
use Test::More tests => 38;

BEGIN { use_ok("IkiWiki"); }
BEGIN { use_ok("IkiWiki::Render"); }
BEGIN { use_ok("IkiWiki::Plugin::aggregate"); }
BEGIN { use_ok("IkiWiki::Plugin::autoindex"); }
BEGIN { use_ok("IkiWiki::Plugin::html"); }
BEGIN { use_ok("IkiWiki::Plugin::mdwn"); }

ok(! system("rm -rf t/tmp; mkdir t/tmp"));

$config{verbose} = 1;
$config{srcdir} = 't/tmp';
$config{underlaydir} = 't/tmp';
$config{underlaydirbase} = '.';
$config{templatedir} = 'templates';
$config{usedirs} = 1;
$config{htmlext} = 'html';
$config{wiki_file_chars} = "-[:alnum:]+/.:_";
$config{userdir} = "users";
$config{tagbase} = "tags";
$config{default_pageext} = "mdwn";
$config{wiki_file_prune_regexps} = [qr/^\./];
$config{autoindex_commit} = 0;

is(checkconfig(), 1);

%oldrenderedfiles=%pagectime=();
%pagesources=%pagemtime=%oldlinks=%links=%depends=%typedlinks=%oldtypedlinks=
%destsources=%renderedfiles=%pagecase=%pagestate=();

# Pages that (we claim) were deleted in an earlier pass. We're using deleted,
# not autofile, to test backwards compat.
$wikistate{autoindex}{deleted}{deleted} = 1;
$wikistate{autoindex}{deleted}{expunged} = 1;
$wikistate{autoindex}{deleted}{reinstated} = 1;

foreach my $page (qw(tags/numbers deleted/bar reinstated reinstated/foo gone/bar)) {
	# we use a non-default extension for these, so they're distinguishable
	# from programmatically-created pages
	$pagesources{$page} = "$page.html";
	$pagemtime{$page} = $pagectime{$page} = 1000000;
	writefile("$page.html", "t/tmp", "your ad here");
}

# a directory containing only an internal page shouldn't be indexed
$pagesources{"has_internal/internal"} = "has_internal/internal._aggregated";
$pagemtime{"has_internal/internal"} = 123456789;
$pagectime{"has_internal/internal"} = 123456789;
writefile("has_internal/internal._aggregated", "t/tmp", "this page is internal");

# a directory containing only an attachment should be indexed
$pagesources{"attached/pie.jpg"} = "attached/pie.jpg";
$pagemtime{"attached/pie.jpg"} = 123456789;
$pagectime{"attached/pie.jpg"} = 123456789;
writefile("attached/pie.jpg", "t/tmp", "I lied, this isn't a real JPEG");

# "gone" disappeared just before this refresh pass so it still has a mtime
$pagemtime{gone} = $pagectime{gone} = 1000000;

my %pages;
my @del;

IkiWiki::Plugin::autoindex::refresh();

# this page is still on record as having been deleted, because it has
# a reason to be re-created
is($wikistate{autoindex}{autofile}{"deleted.mdwn"}, 1);
is($autofiles{"deleted.mdwn"}{plugin}, "autoindex");
%pages = ();
@del = ();
IkiWiki::gen_autofile("deleted.mdwn", \%pages, \@del);
is_deeply(\%pages, {});
is_deeply(\@del, []);
ok(! -f "t/tmp/deleted.mdwn");

# this page is tried as an autofile, but because it'll be in @del, it's not
# actually created
ok(! exists $wikistate{autoindex}{autofile}{"gone.mdwn"});
%pages = ();
@del = ("gone.mdwn");
is($autofiles{"gone.mdwn"}{plugin}, "autoindex");
IkiWiki::gen_autofile("gone.mdwn", \%pages, \@del);
is_deeply(\%pages, {});
is_deeply(\@del, ["gone.mdwn"]);
ok(! -f "t/tmp/gone.mdwn");

# this page does not exist and has no reason to be re-created, but we no longer
# have a special case for that - see
# [[todo/autoindex_should_use_add__95__autofile]] - so it won't be created
# even if it gains subpages later
is($wikistate{autoindex}{autofile}{"expunged.mdwn"}, 1);
ok(! exists $autofiles{"expunged.mdwn"});
ok(! -f "t/tmp/expunged.mdwn");

# a directory containing only an internal page shouldn't be indexed
ok(! exists $wikistate{autoindex}{autofile}{"has_internal.mdwn"});
ok(! exists $autofiles{"has_internal.mdwn"});
ok(! -f "t/tmp/has_internal.mdwn");

# this page was re-created, but that no longer gets a special case
# (see [[todo/autoindex_should_use_add__95__autofile]]) so it's the same as
# deleted
is($wikistate{autoindex}{autofile}{"reinstated.mdwn"}, 1);
ok(! exists $autofiles{"reinstated.mdwn"});
ok(! -f "t/tmp/reinstated.mdwn");

# needs creating (deferred; part of the autofile mechanism now)
ok(! exists $wikistate{autoindex}{autofile}{"tags.mdwn"});
%pages = ();
@del = ();
is($autofiles{"tags.mdwn"}{plugin}, "autoindex");
IkiWiki::gen_autofile("tags.mdwn", \%pages, \@del);
is_deeply(\%pages, {"t/tmp/tags" => 1});
is_deeply(\@del, []);
ok(! -s "t/tmp/tags.mdwn");
ok(-s "t/tmp/.ikiwiki/transient/tags.mdwn");

# needs creating because of an attachment
ok(! exists $wikistate{autoindex}{autofile}{"attached.mdwn"});
%pages = ();
@del = ();
is($autofiles{"attached.mdwn"}{plugin}, "autoindex");
IkiWiki::gen_autofile("attached.mdwn", \%pages, \@del);
is_deeply(\%pages, {"t/tmp/attached" => 1});
is_deeply(\@del, []);
ok(-s "t/tmp/.ikiwiki/transient/attached.mdwn");

1;
