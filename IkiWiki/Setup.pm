#!/usr/bin/perl
# Ikiwiki setup files can be perl files that 'use IkiWiki::Setup::foo',
# passing it some sort of configuration data. Or, they can contain
# the module name at the top, without the 'use', and the whole file is
# then fed into that module.

package IkiWiki::Setup;

use warnings;
use strict;
use IkiWiki;
use open qw{:utf8 :std};
use File::Spec;

sub load ($;$) {
	my $file=IkiWiki::possibly_foolish_untaint(shift);
	my $safemode=shift;

	$config{setupfile}=File::Spec->rel2abs($file);

	#translators: The first parameter is a filename, and the second
	#translators: is a (probably not translated) error message.
	open (IN, $file) || error(sprintf(gettext("cannot read %s: %s"), $file, $!));
	my $content;
	{
		local $/=undef;
		$content=<IN> || error("$file: $!");
	}
	close IN;

	if ($content=~/(use\s+)?(IkiWiki::Setup::\w+)/) {
		$config{setuptype}=$2;
		if ($1) {
			error sprintf(gettext("cannot load %s in safe mode"), $file)
				if $safemode;
			eval IkiWiki::possibly_foolish_untaint($content);
			error("$file: ".$@) if $@;
		}
		else {
			eval qq{require $config{setuptype}};
			error $@ if $@;
			$config{setuptype}->loaddump(IkiWiki::possibly_foolish_untaint($content));
		}
	}
	else {
		error sprintf(gettext("failed to parse %s"), $file);
	}
}

sub dump ($) {
	my $file=IkiWiki::possibly_foolish_untaint(shift);
	
	eval qq{require $config{setuptype}};
	error $@ if $@;
	my @dump=$config{setuptype}->gendump(
		"Setup file for ikiwiki.",
		"",
		"Passing this to ikiwiki --setup will make ikiwiki generate",
		"wrappers and build the wiki.",
		"",
		"Remember to re-run ikiwiki --setup any time you edit this file.",
	);

	open (OUT, ">", $file) || die "$file: $!";
	print OUT "$_\n" foreach @dump;
	close OUT;
}

sub merge ($) {
	# Merge setup into existing config and untaint.
	my %setup=%{shift()};

	if (exists $setup{add_plugins} && exists $config{add_plugins}) {
		push @{$setup{add_plugins}}, @{$config{add_plugins}};
	}
	if (exists $setup{exclude}) {
		push @{$config{wiki_file_prune_regexps}}, $setup{exclude};
	}
	foreach my $c (keys %setup) {
		if (defined $setup{$c}) {
			if (! ref $setup{$c} || ref $setup{$c} eq 'Regexp') {
				$config{$c}=IkiWiki::possibly_foolish_untaint($setup{$c});
			}
			elsif (ref $setup{$c} eq 'ARRAY') {
				if ($c eq 'wrappers') {
					# backwards compatability code
					$config{$c}=$setup{$c};
				}
				else {
					$config{$c}=[map { IkiWiki::possibly_foolish_untaint($_) } @{$setup{$c}}]
				}
			}
			elsif (ref $setup{$c} eq 'HASH') {
				foreach my $key (keys %{$setup{$c}}) {
					$config{$c}{$key}=IkiWiki::possibly_foolish_untaint($setup{$c}{$key});
				}
			}
		}
		else {
			$config{$c}=undef;
		}
	}
	
	if (length $config{cgi_wrapper}) {
		push @{$config{wrappers}}, {
			cgi => 1,
			wrapper => $config{cgi_wrapper},
			wrappermode => (defined $config{cgi_wrappermode} ? $config{cgi_wrappermode} : "06755"),
		};
	}
}

sub getsetup () {
	# Gets all available setup data from all plugins. Returns an
	# ordered list of [plugin, setup] pairs.

        # disable logging to syslog while dumping, broken plugins may
	# whine when loaded
	my $syslog=$config{syslog};
        $config{syslog}=undef;

	# Load all plugins, so that all setup options are available.
	my @plugins=IkiWiki::listplugins();
	foreach my $plugin (@plugins) {
		eval { IkiWiki::loadplugin($plugin) };
		if (exists $IkiWiki::hooks{checkconfig}{$plugin}{call}) {
			my @s=eval { $IkiWiki::hooks{checkconfig}{$plugin}{call}->() };
		}
	}
	
	my %sections;
	foreach my $plugin (@plugins) {
		if (exists $IkiWiki::hooks{getsetup}{$plugin}{call}) {
			# use an array rather than a hash, to preserve order
			my @s=eval { $IkiWiki::hooks{getsetup}{$plugin}{call}->() };
			next unless @s;

			# set default section value (note use of shared
			# hashref between array and hash)
			my %s=@s;
			if (! exists $s{plugin} || ! $s{plugin}->{section}) {
				$s{plugin}->{section}="other";
			}

			# only the selected rcs plugin is included
			if ($config{rcs} && $plugin eq $config{rcs}) {
				$s{plugin}->{section}="core";
			}
			elsif ($s{plugin}->{section} eq "rcs") {
				next;
			}

			push @{$sections{$s{plugin}->{section}}}, [ $plugin, \@s ];
		}
	}
	
        $config{syslog}=$syslog;

	return map { sort { $a->[0] cmp $b->[0] } @{$sections{$_}} }
		sort { # core first, other last, otherwise alphabetical
			($b eq "core") <=> ($a eq "core")
			   ||
			($a eq "other") <=> ($b eq "other")
			   ||
			$a cmp $b
		} keys %sections;
}

sub commented_dump ($$) {
	my $dumpline=shift;
	my $indent=shift;

	my %setup=(%config);
	my @ret;
	
	# disable logging to syslog while dumping
	$config{syslog}=undef;

	eval q{use Text::Wrap};
	die $@ if $@;

	my %section_plugins;
	push @ret, commented_dumpvalues($dumpline, $indent, \%setup, IkiWiki::getsetup());
	foreach my $pair (IkiWiki::Setup::getsetup()) {
		my $plugin=$pair->[0];
		my $setup=$pair->[1];
		my %s=@{$setup};
		my $section=$s{plugin}->{section};
		push @{$section_plugins{$section}}, $plugin;
		if (@{$section_plugins{$section}} == 1) {
			push @ret, "", $indent.("#" x 70), "$indent# $section plugins",
				sub {
					wrap("$indent#   (", "$indent#    ",
						join(", ", @{$section_plugins{$section}})).")"
				},
				$indent.("#" x 70);
		}

		my @values=commented_dumpvalues($dumpline, $indent, \%setup, @{$setup});
		if (@values) {
			push @ret, "", "$indent# $plugin plugin", @values;
		}
	}

	return map { ref $_ ? $_->() : $_ } @ret;
}

sub commented_dumpvalues ($$$@) {
	my $dumpline=shift;
	my $indent=shift;
	my $setup=shift;
	my @ret;
	while (@_) {
		my $key=shift;
		my %info=%{shift()};

		next if $key eq "plugin" || $info{type} eq "internal";
		
		push @ret, "$indent# ".$info{description} if exists $info{description};
		
		if (exists $setup->{$key} && defined $setup->{$key}) {
			push @ret, $dumpline->($key, $setup->{$key}, $info{type}, "");
			delete $setup->{$key};
		}
		elsif (exists $info{example}) {
			push @ret, $dumpline->($key, $info{example}, $info{type}, "#");
		}
		else {
			push @ret, $dumpline->($key, "", $info{type}, "#");
		}
	}
	return @ret;
}

1
