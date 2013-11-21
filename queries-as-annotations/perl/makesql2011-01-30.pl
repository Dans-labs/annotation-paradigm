#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my ($with_monads, $sql_dump) = @ARGV;
my $tmpsql = $sql_dump.'.tmp';

if (!open(FW, "<:encoding(UTF-8)", $with_monads)) {
	print STDERR "Can't read file [$with_monads]\n";
	exit 1;
}
if (!open(G, ">:encoding(UTF-8)", $sql_dump)) {
	print STDERR "Can't write to file [$sql_dump]\n";
	exit 1;
}
if (!open(H, ">:encoding(UTF-8)", $tmpsql)) {
	print STDERR "Can't write to file [$tmpsql]\n";
	exit 1;
}

sub dummy {
	1;
}

print G "delete from verse;
delete from book;

";

my $line;
my %books = ();
my $book_name = '';
my $book = 0;
my $chapter = 0;
my $nchapter = 0;
my $verse = 0;
my $verse_id = 0;

while ($line = <FW>) {
	printf STDERR "%-20s %d : %d\t\r", $book_name, $chapter, $verse;
	if ($line =~ m/<book /) {
		($book_name) = $line =~ m/name="([^"]*)"/;
		$books{$book_name} = ++$book;
		printf G "insert into book (id, name) values (%d,'%s');\n", $book, $book_name;
		$chapter = 0;
		$verse = 0;
		next;
	}
	if ($line =~ m/<chapter /) {
		($chapter) = $line =~ m/name="([^"]*)"/;
		$nchapter++;
		$verse = 0;
		next;
	}
	if ($line =~ m/<verse /) {
		($verse) = $line =~ m/name="([^"]*)"/;
		next;
	}
	if ($line =~ m/<w /) {
		chomp $line;
		printf H "insert into verse (id, book_id, chapter_num, verse_num, text) values (%d,%d,%d,%d,'%s');\n", ++$verse_id, $book, $chapter, $verse, $line;
		next;
	}
}
printf STDERR "\nTotal %d books; %d chapters; %d verses\n", $book, $nchapter, $verse_id;
print G "\n";
close FW;
close H;

if (!open(H, "<:encoding(UTF-8)", $tmpsql)) {
	print STDERR "Can't read file [$tmpsql]\n";
	exit 1;
}
while ($line = <H>) {
	print G $line;
}
close H;
unlink $tmpsql;
close G;
