#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my ($data_file, $anchor_file) = @ARGV;

my $lhb = hex("05d0");
my $uhb = hex("05ea");

if (!open(FW, "<:encoding(UTF-8)", $data_file)) {
	print STDERR "Can't read file [$data_file]\n";
	exit 1;
}
if (!open(A, ">:encoding(UTF-8)", $anchor_file)) {
	print STDERR "Can't write to file [$anchor_file]\n";
	exit 1;
}

sub dediac {
	my $word = shift;
	my @chars = split //, $word;

	my @result = ();
	for my $ch (@chars) {
		my $o = ord($ch);
		if ($o < 255 or ($lhb <= $o and $o <= $uhb)) {
			push @result, $ch;
		}
	}
	return @result;
}

sub dummy {
	1;
}

my %bk_id_acro = (
	1	=> 'gen',
	2	=> 'exo',
	3	=> 'lev',
	4	=> 'num',
	5	=> 'deu',
	6	=> 'jos',
	7	=> 'jud',
	8	=> 'sa1',
	9	=> 'sa2',
	10	=> 'ki1',
	11	=> 'ki2',
	12	=> 'isa',
	13	=> 'jer',
	14	=> 'eze',
	15	=> 'hos',
	16	=> 'joe',
	17	=> 'amo',
	18	=> 'oba',
	19	=> 'jon',
	20	=> 'mic',
	21	=> 'nah',
	22	=> 'hab',
	23	=> 'zep',
	24	=> 'hag',
	25	=> 'zec',
	26	=> 'mal',
	27	=> 'psa',
	28	=> 'job',
	29	=> 'pro',
	30	=> 'rut',
	31	=> 'can',
	32	=> 'ecc',
	33	=> 'lam',
	34	=> 'est',
	35	=> 'dan',
	36	=> 'ezr',
	37	=> 'neh',
	38	=> 'ch1',
	39	=> 'ch2',
);

my %bk_acro_id = ();
for my $id (keys %bk_id_acro) {
	$bk_acro_id{$bk_id_acro{$id}} = $id;
};
printf STDERR "%d books\n", scalar(keys(%bk_acro_id));

my $line;
my $book_id = 0;
my $book_acro = '';
my $book_name = '';
my $chapter_id = 0;
my $chapter_num = 0;
my $verse_id = 0;
my $verse_num = 0;

while ($line = <FW>) {
	my ($thisbook_acro, $thisbook_name) = $line =~ m/^B\t(...)\t(.*)/;
	if (defined $thisbook_acro) {
		$book_acro = $thisbook_acro;
		$book_name = $thisbook_name;
		$book_id = $bk_acro_id{$book_acro};
		if (!defined $book_id) {
			print STDERR "\nbook_id not found for [$book_acro] = [$book_name]\n";
		}
		$chapter_num = 0;
		$verse_num = 0;
		next;
	}
	my ($thisverse, $thischapter, $text) = $line =~ m/^([0-9]+):([0-9]+)\t(.*)/;
	if (defined $thischapter) {
		if ($chapter_num != $thischapter) {
			$chapter_num = $thischapter;
			$verse_num = 0;
		}
		$verse_num = $thisverse;
		printf STDERR "%-20s %3d : %3d\t\r", $book_name, $chapter_num, $verse_num;
		printf A "%s %d:%d\t", $book_acro, $chapter_num, $verse_num;
		my ($rest, $wlimit, $thisword, $newrest);
		$rest = $text;
		my $resultline = '';
		my $prevlimit = '';
		while ($rest ne '') {
			($thisword, $wlimit, $newrest) = $rest =~ m/^([^ \/־׃׀~]+)([ \/־׃׀~]*)(.*)$/s;
			my $extra = '';
			if (!defined $thisword) {
				$thisword = '';
				$wlimit = '';
				$newrest = '';
			}
			else {
				$wlimit =~ s/׃\s+/׃/;
				if ($prevlimit ne "׃") {
					printf A "%s ", join('', dediac($thisword));
				}
				$prevlimit = $wlimit;
			}
			$rest = $newrest;
		}
		printf A "\n";
		next;
	}
}
close FW;
printf STDERR "\nTotal %2d books\n", $book_id;
close A;
