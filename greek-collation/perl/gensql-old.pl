#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my $workdir = "/Users/dirk/Data/DANS/demos/apps/pa/datatrans/TommyWasserman/Transkriptioner_kopior";
my $destdir = "/Users/dirk/Data/DANS/demos/apps/pa/sql";
my $modeldir = "/Users/dirk/Data/DANS/demos/apps/pa/models";
my $sqlfile = "$modeldir/tradition_create.sql";
my $resultfile1 = "$destdir/wasserman.sql";
my $resultfile2 = "$destdir/wassermanlayerdata.sql";

my @table_order = (
	['item', 2, {0=>1, 1=>1}],
	['passage', 3, {0=>1, 1=>1, 2=>1}],
	['layer', 4, {0=>1, 1=>1, 2=>1, 3=>1}],
	['data_type', 1, {0=>1}],
	['data_object', 3, {}],
	['layerdata', 9, {6=>1}],
);

my %book_legend = (
	26 => 'Jude',
);

my $fmt_stat = "%-20s: %4d [%s]\n";

my %stats = ();
my %witness = ();
my $witness;

my %records = ();
my %ids = ();
my %passage_index = ();

sub dodir {
	my $path = shift;
	if (!opendir(WD, $path)) {
		print STDERR "\nCannot read directory $path\n";
		return;
	}
	my @items = readdir WD;
	closedir WD;
	for my $item (@items) {
		if ($item eq '.' or $item eq '..' or substr($item, 0, 1) eq '.') {
			next;
		}
		my $ext;
		($witness, $ext) = $item =~ m/^(.*)\.([^.]*)$/;
		if ($ext eq 'txt') {
			if (-f "$path/$item") {
				print STDERR "\r\t$witness                   ";
				getinfo("$path/$item", $witness);
			}
		}
		elsif ($ext eq '') {
			if (-d "$path/$item") {
				printf STDERR "\n$path/$item\n";
				dodir("$path/$item");
			}
		}
	}

}

sub init_db {
	my ($fileout) = @_;
	define_layer();
	if (!open(F2, ">:encoding(UTF-8)", $fileout)) {
		print STDERR "\ncannot read $fileout\n";
		return;
	}
	print F2 "use tradition;\n";
}

sub define_layer {
	$records{layer}->{++$ids{layer}} = [
	'transcription',
	'Tommy Wasserman',
	'Jan Krans, Juan Garcés, Matthew Munson, Dirk Roorda',
	'The information is this layer consists of the position of each transcribed character in each manuscript transcribed by Tommy Wasserman.
Additional information that can be found in these transcriptions has been left out.
That information can be found in other layers.
',
	]; 
}

