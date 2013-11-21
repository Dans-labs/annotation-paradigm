#!/usr/bin/perl

=head2 test collations

testalign verse

=cut

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

use DBI;

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my $htmlfile = "../html/jude.html";
my $htmltemplate;

my ($thecollation_id) = @ARGV;

my %database = (
	db => 'jude',
	usr => 'root',
	pwd => 'dipre207',
);

my $fileoutname = sprintf "web-%d.html", $thecollation_id;
my $fileout = "../results/$fileoutname";

my $thecollation_name;

my %source_index = ();

my %material = ();
my %materialindex = ();
my %linkto = ();
my %linkfrom = ();

# parameters to write into the collation result

sub check_collation {
	printf STDERR "checking whether there is a collation with id = %d...\n", $thecollation_id;

	my $rows = sql(sprintf "select id, name from collation where id = %d;", $thecollation_id);
	if (!$rows) {
		return 0;
	}
	my $good = 1;
	while (my @row = &$rows()) {
		my ($id, $name) = @row;
		$thecollation_name = $name;
	}
	if (!defined $thecollation_name) {
		$good = 0;
	}
	if ($good) {
		printf STDERR "Collation with id %d exists and has name [%s]\n", $thecollation_id, $thecollation_name;
	}
	return $good;
}

sub get_words {
	print STDERR "retrieving the words of the chapter in all sources\n";
	my $rows = sql("
select
	glyphs, word_number, source_id
from
	word
where
	word_number > 0
;");
	if (!$rows) {
		return 0;
	}
	while (my @row = &$rows()) {
		my ($word, $num, $source) = @row;
		$material{$source}->[$num - 1] = $word;
	}
	printf STDERR "Number of sources = %d\n", scalar(keys(%material));
	return 1;
}

sub get_collation {
	printf STDERR "retrieving the collation of the chapter according to collation [%s]\n", $thecollation_name;
	my $rows = sql(sprintf "
select
	source_id, word_number_start, word_number_end, master_token
from
	collationdata
where
	collation_id = %d
order by
	source_id, word_number_start
;", $thecollation_id);
	if (!$rows) {
		return 0;
	}
	while (my @row = &$rows()) {
		my ($source, $numstart, $numend, $master) = @row;
		push @{$linkto{$source}}, [$master, $numstart - 1, $numend - 1];
		push @{$linkfrom{$master}}, [$source, $numstart - 1, $numend - 1];
	}
	printf STDERR "Number of mastertokens = %d\n", scalar(keys(%linkfrom));
	return 1;
}

sub writematerial {
	if (!open(HT, ">:encoding(UTF-8)", $fileout)) {
		print STDERR "Cannot write file [$fileout]\n";
		return 0;
	}
	my %htmldata = ();
	my $material = '';
	my $materialindex = '';
	my $msep = '';
	for my $source (sort keys %linkto) {
		$material .= sprintf "%s\"%d\" : [\n", $msep, $source;
		my $segments = $linkto{$source};
		my $sep = "\t";
		for my $segment (@$segments) {
			my ($master, $start, $end) = @$segment;
			my $words = join ' ', @{$material{$source}}[$start .. $end];
			if (exists $materialindex{$master}->{$source}) {
				print STDERR "Duplicate for master [$master] en source [$source]: was [$materialindex{$master}->{$source}] becomes [$words]\n";
			}
			$materialindex{$master}->{$source} = $words;
			$material .= sprintf "%s\"%s\"\n", $sep, $master;
			$sep = ",\t";
		}
		$material .= "]";
		$msep = ",\n";
	}
	$msep = '';
	for my $master (sort keys %materialindex) {
		$materialindex .= sprintf "%s\"%s\" : {\n", $msep, $master;
		my $sources = $materialindex{$master};
		my $sep = "\t";
		for my $source_id (sort {$a <=> $b} keys %$sources) {
			my $word = $sources->{$source_id};
			$materialindex .= sprintf "%s\"%s\" : \"%s\"\n", $sep, $source_id, $word;
			$sep = ",\t";
		}
		$materialindex .= "}";
		$msep = ",\n";
	}
	$htmldata{material} = $material;
	$htmldata{materialindex} = $materialindex;
	$htmltemplate =~ s/\$\{([^}]+)\}/$htmldata{$1}/sg;
	print HT $htmltemplate;
	close HT;
	print STDERR "html output written to $fileout\n";
	return 1;
}

sub index_table {
	my ($table, $index) = @_;
	print STDERR "reading the names in table $table and indexing them ...\n";

	my $rows = sql("select id, name from $table;");
	if (!$rows) {
		return 0;
	}
	my $good = 1;
	while (my @row = &$rows()) {
		my ($id, $name) = @row;
		if (exists $index->{$name}) {
			printf STDERR "Duplicate name in table $table [%s] at id [%d]\n", $name, $id;
			$good = 0;
		}
		else {
			$index->{$name} = $id;
		}
	}
	return $good;
}

sub readnames {
	my $good = 1;
	if (!index_table('source', \%source_index)) {
		$good = 0;
	}
	return $good;
}

# general query subroutine

sub sql {
	my $sql = shift;
	my $dbh = DBI->connect("DBI:mysql:$database{db}",$database{usr},$database{pwd});
	$dbh->{'mysql_enable_utf8'}=1;
	if (!$dbh) {
		print STDERR "Cannot connect to mysql database $database{db}\n";
		return 0;
	}
	my $sth = $dbh->prepare($sql);
	if (!$sth->execute) {
		print STDERR "Cannot execute query [$sql]\n";
		return 0;
	}
	return sub {
		my @row = $sth->fetchrow_array();
		return @row;
	};
}

sub get_html {
	if (!open(HT, "<:encoding(UTF-8)", $htmlfile)) {
		print STDERR "Cannot read file [$htmlfile]\n";
		return 0;
	}
	{local $/; $htmltemplate = <HT>;}
	close HT;
	return 1;
}

sub dummy {
	1;
}

sub main {
	my $good = 0;
	if (!readnames()) {
		$good = 0;
	}
	if (!check_collation()) {
		print STDERR "No such collation\n";
		$good = 0;
	}
	if (!get_words()) {
		print STDERR "Can not retrieve the words of this chapter\n";
		$good = 0;
	}
	if (!get_collation()) {
		print STDERR "Can not retrieve the collation of this chapter\n";
		$good = 0;
	}
	if (!get_html()) {
		print STDERR "Cannot get an HTML template\n";
		$good = 0;
	}
	if (!writematerial()) {
		print STDERR "Cannot write HTML to output\n";
		$good = 0;
	}
	return $good;
}

exit !main();
