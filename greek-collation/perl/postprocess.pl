#!/usr/bin/perl

=head2 idea

Use collatex

=cut

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";
use Time::HiRes qw (gettimeofday time tv_interval);

use DBI;

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my ($test, $verbose, $filein, $indexin, $resultout, $granularity, $maxiter, $windowsize, $commonality) = @ARGV;

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

my %textfields = (
	collationdata => [0, 0, 0, 0, 1],
);
my %fieldnames = (
	collationdata => ['collation_id', 'source_id', 'word_number_start', 'word_number_end', 'master_token'],
);

my %granularities = (
	chapter => 1,
	verse   => 0,
);

my $fileinpath;
my $resultpath;
my $infopath;
my $indexinpath;

my %time = ();
my %timenest = ();

sub dummy {
	1;
}

my $input;
my $info;

my %nodelabel = ();
my %edgesin = ();
my %edgesout = ();
my %ledgesout = ();
my %tedgesin = ();
my %nodeclass = ();
my %classnode = ();
my %classerrors = ();
my %classlabel = ();
my %indexsource = ();
my %records = ();
my @nlinks = ();
my $duplicatenodes = 0;
my $nedges = 0;
my $nsourceedges = 0;
my $ncedges = 0;

my %grid = ();

sub processsource {
	my $good = 1;

	if (!open(A, "<:encoding(UTF-8)", $fileinpath)) {
		print STDERR "Can't read file [$fileinpath]\n";
		return 0;
	}
	print STDERR "Reading alignment ... \n";
	timestamp('read alignment', 1);
	$input = undef;
	{local $/; $input = <A>};
	close A;
	print STDERR elapsed('read alignment');

	return 1;
}

sub readindex {
	print STDERR "Reading index with source identifiers\n";
	my $good = 1;
	my $filein = sprintf $indexinpath, 'source'; 
	if (!open(II, "<:encoding(UTF-8)", $filein)) {
		print STDERR "Can't read file [$filein]\n";
		$good = 0;
		next;
	}
	%indexsource = ();
	while (my $line = <II>) {
		chomp $line;
		my ($name, $id) = split /\t/, $line;
		$indexsource{$name} = $id;
	}
	close II;
	return $good;
}

sub creategraph {
	my $good = 1;
	my $thisgood = 1;
	my @lines = split /\n/, $input;

	print STDERR "\treading input ... ";
	for my $line (@lines) {
		my ($node, $node1, $node2, $label, $sources);

#	nodes
#  	v13858 [label = "ιουδας"];

		($node, $label) = $line =~ m/^\s*(\S+)\s*\[label\s*=\s*"(.*)"\];\s*$/;
		if (defined $node) {
			if (exists $nodelabel{$node}) {
				$duplicatenodes++;
			}
			$label =~ s/^\s+//s;
			$label =~ s/\s+$//s;
			$nodelabel{$node} = $label;
			next;
		}

#	edges
#  	v13854 -> v13858 [label = "0142, 049, 056, 1, 1003, 101, 102, 1022, 103, 104, 1040, 105, 1058, 1066"];

		($node1, $node2, $sources) = $line =~ m/^\s*(\S+)\s*->\s*(\S+)\s*\[label\s*=\s*"(.*)"\];\s*$/;
		if (defined $node1) {
			$nedges++;
			my @sources = split /,\s*/, $sources;
			$nsourceedges += scalar(@sources);
			for my $src (@sources) {
				$edgesout{$node1}->{$node2}->{$src} = 1;
				$ledgesout{$node1}->{$src}->{$node2}++;
			}
			$edgesin{$node2}->{$node1} = 1;
			next;
		}

#	cycle edges
#   v13971 -> v14042 [color = "lightgray", style = "dashed" arrowhead = "none", arrowtail = "none" ];

		($node1, $node2) = $line =~ m/^\s*(\S+)\s*->\s*(\S+)\s*\[\s*color[^]]*\];\s*$/;
		if (defined $node1) {
			$ncedges++;
			push @nlinks, [$node1, $node2];
			next;
		}
	}

# statistics

	printf STDERR "%d lines\n", scalar(@lines);
	printf STDERR "Multiple node definitions: %d\n", $duplicatenodes;
	printf STDERR "Nodes: %d\n", scalar(keys(%nodelabel));
	printf STDERR "Edges: %d, source edges %d, identity edges %d\n", $nedges, $nsourceedges, $ncedges;

