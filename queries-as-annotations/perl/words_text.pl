#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my ($filein, $fileout) = @ARGV;

sub dummy {
	1;
}

if (!open(F, "<:encoding(UTF-8)", $filein)) {
	print STDERR "Can't read file [$filein]";
	exit 1;
}
if (!open(G, ">:encoding(UTF-8)", $fileout)) {
	print STDERR "Can't write to file [$fileout]";
	exit 1;
}

my $n = 0;
while (my $line = <F>) {
	$n++;
	if ($n % 1000 == 0) {
		printf STDERR "%6d\t\t\r", $n;
	}
	if ($line =~ m/^\s*[\]>]\s*\n/) {
		next;
	}
	use bytes;
	my ($isprefix, $extra) = $line =~ m/graphical_word="[^"]*([&-]|00)([_NSP]*)"/;
	$line =~ s/^.*?Word\s+[0-9]+\s*\{\s*([0-9]+)\s*\}.*?text="([^"]*).*/sprintf("%d\t<%s>",$1,$2,$3)/e;
	$line =~ s/\\x(..)/chr(hex($1))/ge;
	no bytes;

	$extra =~ s/_//g;
	$extra =~ s/N/נ/g;
	$extra =~ s/S/ס/g;
	$extra =~ s/P/פ/g;
	$isprefix = "\t".$isprefix."\t".$extra;
	$line =~ s/<([^>]*)>/$1$isprefix/;
	print G $line;
}
printf STDERR "%6d\t\t\n", $n;

close F;
close G;
