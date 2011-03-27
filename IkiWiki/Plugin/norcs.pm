#!/usr/local/bin/perl
# Stubs for no revision control.
package IkiWiki::Plugin::norcs;

use warnings;
use strict;
use IkiWiki;

sub import {
	hook(type => "getsetup", id => "norcs", call => \&getsetup);
	hook(type => "rcs", id => "rcs_update", call => \&rcs_update);
	hook(type => "rcs", id => "rcs_prepedit", call => \&rcs_prepedit);
	hook(type => "rcs", id => "rcs_commit", call => \&rcs_commit);
	hook(type => "rcs", id => "rcs_commit_staged", call => \&rcs_commit_staged);
	hook(type => "rcs", id => "rcs_add", call => \&rcs_add);
	hook(type => "rcs", id => "rcs_remove", call => \&rcs_remove);
	hook(type => "rcs", id => "rcs_rename", call => \&rcs_rename);
	hook(type => "rcs", id => "rcs_recentchanges", call => \&rcs_recentchanges);
	hook(type => "rcs", id => "rcs_diff", call => \&rcs_diff);
	hook(type => "rcs", id => "rcs_getctime", call => \&rcs_getctime);
	hook(type => "rcs", id => "rcs_getmtime", call => \&rcs_getmtime);
}

sub getsetup () {
	return
		plugin => {
			safe => 0, # rcs plugin
			rebuild => 0,
			section => "rcs",
		},
}


sub rcs_update () {
}

sub rcs_prepedit ($) {
	return ""
}

sub rcs_commit (@) {
	return undef # success
}

sub rcs_commit_staged (@) {
	return undef # success
}

sub rcs_add ($) {
}

sub rcs_remove ($) {
}

sub rcs_rename ($$) {
}

sub rcs_recentchanges ($) {
}

sub rcs_diff ($;$) {
}

sub rcs_getctime ($) {
	return 0;
}

sub rcs_getmtime ($) {
	return 0;
}

1
