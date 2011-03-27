#!/usr/local/bin/perl
# Ikiwiki parentlinks plugin.
package IkiWiki::Plugin::parentlinks;

use warnings;
use strict;
use IkiWiki 3.00;

sub import {
	hook(type => "parentlinks", id => "parentlinks", call => \&parentlinks);
	hook(type => "pagetemplate", id => "parentlinks", call => \&pagetemplate);
	hook(type => "getsetup", id => "parentlinks", call => \&getsetup);
}

sub getsetup () {
	return 
		plugin => {
			safe => 1,
			rebuild => 1,
			section => "core",
		},
}

sub parentlinks ($) {
	my $page=shift;

	if (! length $page) {
		# dynamic page
		return {
			url => IkiWiki::baseurl(undef),
			page => $config{wikiname},
		};
	}

	my @ret;
	my $path="";
	my $title=$config{wikiname};
	my $i=0;
	my $depth=0;
	my $height=0;

	my @pagepath=(split("/", $page));
	my $pagedepth=@pagepath;
	foreach my $dir (@pagepath) {
		next if $dir eq 'index';
		$depth=$i;
		$height=($pagedepth - $depth);
		push @ret, {
			url => urlto(bestlink($page, $path), $page),
			page => $title,
			depth => $depth,
			height => $height,
			"depth_$depth" => 1,
			"height_$height" => 1,
		};
		$path.="/".$dir;
		$title=pagetitle($dir);
		$i++;
	}
	return @ret;
}

sub pagetemplate (@) {
	my %params=@_;
        my $template=$params{template};

	if ($template->query(name => "parentlinks") ||
	    $template->query(name => "has_parentlinks")) {
		my @links=parentlinks($params{page});
		$template->param(parentlinks => \@links);
		$template->param(has_parentlinks => (@links > 0));
	}
}

1
