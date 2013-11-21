#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my ($sql_template, $data_file, $sql_dump, $listing) = @ARGV;
my $chapsql = $sql_dump.'.chap';
my $verssql = $sql_dump.'.vers';

my $lhb = hex("05d0");
my $uhb = hex("05ea");

if (!open(S, "<:encoding(UTF-8)", $sql_template)) {
	print STDERR "Can't read file [$sql_template]\n";
	exit 1;
}
if (!open(FW, "<:encoding(UTF-8)", $data_file)) {
	print STDERR "Can't read file [$data_file]\n";
	exit 1;
}
if (!open(L, ">:encoding(UTF-8)", $listing)) {
	print STDERR "Can't write to file [$listing]\n";
	exit 1;
}
if (!open(G, ">:encoding(UTF-8)", $sql_dump)) {
	print STDERR "Can't write to file [$sql_dump]\n";
	exit 1;
}
if (!open(GC, ">:encoding(UTF-8)", $chapsql)) {
	print STDERR "Can't write to file [$chapsql]\n";
	exit 1;
}

if (!open(GV, ">:encoding(UTF-8)", $verssql)) {
	print STDERR "Can't write to file [$verssql]\n";
	exit 1;
}

my @lines = <S>;
close S;
my $create = join '', @lines;
$create =~ s/\$\{db\}/westm/sg;
print G $create;

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
	printf STDERR "%-20s %3d : %3d\t\r", $book_name, $chapter_num, $verse_num;
	my ($thisbook_acro, $thisbook_name) = $line =~ m/^B\t(...)\t(.*)/;
	if (defined $thisbook_acro) {
		$book_acro = $thisbook_acro;
		$book_name = $thisbook_name;
		$book_id = $bk_acro_id{$book_acro};
		if (!defined $book_id) {
			print STDERR "\nbook_id not found for [$book_acro] = [$book_name]\n";
		}
		printf G "insert into book (id, name) values (%d,'%s');\n", $book_id, $book_name;
		$chapter_num = 0;
		$verse_num = 0;
		next;
	}
	my ($thisverse, $thischapter, $text) = $line =~ m/^([0-9]+):([0-9]+)\t(.*)/;
	if (defined $thischapter) {
		if ($chapter_num != $thischapter) {
			$chapter_num = $thischapter;
			printf GC "insert into chapter (id, book_id, chapter_num) values (%d,%d,'%s');\n", ++$chapter_id, $book_id, $chapter_num;
			$verse_num = 0;
		}
		$verse_num = $thisverse;
		my $anchprefix = sprintf "%s_%03d:%03d^", $book_acro, $chapter_num, $verse_num;
		my ($rest, $wlimit, $thisword, $newrest);
		$rest = $text;
		my $resultline = '';
		my $word_num = 0;
		my $prevlimit = '';
		my @localanchors = ();
		while ($rest ne '') {
			my $setword = '';
			($thisword, $wlimit, $newrest) = $rest =~ m/^([^ \/־׃׀~]+)([ \/־׃׀~]*)(.*)$/s;
			my $sep = '';
			my $extra = '';
			if (!defined $thisword) {
				$thisword = '';
				$setword = '';
				$wlimit = '';
				$newrest = '';
			}
			else {
				$word_num++;
				$wlimit =~ s/׃\s+/׃/;
				my $anch = sprintf "%s%03d", $anchprefix, $word_num;
				push @localanchors, $anch;
				if ($prevlimit eq "/") {
					$sep = '';
				}
				elsif ($prevlimit eq "~") {
					$sep = '';
				}
				elsif ($prevlimit eq "׃") {
					$sep = $prevlimit . " " . $thisword;
				}
				else {
					$sep = $prevlimit;
				}

				if ($prevlimit eq "׃") {
					$setword = '';
				}
				else {
					$setword = "<w id=\"$anch\">$thisword</w>";
					for my $d (dediac($thisword)) {
						#printf L "%s\n", $d;
						printf L "%s\t%s\n", $anch, $d;
					}
				}
				$prevlimit = $wlimit;
			}
			$resultline .= $sep . $setword;
			$rest = $newrest;
		}
		$resultline .= $prevlimit;

		printf GV "insert into verse (id, chapter_id, verse_num, text) values (%d,%d,%d,'%s');\n", ++$verse_id, $chapter_id, $verse_num, $resultline;
		for my $anch (@localanchors) {
			printf GV "insert into word_verse (anchor, verse_id) values ('%s', %d);\n", $anch, $verse_id;
		}
		next;
	}
}
close FW;
printf STDERR "\nTotal %2d books; %4d chapters; %6d verses\n", $book_id, $chapter_id, $verse_id;
close GC;
close GV;

if (!open(GC, "<:encoding(UTF-8)", $chapsql)) {
	print STDERR "Can't read file [$chapsql]\n";
	exit 1;
}
print G "\n";
while ($line = <GC>) {
	print G $line;
}
close GC;
unlink $chapsql;

if (!open(GV, "<:encoding(UTF-8)", $verssql)) {
	print STDERR "Can't read file [$verssql]\n";
	exit 1;
}
print G "\n";
while ($line = <GV>) {
	print G $line;
}
close GV;
unlink $verssql;

close G;
close L;
