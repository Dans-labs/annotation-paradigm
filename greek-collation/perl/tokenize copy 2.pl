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

my ($input, $result, $bychar, $selectedverse) = @ARGV;
my $extra = '"algorithm": "dekker", "tokenComparator": {"type": "equality" }';

my %sources = ();

sub readsource {
	print STDERR "reading the sources ...\n";
	if (!open(INF, "<:encoding(UTF-8)", $input)) {
		print STDERR "Cannot read file [$input]\n";
		return 0;
	}
	my $cursource;
	my $nsources = 0;
	my $sourceverses = 0;
	while (my $line = <INF>) {
		chomp $line;
		if (substr($line, 0, 1) eq '!') {
			my @fields = split /\t/, $line;
			$cursource = $fields[1];
			$nsources++;
			printf STDERR "\r\t%d (%d): %s          ", $nsources, $sourceverses, $cursource;
			next;
		}
		my ($verse, $versetext) = $line =~ m/^([0-9]+)\tSRC=(.*)$/;
		if (!defined $verse) {
			next;
		}
		if (!defined $selectedverse or $selectedverse eq $verse) {
			if (exists $sources{$verse}->{$cursource}) {
				print STDERR "Duplicate verse $verse in $cursource\n";
			}
			$sources{$verse}->{$cursource} = $versetext;
			$sourceverses++;
		}
	}
	close INF;
	printf STDERR "\nnumber of sources: %d\n", $nsources; 
	printf STDERR "number of source verses: %d\n", $sourceverses; 
}

sub splitchars {
	my $text = shift;
	return join ", ", map {"{\"t\":\"$_\"}"} split //, $text;
}

sub gentokens {
	print STDERR "writing the tokens ...\n";
	my $sourceverses = 0;
	my $good = 1;
	for my $verse (sort {$a <=> $b} keys %sources) {
		my $resultfile = $result."-verse-$verse.txt";
		if (!open(TF, ">:encoding(UTF-8)", $resultfile)) {
			print STDERR "Cannot write file [$resultfile]\n";
			$good = 0;
			next;
		}
		print TF "{\"witnesses\" : [\n";
		my $thissources = $sources{$verse};
		my $sep = "";
		for my $thissource (sort keys %$thissources) {
			$sourceverses++;
			#printf TF "$sep\t{\"id\" : \"%s\", \"content\" : \"%s\"}\n", $thissource, $thissources->{$thissource};
			if (length $thissources->{$thissource}) {
				if ($bychar) {
					printf TF "$sep\t{\"id\" : \"%s\", \"tokens\" : [%s]}\n", $thissource, splitchars($thissources->{$thissource});
				}
				else {
					printf TF "$sep\t{\"id\" : \"%s\", \"content\" : \"%s\"}\n", $thissource, $thissources->{$thissource};
				}
			}
			$sep = ',';
			printf STDERR "\r\t%d    ", $sourceverses;
		}
		print TF "], $extra}\n";
		close TF;
	}
	printf STDERR "\nnumber of source verses: %d\n", $sourceverses;
	return $good;
}

if (!readsource()) {
	exit 1;
}

if (!gentokens()) {
	exit 1;
}