# sanity checks

#	do all nodes mentioned in an edge have a label?

	my %labelless = ();
	for my $node (keys %edgesout, keys %edgesin) {
		if (!exists $nodelabel{$node}) {
			$labelless{$node}++;
		}
	}
	my @labelless = sort keys %labelless;
	my $nlabelless = scalar @labelless;
	if (!$nlabelless) {
		print STDERR "All nodes mentioned in edges have labels: OK\n";
	}
	else {
		$good = 0;
		for my $node (@labelless) {
			printf STDERR "\t%s : %dx\n", $node, $labelless{$node};
		}
		printf STDERR "%d labelless nodes\n", $nlabelless;
	}

#	do all nodes have at most one outgoing edge for each label?

	$thisgood = 1;
	for my $node1 (keys %ledgesout) {
		my $ledges = $ledgesout{$node1};
		for my $src (sort keys %$ledges) {
			my @node2s = sort keys %{$ledges->{$src}};
			if (scalar(@node2s) == 1 and $ledges->{$src}->{$node2s[0]} == 1) {
				next;
			}
			else {
				$thisgood = 0;
				printf STDERR "\tmultiple labeled edge %s === %s ===> ...:\n", $node1, $src;
				for my $node2 (@node2s) {
					printf STDERR "\t\t%s (%d x)\n", $node2, $ledges->{$src}->{$node2};
				}
			}
		}
	}
	if (!$thisgood) {
		$good = 0;
	}
	else {
		print STDERR "All nodes have at most one outgoing edge for each label\n";
	}

#	is the graph acyclic?
#		we will not test it now: to expensive. Later we check whether each labeled path it acyclic
#		a labeled path is a path that follows edges that are labelled with the same label


#	now add all nodes that occur in cycle edges to classes, and check whether all nodes in each class have the same node label

=head2 doc

for every link between t1 and t2 do:

if either t1 or t2 has a class number, give it to the other as well
if both t1 and t2 have class numbers, merge classes with those numbers
if neither have class numbers, make a new class and give both that class number

we need an index from node to classnumber, and a reverse index from classnumber tot nodeset (for the merging)

=cut

	print STDERR "\tprocessing links ... ";
	my $nclasses = 0;
	for my $link (@nlinks) {
		my ($node1, $node2) = @$link;
		if (!exists $nodeclass{$node1} and !exists $nodeclass{$node2}) {
			$nclasses++;
			$nodeclass{$node1} = 'c'.$nclasses;
			$nodeclass{$node2} = 'c'.$nclasses;
			push @{$classnode{'c'.$nclasses}}, $node1, $node2;
		}
		elsif (!exists $nodeclass{$node1} and exists $nodeclass{$node2}) {
			my $thisclass = $nodeclass{$node2};
			$nodeclass{$node1} = $thisclass;
			push @{$classnode{$thisclass}}, $node1;
		}
		elsif (exists $nodeclass{$node1} and !exists $nodeclass{$node2}) {
			my $thisclass = $nodeclass{$node1};
			$nodeclass{$node2} = $thisclass;
			push @{$classnode{$thisclass}}, $node2;
		}
		else {
			my $thisclass1 = $nodeclass{$node1};
			my $thisclass2 = $nodeclass{$node2};
			if ($thisclass1 eq $thisclass2) {
				next;
			}
			for my $nodex (@{$classnode{$thisclass2}}) {
				$nodeclass{$nodex} = $thisclass1;
				push @{$classnode{$thisclass1}}, $nodex;
			}
			delete $classnode{$thisclass2};
		}
	}
	printf STDERR "%d classes\n", scalar(keys(%classnode));
	if (!writeclasses()) {
		return 0;
	}

# now we have classes, we can check whether the nodes in each class have labels
# per class.

	print STDERR "\tfilling the index with class labels ...\n";
	$thisgood = 1;
	for my $class (sort keys %classnode) {
		my $classgood = 1;
		my $nodes = $classnode{$class};
		my @missing = ();
		for my $node (@$nodes) {
			if (!exists $nodelabel{$node}) {
				$classgood = 0;
				push @missing, $node;
			}
			else {
				$classlabel{$class}->{$node} = $nodelabel{$node};
			}
		}
		if (!$classgood) {
			$classerrors{$class} = \@missing;
			$thisgood = 0;
		}
	}
	if ($thisgood) {
		print STDERR "All nodes in all classes do have a label\n";
	}

