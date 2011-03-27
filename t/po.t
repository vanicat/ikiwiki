#!/usr/local/bin/perl
# -*- cperl-indent-level: 8; -*-
use warnings;
use strict;
use File::Temp qw{tempdir};

BEGIN {
	unless (eval { require Locale::Po4a::Chooser }) {
		eval q{
			use Test::More skip_all => "Locale::Po4a::Chooser::new is not available"
		}
	}
	unless (eval { require Locale::Po4a::Po }) {
		eval q{
			use Test::More skip_all => "Locale::Po4a::Po::new is not available"
		}
	}
}

use Test::More tests => 109;

BEGIN { use_ok("IkiWiki"); }

my $msgprefix;

my $dir = tempdir("ikiwiki-test-po.XXXXXXXXXX",
		  DIR => File::Spec->tmpdir,
		  CLEANUP => 1);

### Init
%config=IkiWiki::defaultconfig();
$config{srcdir} = "$dir/src";
$config{destdir} = "$dir/dst";
$config{destdir} = "$dir/dst";
$config{underlaydirbase} = "/dev/null";
$config{underlaydir} = "/dev/null";
$config{url} = "http://example.com";
$config{cgiurl} = "http://example.com/ikiwiki.cgi";
$config{discussion} = 0;
$config{po_master_language} = { code => 'en',
				name => 'English'
			      };
$config{po_slave_languages} = {
			       es => 'Castellano',
			       fr => "Français"
			      };
$config{po_translatable_pages}='index or test1 or test2 or translatable';
$config{po_link_to}='negotiated';
IkiWiki::loadplugins();
ok(IkiWiki::loadplugin('meta'), "meta plugin loaded");
ok(IkiWiki::loadplugin('po'), "po plugin loaded");
IkiWiki::checkconfig();

### seed %pagesources and %pagecase
$pagesources{'index'}='index.mdwn';
$pagesources{'index.fr'}='index.fr.po';
$pagesources{'index.es'}='index.es.po';
$pagesources{'test1'}='test1.mdwn';
$pagesources{'test1.es'}='test1.es.po';
$pagesources{'test1.fr'}='test1.fr.po';
$pagesources{'test2'}='test2.mdwn';
$pagesources{'test2.es'}='test2.es.po';
$pagesources{'test2.fr'}='test2.fr.po';
$pagesources{'test3'}='test3.mdwn';
$pagesources{'test3.es'}='test3.es.mdwn';
$pagesources{'translatable'}='translatable.mdwn';
$pagesources{'translatable.fr'}='translatable.fr.po';
$pagesources{'translatable.es'}='translatable.es.po';
$pagesources{'nontranslatable'}='nontranslatable.mdwn';
foreach my $page (keys %pagesources) {
	$IkiWiki::pagecase{lc $page}=$page;
}

### populate srcdir
writefile('index.mdwn', $config{srcdir},
          "[[!meta title=\"index title\"]]\n[[translatable]] [[nontranslatable]]");
writefile('test1.mdwn', $config{srcdir},
          "[[!meta title=\"test1 title\"]]\ntest1 content");
writefile('test2.mdwn', $config{srcdir}, 'test2 content');
writefile('test3.mdwn', $config{srcdir}, 'test3 content');
writefile('translatable.mdwn', $config{srcdir}, '[[nontranslatable]]');
writefile('nontranslatable.mdwn', $config{srcdir}, '[[/]] [[translatable]]');

