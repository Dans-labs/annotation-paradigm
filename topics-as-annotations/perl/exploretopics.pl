#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my $corpus_acro = 'huyg003';
my $corpus_name = 'Christiaan Huygens';

my ($ltf_file) = @ARGV;

if (!open(S, "<:encoding(UTF-8)", $ltf_file)) {
	print STDERR "Can't read file [$ltf_file]\n";
	exit 1;
}

sub dummy {
	1;
}

my %weight = ();
my %primeweight = ();
my %thresholdweight = ();
my %roughweight = ();
my %roughprimeweight = ();

my $nlines = 0;
my $ntlines = 0;

my $threshold = 0.6;

while (my $line = <S>) {
	if (substr($line, 0, 1) eq '#') {
		next;
	}
	chomp $line;
	$nlines ++;
	my @fields = split /\s+/, $line;
	shift @fields;
	shift @fields;
	my $first = 1;
	while (scalar @fields) {
		my $topic = shift @fields;
		my $weight = shift @fields;
		$weight{$topic} += $weight;
		$roughweight{$topic} += 1;
		if ($weight >= $threshold) {
			$thresholdweight{$topic} += $weight;
		}
		if ($first) {
			if ($weight >= $threshold) {
				$ntlines++;
			}
			$primeweight{$topic} += $weight;
			$roughprimeweight{$topic} += 1;
			$first = 0;
		}
	}
}

for my $topic (sort {$a <=> $b} keys %weight) {
	dummy();
	printf "%4d %5.4f %5.4f %5.4f %5.4f %5.4f %5.4f\n",
		$topic,
		$thresholdweight{$topic}/$ntlines,
		$thresholdweight{$topic}/$nlines,
		$roughprimeweight{$topic}/$nlines,
		$roughweight{$topic}/$nlines,
		$primeweight{$topic}/$nlines,
		$weight{$topic}/$nlines,
	;
}
printf "\n%d letters\n", $nlines;

close S;
