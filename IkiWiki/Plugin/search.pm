#!/usr/local/bin/perl
# xapian-omega search engine plugin
package IkiWiki::Plugin::search;

use warnings;
use strict;
use IkiWiki 3.00;

sub import {
	hook(type => "getsetup", id => "search", call => \&getsetup);
	hook(type => "checkconfig", id => "search", call => \&checkconfig);
	hook(type => "pagetemplate", id => "search", call => \&pagetemplate);
	hook(type => "indexhtml", id => "search", call => \&indexhtml);
	hook(type => "delete", id => "search", call => \&delete);
	hook(type => "cgi", id => "search", call => \&cgi);
	hook(type => "disable", id => "search", call => \&disable);
}

sub getsetup () {
	return
		plugin => {
			safe => 1,
			rebuild => 1,
			section => "web",
		},
		omega_cgi => {
			type => "string",
			example => "/usr/lib/cgi-bin/omega/omega",
			description => "path to the omega cgi program",
			safe => 0, # external program
			rebuild => 0,
		},
}

sub checkconfig () {
	foreach my $required (qw(url cgiurl)) {
		if (! length $config{$required}) {
			error(sprintf(gettext("Must specify %s when using the %s plugin"), $required, 'search'));
		}
	}
	
	if (! defined $config{omega_cgi}) {
		$config{omega_cgi}="/usr/lib/cgi-bin/omega/omega";
	}

	# This is a mass dependency, so if the search form template
	# changes, every page is rebuilt.
	add_depends("", "templates/searchform.tmpl");
}

my $form;
sub pagetemplate (@) {
	my %params=@_;
	my $page=$params{page};
	my $template=$params{template};

	# Add search box to page header.
	if ($template->query(name => "searchform")) {
		if (! defined $form) {
			my $searchform = template("searchform.tmpl", blind_cache => 1);
			$searchform->param(searchaction => IkiWiki::cgiurl());
			$searchform->param(html5 => $config{html5});
			$form=$searchform->output;
		}

		$template->param(searchform => $form);
	}
}

my $scrubber;
my $stemmer;
sub indexhtml (@) {
	my %params=@_;

	setupfiles();

	# A unique pageterm is used to identify the document for a page.
	my $pageterm=pageterm($params{page});
	return unless defined $pageterm;
	
	my $db=xapiandb();
	my $doc=Search::Xapian::Document->new();
	my $caption=pagetitle($params{page});
	my $title;
	if (exists $pagestate{$params{page}}{meta} &&
		exists $pagestate{$params{page}}{meta}{title}) {
		$title=$pagestate{$params{page}}{meta}{title};
	}
	else {
		$title=$caption;
	}

	# Remove html from text to be indexed.
	if (! defined $scrubber) {
		eval q{use HTML::Scrubber};
		if (! $@) {
			$scrubber=HTML::Scrubber->new(allow => []);
		}
	}
	my $toindex = defined $scrubber ? $scrubber->scrub($params{content}) : $params{content};
	
	# Take 512 characters for a sample, then extend it out
	# if it stopped in the middle of a word.
	my $size=512;
	my ($sample)=substr($toindex, 0, $size);
	if (length($sample) == $size) {
		my $max=length($toindex);
		my $next;
		while ($size < $max &&
		       ($next=substr($toindex, $size++, 1)) !~ /\s/) {
			$sample.=$next;
		}
	}
	$sample=~s/\n/ /g;
	
	my $url=urlto($params{destpage}, "");
	if (defined $pagestate{$params{page}}{meta}{permalink}) {
		$url=$pagestate{$params{page}}{meta}{permalink}
	}

	# data used by omega
	# Decode html entities in it, since omega re-encodes them.
	eval q{use HTML::Entities};
	error $@ if $@;
	$doc->set_data(
		"url=".$url."\n".
		"sample=".decode_entities($sample)."\n".
		"caption=".decode_entities($caption)."\n".
		"modtime=$IkiWiki::pagemtime{$params{page}}\n".
		"size=".length($params{content})."\n"
	);

	# Index document and add terms for other metadata.
	my $tg = Search::Xapian::TermGenerator->new();
	if (! $stemmer) {
		my $langcode=$ENV{LANG} || "en";
		$langcode=~s/_.*//;

		# This whitelist is here to work around a xapian bug (#486138)
		my @whitelist=qw{da de en es fi fr hu it no pt ru ro sv tr};

		if (grep { $_ eq $langcode } @whitelist) {
			$stemmer=Search::Xapian::Stem->new($langcode);
		}
		else {
			$stemmer=Search::Xapian::Stem->new("english");
		}
	}
	$tg->set_stemmer($stemmer);
	$tg->set_document($doc);
	$tg->index_text($params{page}, 2);
	$tg->index_text($caption, 2);
	$tg->index_text($title, 2) if $title ne $caption;
	$tg->index_text($toindex);
	$tg->index_text(lc($title), 1, "S"); # for title:foo
	foreach my $link (@{$links{$params{page}}}) {
		$tg->index_text(lc($link), 1, "XLINK"); # for link:bar
	}

	$doc->add_term($pageterm);
	$db->replace_document_by_term($pageterm, $doc);
}