### istranslatable/istranslation
# we run these tests twice because memoization attempts made them
# succeed once every two tries...
foreach (1, 2) {
ok(IkiWiki::Plugin::po::istranslatable('index'), "index is translatable");
ok(IkiWiki::Plugin::po::istranslatable('/index'), "/index is translatable");
ok(! IkiWiki::Plugin::po::istranslatable('index.fr'), "index.fr is not translatable");
ok(! IkiWiki::Plugin::po::istranslatable('index.es'), "index.es is not translatable");
ok(! IkiWiki::Plugin::po::istranslatable('/index.fr'), "/index.fr is not translatable");
ok(! IkiWiki::Plugin::po::istranslation('index'), "index is not a translation");
ok(IkiWiki::Plugin::po::istranslation('index.fr'), "index.fr is a translation");
ok(IkiWiki::Plugin::po::istranslation('index.es'), "index.es is a translation");
ok(IkiWiki::Plugin::po::istranslation('/index.fr'), "/index.fr is a translation");
ok(IkiWiki::Plugin::po::istranslatable('test1'), "test1 is translatable");
ok(IkiWiki::Plugin::po::istranslation('test1.es'), "test1.es is a translation");
ok(IkiWiki::Plugin::po::istranslation('test1.fr'), "test1.fr is a translation");
ok(IkiWiki::Plugin::po::istranslatable('test2'), "test2 is translatable");
ok(! IkiWiki::Plugin::po::istranslation('test2'), "test2 is not a translation");
ok(! IkiWiki::Plugin::po::istranslatable('test3'), "test3 is not translatable");
ok(! IkiWiki::Plugin::po::istranslation('test3'), "test3 is not a translation");
}

### pofiles

my @pofiles = IkiWiki::Plugin::po::pofiles(srcfile("index.mdwn"));
ok( @pofiles, "pofiles is defined");
ok( @pofiles == 2, "pofiles has correct size");
is_deeply(\@pofiles, ["$config{srcdir}/index.es.po", "$config{srcdir}/index.fr.po"], "pofiles content is correct");

### links
require IkiWiki::Render;

sub refresh_n_scan(@) {
	my @masterfiles_rel=@_;
	foreach my $masterfile_rel (@masterfiles_rel) {
		my $masterfile=srcfile($masterfile_rel);
		IkiWiki::scan($masterfile_rel);
		next unless IkiWiki::Plugin::po::istranslatable(pagename($masterfile_rel));
		my @pofiles=IkiWiki::Plugin::po::pofiles($masterfile);
		IkiWiki::Plugin::po::refreshpot($masterfile);
		IkiWiki::Plugin::po::refreshpofiles($masterfile, @pofiles);
		map IkiWiki::scan(IkiWiki::abs2rel($_, $config{srcdir})), @pofiles;
	}
}

$config{po_link_to}='negotiated';
$msgprefix="links (po_link_to=negotiated)";
refresh_n_scan('index.mdwn', 'translatable.mdwn', 'nontranslatable.mdwn');
is_deeply(\@{$links{'index'}}, ['translatable', 'nontranslatable'], "$msgprefix index");
is_deeply(\@{$links{'index.es'}}, ['translatable.es', 'nontranslatable'], "$msgprefix index.es");
is_deeply(\@{$links{'index.fr'}}, ['translatable.fr', 'nontranslatable'], "$msgprefix index.fr");
is_deeply(\@{$links{'translatable'}}, ['nontranslatable'], "$msgprefix translatable");
is_deeply(\@{$links{'translatable.es'}}, ['nontranslatable'], "$msgprefix translatable.es");
is_deeply(\@{$links{'translatable.fr'}}, ['nontranslatable'], "$msgprefix translatable.fr");
is_deeply(\@{$links{'nontranslatable'}}, ['/', 'translatable', 'translatable.fr', 'translatable.es'], "$msgprefix nontranslatable");

