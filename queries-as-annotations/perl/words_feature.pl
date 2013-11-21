#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my ($anchor_file, $filein, $fileout) = @ARGV;

if (!open(A, "<:encoding(UTF-8)", $anchor_file)) {
	print STDERR "Can't read file [$anchor_file]";
	exit 1;
}
if (!open(F, "<:encoding(UTF-8)", $filein)) {
	print STDERR "Can't read file [$filein]";
	exit 1;
}
if (!open(G, ">:encoding(UTF-8)", $fileout)) {
	print STDERR "Can't write to file [$fileout]";
	exit 1;
}

my %anchors = ();
printf STDERR "%s\n", "Reading anchors";
while (my $line = <A>) {
	chomp $line;
	my ($anch, $wnum) = split /\t/, $line;
	$anchors{$wnum} = $anch;
}
close A;

printf STDERR "%s\n", "Processing features";
my $n = 0;
while (my $line = <F>) {
	$n++;
	if ($n % 1000 == 0) {
		printf STDERR "%6d\t\t\r", $n;
	}
	if ($line =~ m/^\s*[\]>]\s*\n/) {
		next;
	}
	$line =~ s/^.*?Word\s+[0-9]+\s*\{\s*([0-9]+)\s*\}[^(]*\(([^)]*)\).*\n/sprintf("%s\t%s\n",$anchors{$1},$2)/e;
    $line =~ s/,[^=]+="(?:none|unknown)"//g;
    $line =~ s/\t[^=]+="(?:none|unknown)",/\t/g;
    $line =~ s/,[^=]+="Absent_lexical_set"//;
	printf G $line;
}
printf STDERR "%6d\t\t\n", $n;

close F;
close G;