sub getinfo {
	my ($filein, $item) = @_;

	if (!open(F, "<:encoding(UTF-8)", $filein)) {
		print STDERR "\ncannot read $filein\n";
		return;
	}
	witness_stat('TOTALS', '# of witnesses');

	my $text;
	{local $/; $text = <F>}
	close F;

	witness_stat('TOTALS', 'KB in witnesses', length($text)/1024);

	my ($pre, $post) = $text =~ m/^(.*?)(<V\s+.*)$/s;
	if (!defined $pre) {
		witness_stat('TOTALS', '# of skipped witnesses');
		return;
	}
	my $good = 1;
	my (@books) = $pre =~ m/<B\s+([0-9]+)>/sg;
	my (@chapters) = $pre =~ m/<K\s+([0-9]+)>/sg;
	if (!scalar @books) {
		witness_stat('MISSING BOOK', $item);
		$good = 0;
	}
	if (!scalar @chapters) {
		witness_stat('MISSING CHAPTER', $item);
		$good = 0;
	}
	if (scalar(@books) > 1) {
		witness_stat('MULTIPLE BOOKS', $item);
		$good = 0;
	}
	if (scalar(@chapters) > 1) {
		witness_stat('MULTIPLE CHAPTERS', $item);
		$good = 0;
	}
	$pre =~ s/<B\s+([0-9]+)>//sg;
	$pre =~ s/<K\s+([0-9]+)>//sg;
	if ($pre !~ m/^[\s\n]*/s) {
		witness_stat('EXTRA PREFIX MATERIAL', $item);
		$good = 0;
	}
	my $book = $book_legend{$books[0]};
	if (!defined $book) {
		witness_stat('STRANGE BOOK', $item);
		$good = 0;
	}
	my $chapter = $chapters[0];
	if ($post !~ m/<V\s+[0-9]/) {
		witness_stat('NO VERSE MATERIAL', $item);
		$good = 0;
	}
	if (!$good) {
		return;
	}
	my @verses = ();
	while ($post ne '') {
		my ($verseref, $versetext, $rest) = $post =~ m/^<V\s+([0-9]+)\s*>(.*?)((?:<V\s+[0-9]+\s*>.*)|\z)/s;
		if (!defined $verseref) {
			witness_stat('STRANGE VERSE MATERIAL', $item);
			last;
		}
		push @verses, [$verseref, $versetext];
		$post = $rest;
	}
	$records{item}->{++$ids{item}} = [$item, 'Tommy Wasserman']; 
	for my $verse (@verses) {
		my ($vref, $vtext) = @$verse;
		my $passage = sprintf "%s %d:%d", $book, $chapter, $vref;
		printf F2 "\n-- %-10s %s\n", $item, $passage;
		my $cur_passage = $passage_index{$passage};
		if (!defined $cur_passage) {
			$records{passage}->{++$ids{passage}} = [$book, $chapter, $vref];
			$passage_index{$passage} = $ids{passage};
			$cur_passage = $passage_index{$passage};
		}
		$vtext =~ s/^\s+//s;
		chomp $vtext;
		my $i = 0;
		$vtext =~ s/<[^>]*>//sg;
		my %thisrecords = ();
		for my $vch (split //, $vtext) {
			$thisrecords{layerdata}->{++$ids{layerdata}} = [
				++$i,
				1,
				$ids{item},
				$cur_passage,
				'null',
				'null',
				$vch,
				'null',
				3,
			]; 
		}
		print F2 write_table(\%thisrecords, $table_order[5]);
	}
}

sub gensql {
	my ($tablerecords, $fileout1) = @_;
	if (!open(F, "<:encoding(UTF-8)", $sqlfile)) {
		print STDERR "\ncannot read $sqlfile\n";
		return;
	}
	my $sqltext;
	{local $/; $sqltext = <F>}
	close F;

	if (!open(F1, ">:encoding(UTF-8)", $fileout1)) {
		print STDERR "\ncannot write $fileout1\n";
		return;
	}
	print F1 $sqltext;
	for my $tablespec (@table_order) {
		print F1 write_table($tablerecords, $tablespec);
	}
	close F1;
}

sub write_table {
	my ($tablerecords, $tablespec) = @_;
	my ($table, $nfields, $quotefields) = @$tablespec;
	if (!exists $tablerecords->{$table}) {
		return '';
	}
	my $result = sprintf "insert into %s values\n", $table;
	my $sep = ' ';
	my $thisrecords = $tablerecords->{$table};
	for my $id (sort {$a <=> $b} keys %$thisrecords) {
		$result .= sprintf "\t$sep(%d", $id;
		for (my $i = 0; $i < $nfields; $i++) {
			my $f = $thisrecords->{$id}->[$i];
			if ($quotefields->{$i}) {
				$f =~ s/'/''/g;
				$f = "'$f'";
			}
			$result .= ",$f";
		}
		$result .= ")\n";
		$sep = ',';
	}
	$result .= ";\n";
	return $result;
}

sub witness_stat {
	my ($stat, $substat, $increment) = @_;
	if (!defined $increment) {
		$increment = 1;
	}
	$stats{$stat}->{$substat} += $increment;
	if (!exists $witness{$stat}) {
		$witness{$stat} = {};
	}
	if (!exists $witness{$stat}->{$substat}) {
		$witness{$stat}->{$substat} = $witness;
	}
}

sub dummy {
	1;
}

sub messages {
	print STDERR "\n";

	for my $stat (sort keys %stats) {
		print STDERR "\n$stat\n";
		my $substats = $stats{$stat};
		for my $substat (sort keys %$substats) {
			printf $fmt_stat, $substat, $substats->{$substat}, $witness{$stat}->{$substat};
		}
	}
}

sub main {
	init_db($resultfile2);
	mkdir $destdir;
	dodir($workdir);
	close F2;
	gensql(\%records, $resultfile1);
	messages();
}

main();
