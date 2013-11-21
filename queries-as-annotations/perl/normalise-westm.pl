#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my ($data_file, $ntext_file) = @ARGV;

if (!open(FW, "<:encoding(UTF-8)", $data_file)) {
	print STDERR "Can't read file [$data_file]\n";
	exit 1;
}
if (!open(G, ">:encoding(UTF-8)", $ntext_file)) {
	print STDERR "Can't write to file [$ntext_file]\n";
	exit 1;
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
my $chapter_num = 0;
my $verse_num = 0;

while ($line = <FW>) {
	chomp $line;
	printf STDERR "%-20s %3d : %3d\t\r", $book_name, $chapter_num, $verse_num;
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
		my $pass = sprintf "%s %d:%d", $book_acro, $chapter_num, $verse_num;
		$text =~ s/[\/~]//g;
		printf G "%s\t%s\n", $pass, $text;
	}
}

printf STDERR "\n";
close FW;
close G;