# later, when we write out the collation result, we use node names as anchors: all words with the same node name count as collated.
# moreover, identified nodes count as the same collation position, so for nodes that are in a class, we do not use the node name, but the class number instead.

	if (!writeclasserrors()) {
		$good = 0;
	}

	return $good;
}

sub reconstructsources {

# assume that there is a least node in the graph, i.e. from each node you can follow the incoming edges back,
# and what ever path you walk, you end up at the same node, the start node, or least node.
# Analogously for a greatest node, the last node.

# find the first and last node

	my @keys;

	print STDERR "Finding the first node ...\n";
	@keys = keys %edgesout;
	my $startnode = $keys[0];
	my $firstfound = 0;
	while (!$firstfound) {
		my $previous = $edgesin{$startnode};
		@keys = keys %$previous;
		if (!scalar(@keys)) {
			$firstfound = 1;
		}
		else {
			$startnode = $keys[0];
		}
	}
	printf STDERR "\tfirst node = %s\n", $startnode;

	print STDERR "Finding the last node ...\n";
	@keys = keys %edgesin;
	my $lastnode = $keys[0];
	my $lastfound = 0;
	while (!$lastfound) {
		my $next = $edgesout{$lastnode};
		@keys = keys %$next;
		if (!scalar(@keys)) {
			$lastfound = 1;
		}
		else {
			$lastnode = $keys[0];
		}
	}
	printf STDERR "\tlast node = %s\n", $lastnode;
# now gather all the sources, all sources will have an outgoing edge from the first node

	my @sources = ();
	for my $node (keys %{$edgesout{$startnode}}) {
		push @sources, keys %{$edgesout{$startnode}->{$node}};
	}

# now for each source walk through the graph by means of edges that are labeled by that source

	my $good = 1;
	for my $source (sort @sources) {
		printf STDERR "\r\twalking [%s]    ", $source;
		my $nextnode = $startnode;
		my %visited = ();

		while (defined $nextnode) {
			my $thisnode = $nextnode;
			if ($visited{$nextnode}) {
				printf STDERR "Cycle detected! Source = %s; node = %s (%s)\n", $source, $nextnode, $nodelabel{$nextnode};
				$good = 0;
				last;
			}
			else {
				$visited{$nextnode} = 1;
			}
			$nextnode = undef;
			for my $node (keys %{$edgesout{$thisnode}}) {
				if (exists $edgesout{$thisnode}->{$node}->{$source}) {
					if ($node ne $lastnode) {
						my $item;
						my $class = $nodeclass{$node};
						if (defined $class) {
							$item = $class.':'.$node;
						}
						else {
							$item = $node;
						}
						push @{$grid{$source}}, $item;
					}
					$nextnode = $node;
					last;
				}
			}
		}
	}
	print STDERR "\n";
	return $good;
}

sub writeclasserrors {
	print STDERR "Writing the class errors (missing labels) ... \n";
	my $good = 1;
	my $nmissing = 0;
	my $infofile = sprintf $infopath, 'classerr';
	if (!open(P, ">:encoding(UTF-8)", $infofile)) {
		print STDERR "Can't write to file [$infofile]\n";
		return 0;
	}
	for my $class (sort keys %classerrors) {
		my $missing = $classerrors{$class};
		if (scalar(@$missing)) {
			printf P "\tClass %d: missing nodes (%s):\n", $class, scalar(@$missing);
			for my $node (sort @$missing) {
				printf P "\t\t%s\n", $node;
				$nmissing++;
			}
		}
	}
	close P;

	if ($nmissing) {
		printf STDERR "Nodes in classes without label: %d\n", $nmissing;
		$good = 0;
	}
	return $good;
}

sub writeclasses {
	print STDERR "Printing the classes\n";
	my $infofile = sprintf $infopath, 'classes';
	if (!open(P, ">:encoding(UTF-8)", $infofile)) {
		print STDERR "Can't write to file [$infofile]\n";
		return 0;
	}
	for my $class (sort keys %classnode) {
		my $nodes = $classnode{$class};
		printf P "%s=%s\n", $class, join(', ', sort @$nodes);
	}

	close P;
	return 1;
}

