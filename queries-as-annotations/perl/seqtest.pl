#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

use Diff qw(sdiff);

binmode(STDOUT, ":utf8");

my $wivu = "xyz[d|e|f]ghijkl";
my $westm = "[b|c|d]ghiuvw";

my $w123 = "{a}{b}{cç}{ }{d}{f}{e}{.}{ }{u}{ée}{x}{y}{z}{ }{g}{üu}{!?}";

my $w4 = "{a}{b}{d}{e}{.}{ }{x}{y}{é}{ }{ü}{!}{z}";

sub chunk {
	my ($comp) = @_;
	my $rest = $comp;
	my @result = ();
	while (length($rest)) {
		my ($chunk, $newrest);
		($chunk, $newrest) = $rest =~ m/^\{([^\}]*)\}(.*)$/;
		if (defined $chunk) {
			push @result, $chunk;
			$rest = $newrest;
			next;
		}
	}
	return \@result;
}

sub keyGen {
	my ($item) = @_;
	my @keys = split //, $item;
	return \@keys;
}

for my $c (@{chunk($w123)}) {
	printf "-%s-", $c;
}
print "\n";
for my $c (@{chunk($w4)}) {
	printf "-%s-", $c;
}
print "\n";

for my $c (sdiff(chunk($w123), chunk($w4), \&keyGen)) {
	printf "%s <%s> <%s>\n", @$c;
}
