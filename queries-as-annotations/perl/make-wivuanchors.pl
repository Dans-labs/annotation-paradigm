#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my ($with_monads, $anchor_file) = @ARGV;

my $lhb = hex("05d0");
my $uhb = hex("05ea");

if (!open(FW, "<:encoding(UTF-8)", $with_monads)) {
	print STDERR "Can't read file [$with_monads]\n";
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
my $book_name = '';
my $chapter_id = 0;
my $chapter_num = 0;
my $verse_id = 0;
my $verse_num = 0;

while ($line = <FW>) {
	printf STDERR "%-20s %3d : %3d\t\r", $book_name, $chapter_num, $verse_num;
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
		printf A "%s %d:%d\t", $bk_id_acro{$book_id}, $chapter_num, $verse_num;
		next;
	}
	if ($line =~ m/<w /) {
		chomp $line;
		my (@words) = $line =~ m/(<w .*?<\/w>)/g;
		for my $word (@words) {
			my ($monadnum, $innerword) = $word =~ m/<w id="m([0-9]+)"[^>]*>([^<]*)</;
			if (length $innerword) {
				printf A "%s ", join('', dediac($innerword));
			}
		}
		print A "\n";
		next;
	}
}
close FW;
printf STDERR "\nTotal %2d books\n", $book_id;
close A;
