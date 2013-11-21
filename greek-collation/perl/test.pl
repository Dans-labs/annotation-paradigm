#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

use DBI;

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my ($maxiter, $windowsize, $commonality) = @ARGV;

my %database = (
	db => 'jude',
	usr => 'root',
	pwd => 'dipre207',
);

my %collationinfo = (
	id => undef,
	name => 'pre + collatex + post',
	author => 'Ronald Dekker, Gregor Middell, Dirk Roorda',
	version => '1.3',
	algorithm => 'context analysis, collatex, result table construction',
	parameters => sprintf("Context analysis: %s = %d; %s = %d; %s = %.1f",
		'max iterations', $maxiter,
		'context window size', $windowsize,
		'commonality threshold', $commonality
	),
	description => 'Before collatex the input is preprocessed to identify variations of "same" words by context analysis.
Same words are replaced by group numbers like #123, #456 etc.
The result is passed to CollateX, as plain strings, without tokenization.
The graph output of CollateX is used (plain), to construct the collation table.
Basically, the names nodes of the graphs are used as decorators of the word ranges that occur as labels on them.
Word ranges in different sources with the same decoration are counted as corresponding passages.
However, some nodes in the result graph are linked by extra edges. This gives rise to classes of nodes that are connected by paths of such edges.
If a node belongs to such a class, we decorate with the class number instead of the node name.
However, some classes are not consistently labeled with the same material in every source.
But even then we will decorate the corresponding word ranges with that class.
',
);

sub makecollationrecord {

	print STDERR "looking for\n=====$collationinfo{parameters}\n=====\n";

	my @existingids = ();
	my $rows;
	$rows = sql("
select
	id
from
	collation
where
	parameters = '$collationinfo{parameters}'
;");
	if (!$rows) {
		return undef;
	}

	while (my @row = &$rows()) {
		my ($id) = @row;
		push @existingids, $id;
	}

	printf STDERR "Found %d collation records\n", scalar(@existingids);

	printf STDERR "Deleting old collation records and associated collations\n";
	if (scalar(@existingids)) {
		sql(sprintf "
delete from collationdata where collation_id in (%s);
", join(',', @existingids));
		sql(sprintf "
delete from collation where id in (%s);
", join(',', @existingids));
	}

	printf STDERR "Inserting new collation record\n";
	sql("
insert into collation (
	name,
	author,
	version,
	algorithm,
	parameters,
	description
) values (
	'$collationinfo{name}',
	'$collationinfo{author}',
	'$collationinfo{version}',
	'$collationinfo{algorithm}',
	'$collationinfo{parameters}',
	'$collationinfo{description}'
);
");

	$rows = sql("
select
	id
from
	collation
where
	parameters = '$collationinfo{parameters}'
;");
	if (!$rows) {
		return undef;
	}

	my @row = &$rows();
	my ($id) = @row;

	return $id;
}

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

my $id = makecollationrecord();

print STDERR "ID=$id\n";