$config{po_link_to}='current';
$msgprefix="links (po_link_to=current)";
refresh_n_scan('index.mdwn', 'translatable.mdwn', 'nontranslatable.mdwn');
is_deeply(\@{$links{'index'}}, ['translatable', 'nontranslatable'], "$msgprefix index");
is_deeply(\@{$links{'index.es'}}, [ (map bestlink('index.es', $_), ('translatable.es', 'nontranslatable'))], "$msgprefix index.es");
is_deeply(\@{$links{'index.fr'}}, [ (map bestlink('index.fr', $_), ('translatable.fr', 'nontranslatable'))], "$msgprefix index.fr");
is_deeply(\@{$links{'translatable'}}, [bestlink('translatable', 'nontranslatable')], "$msgprefix translatable");
is_deeply(\@{$links{'translatable.es'}}, ['nontranslatable'], "$msgprefix translatable.es");
is_deeply(\@{$links{'translatable.fr'}}, ['nontranslatable'], "$msgprefix translatable.fr");
is_deeply(\@{$links{'nontranslatable'}}, ['/', 'translatable', 'translatable.fr', 'translatable.es'], "$msgprefix nontranslatable");

### targetpage
$config{usedirs}=0;
$msgprefix="targetpage (usedirs=0)";
is(targetpage('test1', 'html'), 'test1.en.html', "$msgprefix test1");
is(targetpage('test1.fr', 'html'), 'test1.fr.html', "$msgprefix test1.fr");
$config{usedirs}=1;
$msgprefix="targetpage (usedirs=1)";
is(targetpage('index', 'html'), 'index.en.html', "$msgprefix index");
is(targetpage('index.fr', 'html'), 'index.fr.html', "$msgprefix index.fr");
is(targetpage('test1', 'html'), 'test1/index.en.html', "$msgprefix test1");
is(targetpage('test1.fr', 'html'), 'test1/index.fr.html', "$msgprefix test1.fr");
is(targetpage('test3', 'html'), 'test3/index.html', "$msgprefix test3 (non-translatable page)");
is(targetpage('test3.es', 'html'), 'test3.es/index.html', "$msgprefix test3.es (non-translatable page)");

### urlto -> index
$config{po_link_to}='current';
$msgprefix="urlto (po_link_to=current)";
is(urlto('', 'index'), './index.en.html', "$msgprefix index -> ''");
is(urlto('', 'nontranslatable'), '../index.en.html', "$msgprefix nontranslatable -> ''");
is(urlto('', 'translatable.fr'), '../index.fr.html', "$msgprefix translatable.fr -> ''");
# when asking for a semi-absolute or absolute URL, we can't know what the
# current language is, so for translatable pages we use the master language
is(urlto('nontranslatable'), '/nontranslatable/', "$msgprefix 1-arg -> nontranslatable");
is(urlto('translatable'), '/translatable/index.en.html', "$msgprefix 1-arg -> translatable");
is(urlto('nontranslatable', undef, 1), 'http://example.com/nontranslatable/', "$msgprefix 1-arg -> nontranslatable");
is(urlto('index', undef, 1), 'http://example.com/index.en.html', "$msgprefix 1-arg -> index");
is(urlto('', undef, 1), 'http://example.com/index.en.html', "$msgprefix 1-arg -> ''");
# FIXME: should these three produce the negotiatable URL instead of the master
# language?
is(urlto(''), '/index.en.html', "$msgprefix 1-arg -> ''");
is(urlto('index'), '/index.en.html', "$msgprefix 1-arg -> index");
is(urlto('translatable', undef, 1), 'http://example.com/translatable/index.en.html', "$msgprefix 1-arg -> translatable");

$config{po_link_to}='negotiated';
$msgprefix="urlto (po_link_to=negotiated)";
is(urlto('', 'index'), './', "$msgprefix index -> ''");
is(urlto('', 'nontranslatable'), '../', "$msgprefix nontranslatable -> ''");
is(urlto('', 'translatable.fr'), '../', "$msgprefix translatable.fr -> ''");
is(urlto('nontranslatable'), '/nontranslatable/', "$msgprefix 1-arg -> nontranslatable");
is(urlto('translatable'), '/translatable/', "$msgprefix 1-arg -> translatable");
is(urlto(''), '/', "$msgprefix 1-arg -> ''");
is(urlto('index'), '/', "$msgprefix 1-arg -> index");
is(urlto('nontranslatable', undef, 1), 'http://example.com/nontranslatable/', "$msgprefix 1-arg -> nontranslatable");
is(urlto('translatable', undef, 1), 'http://example.com/translatable/', "$msgprefix 1-arg -> translatable");
is(urlto('index', undef, 1), 'http://example.com/', "$msgprefix 1-arg -> index");
is(urlto('', undef, 1), 'http://example.com/', "$msgprefix 1-arg -> ''");

