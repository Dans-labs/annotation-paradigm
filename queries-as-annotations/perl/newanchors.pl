#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my ($alignment, $newanchors) = @ARGV;

if (!open(A, "<:encoding(UTF-8)", $alignment)) {
	print STDERR "Can't read file [$alignment]\n";
	exit 1;
}
if (!open(AA, ">:encoding(UTF-8)", $newanchors)) {
	print STDERR "Can't write to file [$newanchors]\n";
	exit 1;
}

sub dummy {
	1;
}

print STDERR "computing anchors ...\n";

while (my $line = <A>) {
	chomp $line;
	my ($pass, $text) = split /\t/, $line, 2;
	print STDERR "\r$pass\t\t";
	my ($item, $rest);
	$rest = $text;
	my $va = '';
	my $vb = '';
	my $n = 0;
	while (length $rest) {
		my ($ait, $bit, $newrest) = $rest =~ m/^\(([^|]*)\|([^)]*)\)(.*)$/;
		if (defined $ait) {
			my $aitem = '';
			my $bitem = '';
			if (length $ait) {
				$aitem = sprintf "%d%s", ++$n, $ait;
			}
			if (length $bit) {
				$bitem = sprintf "%d%s", ++$n, $bit;
			}
			$va .= $aitem;
			$vb .= $bitem;
			$rest = $newrest;
			next;
		}
		my ($uit, $newrest) = $rest =~ m/^((?:(?: +)|(?:[^ (|)]+)))(.*)$/;
		if (defined $uit) {
			my $uitem = sprintf "%d%s", ++$n, $uit;
			$va .= $uitem;
			$vb .= $uitem;
			$rest = $newrest;
			next;
		}
	}
	printf AA "%s\n%s\n%s\n\n", $pass, $va, $vb;
}

print STDERR "\n";

close AA;
close A;
