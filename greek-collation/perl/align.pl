#!/usr/bin/perl

=head2 idea

Use collatex

=cut

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";
use Time::HiRes qw (gettimeofday time tv_interval);

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my $curl = "/usr/bin/curl";
my $localserver = "http://localhost:7369/collate";

my ($test, $filein, $resultout, $granularity, $outputtype, $maxiter, $windowsize, $commonality) = @ARGV;

my %granularities = (
	chapter => 1,
	verse   => 0,
);

my $fileinpath;
my $resultpath;

my $outputheader;
my $outputfileext;

my %time = ();
my %timenest = ();

sub dummy {
	1;
}

my %types = (
	json => {
		ext => 'json',
		type => 'application/json',
	},
	plain => {
		ext => 'txt',
		type => 'text/plain',
	},
	svg => {
		ext => 'svg',
		type => 'image/svg+xml',
	},
);

sub processsource {
	my $good = 1;

	printf STDERR "aligning %s to output type %s\n", $granularity, $outputtype;
	timestamp('align', 1);
	my ($thisgood, $atext) = align($fileinpath);
	print STDERR elapsed('align');
	if (!$thisgood) {
		$good = 0;
	}
	else {
		if (!open(A, ">:encoding(UTF-8)", $resultpath)) {
			print STDERR "Can't write to file [$resultpath]\n";
			return 0;
		}
		print A $atext;
		close A;
	}

	printf STDERR "Results written to [$resultpath]\n";
	return $good;
}

sub align {
	my ($file) = @_;
	my @curl = (
		$curl, '--silent',
		'-X', 'POST',
		'--header', 'Content-Type: application/json;charset=UTF-8;',
		'--header', sprintf('Accept: %s', $outputheader),
		'--data-binary', '@'.$file,
        $localserver
	);
	if (!(open(CURL, "-|:encoding(UTF-8)", @curl))) {
		return (0, '');
	}
	my @response = <CURL>;
	my $response = join '', @response;
	if (!close CURL) {
		return (0, $response);
	}
	return (1, $response);
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

	if (!exists $types{$outputtype}) {
		printf STDERR "Wrong outputtype [%s]. Should be one of (%s)\n", $outputtype, join(", ", sort(keys(%types)));
		$good = 0;
		next;
	}
	$outputheader = $types{$outputtype}->{type}; 
	$outputfileext = $types{$outputtype}->{ext}; 

	$fileinpath = sprintf "%s%s-max%d-win%d-comm%.1f.txt", $filein, $testrep, $maxiter, $windowsize, $commonality;
	$resultpath = sprintf "%s%s-max%d-win%d-comm%.1f.%s", $resultout, $testrep, $maxiter, $windowsize, $commonality, $outputfileext;

	if (!$granularities{$granularity}) {
		print STDERR "Unsupported granularity [$granularity].\nChoose one of ".join(", ", sort(keys(%granularities)))."\n";
		$good = 0;
	}
	return $good;
}

sub timestamp {
	my $mark = shift;
	my $nest = shift;
	@{$time{$mark}} = gettimeofday();
	$timenest{$mark} = $nest;
}

sub elapsed {
	my $mark = shift;
	my $elapsed = tv_interval($time{$mark});
	my $seconds = $elapsed;
	my $minutes;
	my $hours;
	if ($seconds > 60) {
		$seconds = int($seconds + 0.5);
		$minutes = int($seconds / 60);
		$seconds = $seconds % 60;
	}
	if ($minutes > 60) {
		$hours = int($minutes / 60);
		$minutes = $minutes % 60;
	}
	my $resultstring = '';
	if (defined $hours) {
		$resultstring .= sprintf "%d h", $hours;
	}
	if (defined $minutes) {
		$resultstring .= sprintf "%d m", $minutes;
	}
	if ($seconds == int($seconds)) {
		$resultstring .= sprintf "%d s", $seconds;
	}
	else {
		$resultstring .= sprintf "%.2f s", $seconds;
	}
	return
		('-' x 80)
	.	$mark
	.	('─' x (20 - length($mark)))
	.	('─' x (40 - $timenest{$mark} * 8))
	.	('─' x (10 - length($resultstring)))
	.	$resultstring
	.	"\n";
}

sub main {
	timestamp('program', 0);
	my $good = 1;
	for (1) {
		if (!initialize()) {
			$good = 0;
			next;
		}
		if (!processsource()) {
			$good = 0;
			next;
		}
	}
	print STDERR elapsed('program');
	return $good;
}

exit !main();