sub delete (@) {
	my $db=xapiandb();
	foreach my $page (@_) {
		my $pageterm=pageterm(pagename($page));
		$db->delete_document_by_term($pageterm) if defined $pageterm;
	}
}

sub cgi ($) {
	my $cgi=shift;

	if (defined $cgi->param('P')) {
		# only works for GET requests
		chdir("$config{wikistatedir}/xapian") || error("chdir: $!");
		$ENV{OMEGA_CONFIG_FILE}="./omega.conf";
		$ENV{CGIURL}=IkiWiki::cgiurl();
		IkiWiki::loadindex();
		$ENV{HELPLINK}=htmllink("", "", "ikiwiki/searching",
			noimageinline => 1, linktext => "Help");
		exec($config{omega_cgi}) || error("$config{omega_cgi} failed: $!");
	}
}

sub pageterm ($) {
	my $page=shift;

	# 240 is the number used by omindex to decide when to hash an
	# overlong term. This does not use a compatible hash method though.
	if (length $page > 240) {
		eval q{use Digest::SHA};
		if ($@) {
			debug("search: ".sprintf(gettext("need Digest::SHA to index %s"), $page)) if $@;
			return undef;
		}

		# Note no colon, therefore it's guaranteed to not overlap
		# with a page with the same name as the hash..
		return "U".lc(Digest::SHA::sha1_hex($page));
	}
	else {
		return "U:".$page;
	}
}

my $db;
sub xapiandb () {
	if (! defined $db) {
		eval q{
			use Search::Xapian;
			use Search::Xapian::WritableDatabase;
		};
		error($@) if $@;
		$db=Search::Xapian::WritableDatabase->new($config{wikistatedir}."/xapian/default",
			Search::Xapian::DB_CREATE_OR_OPEN());
	}
	return $db;
}

{
my $setup=0;
sub setupfiles () {
	if (! $setup and (! -e $config{wikistatedir}."/xapian" || $config{rebuild})) {
		writefile("omega.conf", $config{wikistatedir}."/xapian",
			"database_dir .\n".
			"template_dir ./templates\n");
		
		# Avoid omega interpreting anything in the cgitemplate
		# as an omegascript command.
		eval q{use IkiWiki::CGI};
		my $template=IkiWiki::cgitemplate(undef, gettext("search"), "\0",
			searchform => "", # avoid showing the small search form
		);
		eval q{use HTML::Entities};
		error $@ if $@;
		$template=encode_entities($template, '\$');

		my $querytemplate=readfile(IkiWiki::template_file("searchquery.tmpl"));
		$template=~s/\0/$querytemplate/;

		writefile("query", $config{wikistatedir}."/xapian/templates",
			$template);
		$setup=1;
	}
}
}

sub disable () {
	if (-d $config{wikistatedir}."/xapian") {
		system("rm", "-rf", $config{wikistatedir}."/xapian");
	}
}

1