sub writelabelindex {
	print STDERR "Printing the labelindex\n";
	my $infofile = sprintf $infopath, 'labelindex';
	if (!open(P, ">:encoding(UTF-8)", $infofile)) {
		print STDERR "Can't write to file [$infofile]\n";
		return 0;
	}
	for my $class (sort keys %classlabel) {
		my $nodes = $classlabel{$class};
		for my $node (sort keys %$nodes) {
			printf P "%-10s %-10s : %s\n", $class, $node, $nodes->{$node};
		}
	}
	for my $item (sort keys %nodelabel) {
		printf P "%-10s : %s\n", $item, $nodelabel{$item};
	}

	close P;
	return 1;
}

sub makecollationtable {
	if (!readindex()) {
		return 0;
	}
	$collationinfo{id} = makecollationrecord();
	print STDERR "Processing alignment ... \n";
	my $good = 1;
	for my $source (sort keys %grid) {
		my $source_id = $indexsource{$source};
		if (!defined $source_id) {
			printf STDERR "\tmissing source id for [%s]\n", $source;
			$good = 0;
			next;
		}
		my $curwordnumstart = 1;
		my $items = $grid{$source};
		for my $item (@$items) {
			my ($label, $symbol);
			my ($class, $node) = $item =~ m/^([^:]+):(.*)$/;
			if (defined $class) {
				$label = $classlabel{$class}->{$node};
				$symbol = $class;
			}
			else {
				$label = $nodelabel{$item};
				$symbol = $item;
			}
			my $thisn = scalar split / /, $label;
			push @{$records{collationdata}}, [$collationinfo{id}, $source_id, $curwordnumstart, $curwordnumstart + $thisn - 1, $symbol];
			$curwordnumstart += $thisn;
		}
	}
	if (!writesql()) {
		return 0;
	}
	return 1;
}

sub writesql {
	if (!open(P, ">:encoding(UTF-8)", $resultpath)) {
		print STDERR "Can't write to file [$resultpath]\n";
		return 0;
	}
	if (!defined $collationinfo{id}) {
		return 0;
	}
	printf P "use %s;\n", $database{db};
	writetable('collationdata');
	close P;
	return 1;
}

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

sub writegrid {
	print STDERR "Writing pretty grid for checking purposes\n";
	my $infoprettyfile = sprintf $infopath, 'pretty';
	if (!open(PP, ">:encoding(UTF-8)", $infoprettyfile)) {
		print STDERR "Can't write to file [$infoprettyfile]\n";
		return 0;
	}
	my $infonodefile = sprintf $infopath, 'node';
	if (!open(PN, ">:encoding(UTF-8)", $infonodefile)) {
		print STDERR "Can't write to file [$infonodefile]\n";
		return 0;
	}

# PP is for checking purposes against the original input: it shows the reconstructed sources
# it should generate exactly the same file as the context script did
# PN shows the nodes or classes

	for my $source (sort keys %grid) {
		printf PP "%-10s:", $source;
		printf PN "%-10s:", $source;
		my $sourceinfo = $grid{$source};
		for my $item (@$sourceinfo) {
			my $label;
			my ($class, $node) = $item =~ m/^([^:]+):(.*)$/;
			if (defined $class) {
				$label = $classlabel{$class}->{$node};
			}
			else {
				$label = $nodelabel{$item};
			}
			printf PP " %s", $label;
			printf PN " %s", $item;
		}
		print PP "\n";
		print PN "\n";
	}
	close PP;
	close PN;
	return 1;
}

sub transform {
	my $good = 1;
	timestamp('process alignment', 2);
	for (1) {
		timestamp('create graph', 2);
		print STDERR "Internalize the alignment graph\n";
		if (!creategraph()) {
			$good = 0;
		}
		print STDERR elapsed('create graph');
		if (!$good) {
			next;
		}

		timestamp('walk graph', 2);
		print STDERR "Walk through the graph and make a grid of all sources\n";
		if (!reconstructsources()) {
			$good = 0;
		}
		print STDERR "\n";
		print STDERR elapsed('walk graph');
		if (!$good) {
			next;
		}

		if (!writegrid()) {
			$good = 0;
			next;
		}

		timestamp('generate sql', 2);
		print STDERR "Turn the alignment result into an sql table\n";
		if (!makecollationtable()) {
			$good = 0;
		}
		print STDERR "\n";
		print STDERR elapsed('generate sql');
		if (!$good) {
			next;
		}

	}
	print STDERR elapsed('process alignment');
	return $good;
}

