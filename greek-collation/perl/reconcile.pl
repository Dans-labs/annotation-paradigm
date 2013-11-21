#!/usr/bin/perl

=head2 idea

Collatex does not give refined output for sequences that are identical in normal form, but different in surface form.
This script takes the json output of collatex, identifies pieces with identical normal form, and
constructs a simple sub-collation of such pieces.
These subcollations only have to compare slices of tokens across witnesses.

=cut

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

use Data::Dump qw(dump);
use JSON;

my ($filein, $fileout) = @ARGV;

sub dummy {
	1;
}

sub main {
	my $good = 1;
	if (!open(AF, "<:encoding(UTF-8)", $filein)) {
		print STDERR "Can't read file [$filein]\n";
		return 0;
	}
	if (!open(A, ">:encoding(UTF-8)", $fileout)) {
		print STDERR "Can't write to file [$fileout]\n";
		return 0;
	}
	my $alignedtokens;
	{local $/; $alignedtokens = <AF>}
	close AF; 
	my $aligneddata = from_json($alignedtokens);
	my ($reconcileddata, $print) = reconcile($aligneddata);
	#my $reconciledtokens = to_json($reconcileddata, {canonical => 1, pretty => 1});
	#print A $reconciledtokens;
	print A $print;
	#print A dump($reconcileddata);
	close A;
}

sub reconcile {
	my $indata = shift;
	my @result = ();
	my $toprint = '';
	for my $pass (@$indata) {
		my ($matrix, $printresult) = reconcilepass($pass);
		push @result, $matrix;
		$toprint .= $printresult;
	}
	return (\@result, $toprint);
}

sub reconcilepass {
	my $passdata = shift;
	my $passname = $passdata->{verse};
	my $witnesses = $passdata->{alignment};
	my ($matrix, $toprint) = shufflewitnesses($witnesses);
	return ($matrix, $toprint);
}

sub shufflewitnesses {
	my $witnesses = shift;
	my @matrix = ();
	my $toprint = '';
	for my $witness (@$witnesses) {
		my $witnesslabel = $witness->{witness};
		$toprint .= sprintf "%4s:", $witnesslabel;
		my $tokens = $witness->{tokens};
		my $i = 0;
		for my $token (@$tokens) {
			$matrix[$i++]->{$witnesslabel} = $token;
			my $tokenrep;
			if (!defined $token) {
				$tokenrep = "▪";
			}
			else {
				$tokenrep = $token->{t};
			}
			$toprint .= $tokenrep;
		}
		$toprint .= "\n";
	}
	return (\@matrix, $toprint)
}

exit !main();

close A;
