#!/usr/bin/perl

=head2 idea

Use collatex

=cut

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

use Unicode::Normalize;

my ($result, @sources) = @ARGV;

my @greek_letter = (
	hex("0345"),				# iota subscriptum
	hex("037A"),				# iota subscriptum
	hex("1FBE"),				# iota adscriptum
	hex("0391") .. hex("03A9"), # capitals 
	hex("03B1") .. hex("03C9"), # lower case 
	hex("1D26") .. hex("1D2A"), # small capitals
	hex("1D5D") .. hex("1D61"), # superscripts
	hex("1D66") .. hex("1D6A"), # subscripts
);
my @combining_accent = (
	hex("0301") .. hex("0362"),		# not necessarily greek accents. Some of them are used for greek, especially after UNICODE decomposition
);
my @greek_accent = (
	hex("0340") .. hex("0344"),
	hex("0384") .. hex("0385"),
	hex("1FBF") .. hex("1FC1"),
	hex("1FCD") .. hex("1FCF"),
	hex("1FDD") .. hex("1FDF"),
	hex("1FED") .. hex("1FEF"),
	hex("1FFD") .. hex("1FFE"),
);
my @greek_letter_accent = (
	hex("0386"),				# 
	hex("0388") .. hex("0390"), # 
	hex("03AA") .. hex("03B0"), # 
	hex("03CA") .. hex("03CE"), # 
	hex("1F00") .. hex("1FBC"), # 
	hex("1FC2") .. hex("1FCC"), # 
	hex("1FD0") .. hex("1FDB"), # 
	hex("1FE0") .. hex("1FEC"), # 
	hex("1FF2") .. hex("1FFC"), # 
);
my @greek_punct = (
	hex("037E"),				# question mark
	hex("0387"),				# ano teleia
);
my @greek_varia = (
	hex("0370") .. hex("0377"), # eta's, sampi's, numeral signs, digamma
	hex("037B") .. hex("037D"), # editorial symbols: lunates
	hex("03CF") .. hex("03D7"),	# symbols
	hex("03D8") .. hex("03E1"),	# koppa, stigma, digamma, sampi
	hex("03E2") .. hex("03EF"),	# coptic
	hex("03F0") .. hex("03F6"),	# symbols among which the yot
	hex("03F7") .. hex("03F9"),	# for bactrian
	hex("03FA") .. hex("03FC"),	# archaic
	hex("03FD") .. hex("03FF"),	# editorial
	hex("1FBD"), 				# koronis
);

my %greek_letter = ();
my %greek_accent = ();
my %greek_letter_accent = ();
my %greek_punct = ();
my %greek_varia = ();

for my $g (@greek_letter) {
	$greek_letter{$g} = 1;
}
for my $g (@greek_accent, @combining_accent) {
	$greek_accent{$g} = 1;
}
for my $g (@greek_letter_accent) {
	$greek_letter_accent{$g} = 1;
}
for my $g (@greek_punct) {
	$greek_punct{$g} = 1;
}
for my $g (@greek_varia) {
	$greek_varia{$g} = 1;
}

sub dummy {
	1;
}

sub gchunk {
	my ($gstr) = @_;
	my (@gchars) = split //, $gstr;
	my @result = ();
	my $chunk = '';
	for my $gc (@gchars) {
		my $go = ord($gc);
		if ($greek_accent{$go}) {
			$chunk .= $gc;
			next;
		}
		if (length $chunk) {
			push @result, $chunk;
		}
		$chunk = $gc;
	}
	if (length $chunk) {
		push @result, $chunk;
	}
	return \@result;
}

my %anchors = ();
my %tokenized = ();

sub passsort {
	my ($bka, $cha, $vsa) = $a =~ m/^(...) ([^:]+):(.*)/;
	my ($bkb, $chb, $vsb) = $b =~ m/^(...) ([^:]+):(.*)/;
	if ($bka eq $bkb) {
		if ($cha == $chb) {
			return $vsa <=> $vsb;
		}
		return $cha <=> $chb;
	}
	return $bka <=> $bkb;
}

sub readsource {
	my ($file, $key) = @_;
	if (!open(AF, "<:encoding(UTF-8)", $file)) {
		print STDERR "Can't read file [$file]\n";
		return 0;
	}
	print STDERR " $key";
	my $curpass = undef;
	while (my $line = <AF>) {
		chomp $line;
		if ($line =~ m/^\s*$/) {
			$anchors{$curpass}->{$key} .= "§";
			next;
		}
		my ($xkey, $pass, $text);
		($xkey, $pass, $text) = $line =~ m/^﻿?([^§]*)§([A-Za-z]+\s+[0-9]+:[0-9]+)\s+(.*)/;
		if (!defined $xkey) {
			$xkey = $key;
			($pass, $text) = $line =~ m/^﻿?([A-Za-z]+\s+[0-9]+:[0-9]+)\s+(.*)/;
		}
		if (defined $pass) {
			$curpass = $pass;
			$anchors{$pass}->{$xkey} = NFD($text);
			next;
		}
		print STDERR "Unparsed line in [%s]: [%s]\n", $key, $line;
	}
	close AF;
}

sub readsources {
	print STDERR "reading ...";
	for my $source (@sources) {
		my ($sourcekey) = $source =~ m/^([^_]*)_(.*)\.txt/;
		if (!readsource($source, $sourcekey)) {
			return 0;
		}
	}
	print STDERR "\n";
}

sub tokenize {
	print STDERR "tokenizing ...\n";

	for my $pass (sort passsort keys %anchors) {
		print STDERR "\r\t$pass ...\t\t";
		my $info = $anchors{$pass};
		dummy();
		for my $wn (sort keys %$info) {
			$tokenized{$pass}->{$wn} = gchunk($info->{$wn});
		}
	}
	print STDERR "\n";
	return 1;
}

sub serialize {
	print STDERR "serializing ...\n";

	if (!open(A, ">:encoding(UTF-8)", $result)) {
		print STDERR "Can't write to file [$result]\n";
		exit 1;
	}

	for my $pass (sort passsort keys %tokenized) {
		print STDERR "\r\t$pass ...\t\t";
		printf A "=====%s=====\n{\n\t\"witnesses\" : [", $pass;
		my $witnesses = $tokenized{$pass};
		my $wfirst = 1;
		my $wsep = '';
		for my $wn (sort keys %$witnesses) {
			printf A "%s\n\t{\n\t\t\"id\": \"%s\",\n\t\t\"tokens\": [", $wsep, $wn;
			my $chunks = $witnesses->{$wn};
			my $ffirst = 1;
			my $fsep = '';
			for my $chunk (@$chunks) {
				printf A "%s\n\t\t\t{\"t\": \"%s\"", $fsep, $chunk;
				if (length($chunk) > 1) {
					printf A ", \"n\": \"%s\"", substr($chunk, 0, 1);
				}
				printf A "}";
				if ($ffirst) {
					$fsep = ',';
					$ffirst = 0;
				}
			}
			print A "\t\t]\n\t}";
			if ($wfirst) {
				$wsep = ',';
				$wfirst = 0;
			}
		}
		printf A "\t]\n}\n";
	}
	close A;
	printf STDERR "\nResults written to [$result]\n";
	return 1;
}

sub main {
	if (!readsources()) {
		return 0;
	}
	if (!tokenize()) {
		return 0;
	}
	if (!serialize()) {
		return 0;
	}
}

exit !main();

close A;
