#!/usr/bin/perl

=head2 idea

Use collatex

=cut

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my ($test, $filein, $resultout, $granularity, $maxiter, $windowsize, $commonality) = @ARGV;
my $extra = '"algorithm": "dekker", "tokenComparator": {"type": "equality" }';

my %granularities = (
	chapter => 1,
	verse   => 0,
);

my $fileinpath;
my $resultpath;

my %sources = ();

sub readsource {
	print STDERR "reading the sources ...\n";
	if (!open(INF, "<:encoding(UTF-8)", $fileinpath)) {
		print STDERR "Cannot read file [$fileinpath]\n";
		return 0;
	}
	my $good = 1;
	while (my $line = <INF>) {
		chomp $line;
		if ($line =~ m/^Data/) {
			next;
		}
		my ($source, $text) = $line =~ m/^([^:]+):\s*(.*)$/;
		if (!defined $source) {
			print STDERR "Strange input [$line]\n";
			$good = 0;
			next;
		}
		$source =~ s/\s+$//;
		$sources{$source} = $text;
	}
	close INF;
	printf STDERR "\nnumber of sources: %d\n", scalar(keys(%sources)); 
	return $good;
}

sub gentokens {
	print STDERR "writing the tokens ...\n";
	my $good = 1;
	if (!open(TF, ">:encoding(UTF-8)", $resultpath)) {
		print STDERR "Cannot write file [$resultpath]\n";
		$good = 0;
		next;
	}
	print TF "{\"witnesses\" : [\n";
	my $sep = "";
	for my $source (sort keys %sources) {
		printf TF "$sep\t{\"id\" : \"%s\", \"content\" : \"%s\"}\n", $source, $sources{$source};
		$sep = ',';
	}
	print TF "], $extra}\n";
	close TF;
	return $good;
}

sub initialize {
	my $good = 1;

	my $testrep;
	if ($test == 2) {
		$testrep = '-test';
	}
	elsif ($test == 1) {
		$testrep = '-limited';
	}
	else {
		$testrep = '';
	}

	$fileinpath = sprintf "%s%s-max%d-win%d-comm%.1f-%s-%s.txt", $filein, $testrep, $maxiter, $windowsize, $commonality, 'dat', 'final';
	$resultpath = sprintf "%s%s-max%d-win%d-comm%.1f.txt", $resultout, $testrep, $maxiter, $windowsize, $commonality;

	if (!$granularities{$granularity}) {
		print STDERR "Unsupported granularity [$granularity].\nChoose one of ".join(", ", sort(keys(%granularities)))."\n";
		$good = 0;
	}
	return $good;
}

sub main {
	my $good = 1;
	for (1) {
		if (!initialize()) {
			$good = 0;
			next;
		}
		if (!readsource()) {
			$good = 0;
			next;
		}

		if (!gentokens()) {
			$good = 0;
			next;
		}
	}
	return $good;
}

exit !main();
