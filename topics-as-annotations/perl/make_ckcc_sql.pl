#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my $corpus_acro = 'huyg003';
my $corpus_name = 'Christiaan Huygens';
my $chunk_size = 15000;

my ($sql_template, $data_dir, $sql_dump, $id_map) = @ARGV;
my $lettersql = $sql_dump.'.lett';
my $chunksql = $sql_dump.'.chnk';

if (!open(S, "<:encoding(UTF-8)", $sql_template)) {
	print STDERR "Can't read file [$sql_template]\n";
	exit 1;
}
if (!open(G, ">:encoding(UTF-8)", $sql_dump)) {
	print STDERR "Can't write to file [$sql_dump]\n";
	exit 1;
}
if (!open(GL, ">:encoding(UTF-8)", $lettersql)) {
	print STDERR "Can't write to file [$lettersql]\n";
	exit 1;
}
if (!open(GC, ">:encoding(UTF-8)", $chunksql)) {
	print STDERR "Can't write to file [$chunksql]\n";
	exit 1;
}
if (!open(I, ">:encoding(UTF-8)", $id_map)) {
	print STDERR "Can't write to file [$id_map]\n";
	exit 1;
}

my @datafiles = glob("$data_dir/*.xml");
if (!scalar(@datafiles)) {
	print STDERR "No data found in [$data_dir]\n";
	exit 1;
}

my @lines = <S>;
close S;
my $create = join '', @lines;
$create =~ s/\$\{db\}/ckcc/sg;
print G $create;

sub dummy {
	1;
}

my $corpus_id = 0;
my $letter_id = 0;
my $chunk_id = 0;

printf G "insert into corpus (id, acro, name) values (%d,'%s','%s');\n", ++$corpus_id, $corpus_acro, $corpus_name;

my %m_ids = ();

for my $file (sort @datafiles) {
	my ($fname) = $file =~ m/([^\/]*)\.xml$/;
	printf STDERR "\r%-10s\t\t", $fname;
	if (!open(FW, "<:encoding(UTF-8)", $file)) {
		print STDERR "\nCan't read file [$file]\n";
	}
	my @lines = <FW>;
	close FW;
	my $text = join '', @lines;
	my ($meta) = $text =~ m/(<teiHeader.*?<\/teiHeader>)/s;
	my ($meta_id) = $meta =~ m/(<meta type="id".*?\/>)/s;
	my ($m_id) = $meta_id =~ m/value="([^"]*)"/s;
	my ($meta_lang) = $meta =~ m/(<meta type="language".*?\/>)/s;
	my ($m_lang) = $meta_lang =~ m/value="([^"]*)"/s;
	my ($meta_date) = $meta =~ m/(<meta type="date".*?\/>)/s;
	my ($m_date) = $meta_date =~ m/value="([^"]*)"/s;
	my ($meta_sender) = $meta =~ m/(<meta type="sender".*?\/>)/s;
	my ($m_sender) = $meta_sender =~ m/value="([^"]*)"/s;
	my ($meta_senderloc) = $meta =~ m/(<meta type="senderloc".*?\/>)/s;
	my ($m_senderloc) = $meta_senderloc =~ m/value="([^"]*)"/s;
	my ($meta_recipient) = $meta =~ m/(<meta type="recipient".*?\/>)/s;
	my ($m_recipient) = $meta_recipient =~ m/value="([^"]*)"/s;
	my ($meta_recipientloc) = $meta =~ m/(<meta type="recipientloc".*?\/>)/s;
	my ($m_recipientloc) = $meta_recipientloc =~ m/value="([^"]*)"/s;
	printf GL "insert into letter (id, corpus_id, m_id, m_lang, m_date, m_sender, m_senderloc, m_recipient, m_recipientloc) values (%d,%d,'%s','%s','%s','%s','%s','%s','%s');\n", ++$letter_id, $corpus_id, $m_id, $m_lang, $m_date, $m_sender, $m_senderloc, $m_recipient, $m_recipientloc;
	my ($body) = $text =~ m/<body>(.*?)<\/body>/s;
	$body =~ s/\r//sg;
	my $chunk_n = 0;
	for (my $i = 0; $i < length $body; $i += $chunk_size) {
		my $thischunk = substr $body, $i, $chunk_size;
		$thischunk =~ s/'/''/sg;
		printf GC "insert into contentchunk (id, letter_id, seq, content) values (%d,%d,%d,'%s');\n", ++$chunk_id, $letter_id, ++$chunk_n, $thischunk;
	}
    printf I "%s\t%s\n", $fname, $m_id;
    if (exists $m_ids{$m_id}) {
        printf STDERR "\nduplicate m_id [%s]\n", $m_id;
    }
    $m_ids{$m_id}++;
}

printf STDERR "\nTotal %2d corpora; %4d letters; %6d textchunks\n", $corpus_id, $letter_id, $chunk_id;
close GC;
close GL;

if (!open(GL, "<:encoding(UTF-8)", $lettersql)) {
	print STDERR "Can't read file [$lettersql]\n";
	exit 1;
}
print G "\n";
my $line;

while ($line = <GL>) {
	print G $line;
}
close GL;
unlink $lettersql;

if (!open(GC, "<:encoding(UTF-8)", $chunksql)) {
	print STDERR "Can't read file [$chunksql]\n";
	exit 1;
}
print G "\n";
while ($line = <GC>) {
	print G $line;
}
close GC;
unlink $chunksql;

close G;
close I;
