#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my ($filein, $fileout) = @ARGV;

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
	$line =~ s/^.*?Verse\s+[0-9]+\s*\{\s*([0-9]+)-([0-9]+)\s*\}.*?\(book="([^"]*)",chapter="([^"]*)",verse="([^"]*)"\).*/sprintf("%d\t%d\t%s\t%d\t%d",$1,$2,$3,$4,$5)/e;
	print G $line;
}
printf STDERR "%6d\t\t\n", $n;

close F;
close G;
