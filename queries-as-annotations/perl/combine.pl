#!/usr/bin/perl

=head2 USAGE

combine.pl verse_file_in word_file_in xml_file_out option_with_monads option_reverse

verse_file_in: a file that lists all verses with first and last monad
word_file_in: a file that lists all words in Hebrew with monad number plus indication whether it is a prefix
option_with_monads: if 1 then each word is packaged in an element with the monad number in an attribute
option_reverse: if 1 then the words are reversed, per verse

=cut

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my ($versefilein, $wordfilein, $fileout) = @ARGV;
my @curwords = ();

if (!open(FV, "<:encoding(UTF-8)", $versefilein)) {
	print STDERR "Can't read file [$versefilein]";
	exit 1;
}
if (!open(FW, "<:encoding(UTF-8)", $wordfilein)) {
	print STDERR "Can't read file [$wordfilein]";
	exit 1;
}
if (!open(G, ">:encoding(UTF-8)", $fileout)) {
	print STDERR "Can't write to file [$fileout]";
	exit 1;
}

my %verses = ();
my %verseindex = ();

sub dummy {
	1;
}

sub flush_words {
	if (scalar @curwords) {
		for my $i (0 .. $#curwords) {
			my ($monad, $word, $isprefix, $extra) = @{$curwords[$i]};
			my $space = ' ';
			my $postfix = '';
			if ($isprefix eq '-') {
				$space = '';
			}
			elsif ($isprefix eq '&') {
				$space = '';
				$postfix = '־';
			}
			elsif ($isprefix eq '00') {
				$space = '';
				$postfix = '׃ ';
			}

			my ($realword, $bar) = $word =~ m/^(.*)(׀)$/;
			if (defined $realword) {
				$word = $realword;
				$postfix = " "."׀";
			}
			print G "<w id=\"m$monad\">$word</w>$postfix$space$extra";
		}
		@curwords = ();
	}
}

my $n;

$n = 0;
while (my $line = <FV>) {
	$n++;
	if ($n % 1000 == 0) {
		printf STDERR "%6s\t\tverses\r", $n;
	}
	chomp $line;
	my ($monadfirst, $monadlast, $book, $chapter, $verse) = split /\t/, $line;
	$verses{$book}->{$chapter}->{$verse} = [$monadfirst, $monadlast];
	for my $v ($monadfirst .. $monadlast) {
		$verseindex{$v} = [$book, $chapter, $verse];
	}
}

printf STDERR "%6s\t\tverses\n", $n;

dummy();

print G '<?xml version="1.0" encoding="UTF-8"?>', "\n<books>\n";

$n = 0;
my ($curbook, $curchapter, $curverse);

while (my $line = <FW>) {
	$n++;
	if ($n % 1000 == 0) {
		printf STDERR "%6d\t\twords\r", $n;
	}
	chomp $line;
	my ($monad, $word, $isprefix, $extra) = split /\t/, $line;
	my ($thisbook, $thischapter, $thisverse) = @{$verseindex{$monad}};
	if ($thisbook ne $curbook) {
		flush_words();
		if (defined $curbook) {
			print G "\n\t\t</verse>\n\t</chapter>\n</book>\n";
		}
		$curbook = $thisbook;
		$curchapter = $thischapter;
		$curverse = $thisverse;
		print G "<book name=\"$curbook\">\n\t<chapter name=\"$curchapter\">\n\t\t<verse name=\"$curverse\">\n";
	}
	elsif ($thischapter ne $curchapter) {
		flush_words();
		$curchapter = $thischapter;
		$curverse = $thisverse;
		print G "\n\t\t</verse>\n\t</chapter>\n\t<chapter name=\"$curchapter\">\n\t\t<verse name=\"$curverse\">\n";
	}
	elsif ($thisverse ne $curverse) {
		flush_words();
		$curverse = $thisverse;
		print G "\n\t\t</verse>\n\t\t<verse name=\"$curverse\">\n";
	}
	push @curwords, [$monad, $word, $isprefix, $extra];
}
flush_words();
print G "\n\t\t</verse>\n\t</chapter>\n</book>\n</books>\n";

printf STDERR "%6d\t\twords\n", $n;

close FW;
close FV;
close G;