sub initialize {
	my $good = 1;

	my $testrep;
	if ($test == 2) {
		$testrep = '-test';
	}
	elsif ($test == 1) {
		$testrep = '-limited';
	}
	else {
		$testrep = '';
	}

	$fileinpath = sprintf "%s%s-max%d-win%d-comm%.1f.txt", $filein, $testrep, $maxiter, $windowsize, $commonality;
	$resultpath = sprintf "%s%s-max%d-win%d-comm%.1f.sql", $resultout, $testrep, $maxiter, $windowsize, $commonality;
	$infopath = sprintf "%s%s-%%s-max%d-win%d-comm%.1f.txt", $resultout, $testrep, $maxiter, $windowsize, $commonality;
	$indexinpath = "$indexin-%s.txt";

	if (!$granularities{$granularity}) {
		print STDERR "Unsupported granularity [$granularity].\nChoose one of ".join(", ", sort(keys(%granularities)))."\n";
		$good = 0;
	}
	return $good;
}

sub writetable {
	my $table = shift;
	print STDERR "Writing table [$table] ...\n";
	my $sep = '  ';
	my $resume = sprintf "insert into %s (%s) values \n", $table, join(',',@{$fieldnames{$table}});
	print P $resume;
	my $nrecords = 0;
	my $thisn = 0;
	my $period = 10000;
	for my $record (@{$records{$table}}) {
		if ($thisn == $period) {
			printf STDERR "\r\t$nrecords     ";
			print P ";\n";
			print P $resume;
			$thisn = 0;
			$sep = '  ';
		}
		print P $sep;
		writerecord($table, $record);
		$sep = ', ';
		$nrecords++;
		$thisn++;
	}
	printf STDERR "\r\t$nrecords     \n";
	print P ";\n\n";
}

sub writerecord {
	my ($table, $record) = @_;
	print P '(';
	my $fsep = '';
	for (my $i = 0; $i <= $#$record; $i++) {
		print P $fsep;
		$fsep = ',';
		if (!defined $record->[$i]) {
			print P 'null';
		}
		else {
			if ($textfields{$table}->[$i]) {
				print P sq($record->[$i]);
			}
			else {
				print P $record->[$i];
			}
		}
	}
	print P ")\n";
}

sub sq {
	my $text = shift;
	$text =~ s/'/''/sg;
	return "'".$text."'";
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

sub timestamp {
	my $mark = shift;
	my $nest = shift;
	@{$time{$mark}} = gettimeofday();
	$timenest{$mark} = $nest;
}

sub elapsed {
	my $mark = shift;
	my $elapsed = tv_interval($time{$mark});
	my $seconds = $elapsed;
	my $minutes;
	my $hours;
	if ($seconds > 60) {
		$seconds = int($seconds + 0.5);
		$minutes = int($seconds / 60);
		$seconds = $seconds % 60;
	}
	if ($minutes > 60) {
		$hours = int($minutes / 60);
		$minutes = $minutes % 60;
	}
	my $resultstring = '';
	if (defined $hours) {
		$resultstring .= sprintf "%d h", $hours;
	}
	if (defined $minutes) {
		$resultstring .= sprintf "%d m", $minutes;
	}
	if ($seconds == int($seconds)) {
		$resultstring .= sprintf "%d s", $seconds;
	}
	else {
		$resultstring .= sprintf "%.2f s", $seconds;
	}
	return
		('-' x 80)
	.	$mark
	.	('─' x (20 - length($mark)))
	.	('─' x (40 - $timenest{$mark} * 8))
	.	('─' x (10 - length($resultstring)))
	.	$resultstring
	.	"\n";
}

sub main {
	timestamp('program', 0);
	my $good = 1;
	for (1) {
		if (!initialize()) {
			$good = 0;
			next;
		}
		if (!processsource()) {
			$good = 0;
			next;
		}
		if (!transform()) {
			$good = 0;
			next;
		}
	}
	print STDERR elapsed('program');
	return $good;
}

exit !main();

