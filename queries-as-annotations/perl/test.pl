#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";
binmode(STDERR, ":utf8");

my $word = "בֹ֖קֶר";

my @chars = ();
for (my $i = 0; $i < length $word; $i++) {
	push @chars, substr $word, $i, 1;
}
my @bchars = split //, $word;

my $lhb = hex("05d0");
my $uhb = hex("05ea");
print STDERR "LHB=$lhb=".chr($lhb)."\n";
print STDERR "UHB=$uhb=".chr($uhb)."\n";

for my $ch (@bchars) {
	my $o = ord($ch);
	if ($lhb <= $o and $o <= $uhb) {
		printf STDERR "$ch [%d] ROOT\n", $o;
	}
	else {
		printf STDERR "$ch [%d] DIAC\n", $o;
	}
}
