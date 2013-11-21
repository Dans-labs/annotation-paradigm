#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my ($data_file, $text_file) = @ARGV;

if (!open(D, "<:encoding(UTF-8)", $data_file)) {
	print STDERR "Can't read file [$data_file]\n";
	exit 1;
}
if (!open(T, ">:encoding(UTF-8)", $text_file)) {
	print STDERR "Can't write to file [$text_file]\n";
	exit 1;
}

sub dummy {
	1;
}

my %bk_acro_name = (
	gen	=> 'Genesis',
	exo	=> 'Exodus',
	lev	=> 'Leviticus',
	num	=> 'Numbers',
	deu	=> 'Deuteronomy',
	jos	=> 'Joshua',
	jud	=> 'Judges',
	sa1	=> '1 Samuel',
	sa2	=> '2 Samuel',
	ki1	=> '1 Kings',
	ki2	=> '2 Kings',
	isa	=> 'Isaiah',
	jer	=> 'Jeremiah',
	eze	=> 'Ezekiel',
	hos	=> 'Hosea',
	joe	=> 'Joel',
	amo	=> 'Amos',
	oba	=> 'Obadiah',
	jon	=> 'Jonah',
	mic	=> 'Micah',
	nah	=> 'Nahum',
	hab	=> 'Habakkuk',
	zep	=> 'Zephaniah',
	hag	=> 'Haggai',
	zec	=> 'Zechariah',
	mal	=> 'Malachi',
	psa	=> 'Psalms',
	job	=> 'Job',
	pro	=> 'Proverbs',
	rut	=> 'Ruth',
	can	=> 'Song of Songs',
	ecc	=> 'Ecclesiastes',
	lam	=> 'Lamentations',
	est	=> 'Esther',
	dan	=> 'Daniel',
	ezr	=> 'Ezra',
	neh	=> 'Nehemiah',
	ch1	=> '1 Chronicles',
	ch2	=> '2 Chronicles',
);

my %strangechars = ();

while (my $line = <D>) {
	if ($line =~ m/^\s*$/) {
		next;
	}
	if (substr($line,0,1) eq "‪") {
		next;
	}
	if (substr($line,0,1) eq "‫") {
		$line = substr($line, 1);
		$line =~ s/‬\r?$//;
		$line =~ s/‪[^‬]*‬//g;
		$line =~ s/‍/~/g;
		my ($vers, $chap, $text) = $line =~ m/^[\s ]*([0-9]+)[\s ]*׃[\s ]*([0-9]+)[\s ]*(.*)$/;
		printf T "%d:%d\t%s\n", $vers, $chap, $text;
		my @chars = split //, $text;
		for my $c (@chars) {
			my $o = ord($c);
			if ($o > hex "2000") {
				$strangechars{$c}++;
			}
		}
		next;
	}
	my ($acro) = $line =~ m/^ book (...)$/;
	if (defined $acro) {
		printf T "B\t%s\t%s\n", $acro, $bk_acro_name{$acro};
	}
}
close D;
close T;

binmode(STDERR, ":utf8");

for my $c (sort keys %strangechars) {
	printf STDERR "%x [%s] %dx\n", ord($c), $c, $strangechars{$c};
}
