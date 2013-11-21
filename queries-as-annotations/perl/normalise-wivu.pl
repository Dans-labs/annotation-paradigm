#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my ($with_monads, $ntext_file) = @ARGV;

if (!open(FW, "<:encoding(UTF-8)", $with_monads)) {
	print STDERR "Can't read file [$with_monads]\n";
	exit 1;
}
if (!open(G, ">:encoding(UTF-8)", $ntext_file)) {
	print STDERR "Can't write to file [$ntext_file]\n";
	exit 1;
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
my $book_name = '';
my $chapter_id = 0;
my $chapter_num = 0;
my $verse_id = 0;
my $verse_num = 0;
my $word_num = 0;

while ($line = <FW>) {
	if ($line =~ m/<book /) {
		($book_name) = $line =~ m/name="([^"]*)"/;
		$book_id++;
		$chapter_num = 0;
		$verse_num = 0;
		next;
	}
	if ($line =~ m/<chapter /) {
		($chapter_num) = $line =~ m/name="([^"]*)"/;
		$verse_num = 0;
		next;
	}
	if ($line =~ m/<verse /) {
		($verse_num) = $line =~ m/name="([^"]*)"/;
		next;
	}
	if ($line =~ m/<w /) {
		chomp $line;
		my $pass = sprintf "%s %d:%d", $bk_id_acro{$book_id}, $chapter_num, $verse_num;
		print G "$pass\t";
		print STDERR "\r$pass\t\t";
		$line =~ s/<\/?w[^>]*>//g;
		print G "$line\n";
	}
}
print STDERR "\n";
close FW;
close G;