### bestlink
$config{po_link_to}='current';
$msgprefix="bestlink (po_link_to=current)";
is(bestlink('test1.fr', 'test2'), 'test2.fr', "$msgprefix test1.fr -> test2");
is(bestlink('test1.fr', 'test2.es'), 'test2.es', "$msgprefix test1.fr -> test2.es");
$config{po_link_to}='negotiated';
$msgprefix="bestlink (po_link_to=negotiated)";
is(bestlink('test1.fr', 'test2'), 'test2.fr', "$msgprefix test1.fr -> test2");
is(bestlink('test1.fr', 'test2.es'), 'test2.es', "$msgprefix test1.fr -> test2.es");

### beautify_urlpath
$config{po_link_to}='default';
$msgprefix="beautify_urlpath (po_link_to=default)";
is(IkiWiki::beautify_urlpath('test1/index.en.html'), './test1/index.en.html', "$msgprefix test1/index.en.html");
is(IkiWiki::beautify_urlpath('test1/index.fr.html'), './test1/index.fr.html', "$msgprefix test1/index.fr.html");
$config{po_link_to}='negotiated';
$msgprefix="beautify_urlpath (po_link_to=negotiated)";
is(IkiWiki::beautify_urlpath('test1/index.html'), './test1/', "$msgprefix test1/index.html");
is(IkiWiki::beautify_urlpath('test1/index.en.html'), './test1/', "$msgprefix test1/index.en.html");
is(IkiWiki::beautify_urlpath('test1/index.fr.html'), './test1/', "$msgprefix test1/index.fr.html");
$config{po_link_to}='current';
$msgprefix="beautify_urlpath (po_link_to=current)";
is(IkiWiki::beautify_urlpath('test1/index.en.html'), './test1/index.en.html', "$msgprefix test1/index.en.html");
is(IkiWiki::beautify_urlpath('test1/index.fr.html'), './test1/index.fr.html', "$msgprefix test1/index.fr.html");

### re-scan
refresh_n_scan('index.mdwn');
is($pagestate{'index'}{meta}{title}, 'index title');
is($pagestate{'index.es'}{meta}{title}, 'index title');
is($pagestate{'index.fr'}{meta}{title}, 'index title');
refresh_n_scan('test1.mdwn');
is($pagestate{'test1'}{meta}{title}, 'test1 title');
is($pagestate{'test1.es'}{meta}{title}, 'test1 title');
is($pagestate{'test1.fr'}{meta}{title}, 'test1 title');

### istranslatedto
ok(IkiWiki::Plugin::po::istranslatedto('index', 'es'));
ok(IkiWiki::Plugin::po::istranslatedto('index', 'fr'));
ok(! IkiWiki::Plugin::po::istranslatedto('index', 'cz'));
ok(IkiWiki::Plugin::po::istranslatedto('test1', 'es'));
ok(IkiWiki::Plugin::po::istranslatedto('test1', 'fr'));
ok(! IkiWiki::Plugin::po::istranslatedto('test1', 'cz'));
ok(! IkiWiki::Plugin::po::istranslatedto('nontranslatable', 'es'));
ok(! IkiWiki::Plugin::po::istranslatedto('nontranslatable', 'cz'));
ok(! IkiWiki::Plugin::po::istranslatedto('test1.es', 'fr'));
ok(! IkiWiki::Plugin::po::istranslatedto('test1.fr', 'es'));
