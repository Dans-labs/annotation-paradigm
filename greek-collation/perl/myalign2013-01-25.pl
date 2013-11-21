#!/usr/bin/perl

=head2 idea

Use my algorithm

INPUT DESCRITPION

Step 0: readsource() or readsourcesql
 
the file layersnumeric (which contains the complete transcription data) is parsed,
the SRC layer is taken, split into words (on /[ ·]/).

Alternatively, the data can also be read from the database that is generated out of the file layersnumeric.
The query needs only the tables word, passage and source, not the table layerdata.
The word table is basically the same as layerdata, but simpler in two ways:
i it only represents the SRC layer, all other layers are ignored
ii the granularity is at the word level

The table word does contain character positions of the starts of words relative to passage and source, but this script will ignore them.
The table word contains words as well as the things that are between words. Only the words have numbers.

I have checked the input through readsource directly and through readsourcesql. The result is identical.

So I switch to reading from the database, since future collation attempts should get their input from the database and deliver their 
results to the database.

The words are collectively stored %words, with number of occurrences. 
The passage texts are stored per passage per source in %sources

PROCESS DESCRIPTION

Step 1: cluster()

cluster the words with a Levenshtein like similarity: 

(2 * length of longest common subsequence ) / sum of lengths

Result: @clusters of individual $cluster s
which are themselves arrays of strings, the strings are the words.

Step 2: linksources()

For every passage make a master bag of words in that passage,
plus bidirectional links from every word occurrence in the source to
the words in the master bag.

The resulting datastructure is:

--------

The masterbag per passage

%masterbag{$passage}->{$clusternumber}->{$occurrencenumber} = $n

where $n is the number of source words linked to it

--------

The links from the source passages to the masterbagitems

%linkto{$passage}->{$source}->{$wordnum} = [$clusternumber, $occurrencenumber]

--------

The links back from the masterbagitems to the wordnumbers in the sources

%linkfrom{$passage}->{$clusternumber}->{$occurrencenumber}->{$source}->{$wordnum}->1

--------

Step 3: context analysis (renewed)

In order to collate words from different clusters, we analyze contexts.

The $skeletonthreshold is a fraction. A cluster occurrence in a passage that has frequency higher than this threshold, belongs to the skeleton.
More precisely: the frequency of a cluster occurrence in a passage is the number of times this occurrence is linked to from the sources in proportion to the total number of sources, that is the value in %masterbag.

A context of a cluster occurrence in a passage in a source is the sequence of names of the cluster occurrences in that passage, separated by |, where the cluster occurrence in question is replaced by a special place holder character and the non-skeleton cluster occurrences are replaced by the character * .

For every passage we compute all contexts and list them in a hash as key, with values the set of cluster occurrences that have that context.

%context{passage}->{$context}->{clusterocc}->{$source}->{$wordnum} = 1

where $clusterocc = "$clusternumber#$clusteroccurrence" and

So the context analysis step should go this way:

We work per passage.

For every context: identify all clusteroccs that occur in the sources (in that context).
That effect can be expressed as follows:
we make a new, virtual cluster occurrence, say x#0 and we adapt the linkfrom and linkto hashes as follows

For sources and clusteroccs under consideration

		$linkto{$passage}->{source}->{$wordnum} = [x,0]
		$linkfrom{passage}->{x}->{0}->{source}->{wordnum} = 1

If we have done this, the context situation has changed, we have more equal context. So repeat it, including computing the skeleton contexts.

Parameters: 

	contextwidth: the maximum number of skeleton tokens left and right that make up a context
	contextweight: the minimum number of skeleton tokens that should be in a context in order to induce identifications

OUTPUT DESCRIPTION

In the database there is a table collation, that contains collation descriptions. The name and version of the collation algorithm, parameters and settings, author, provenance kind of things.

The actual collation data is in a table collationdata, which essentially maps each word-number in a passage in a source to an arbitrary token. The meaning is that all words with the same token occupy corresponding positions.
An interface that wants to show variants at corresponding positions has to query for word numbers with a given token.

=cut

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

use Algorithm::Diff qw(LCS_length);
use DBI;

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my $selectpassage = undef;

my $clusterthreshold = 0.8;
my $skeletonthreshold = 0.6;
my $contextwidth = 3;
my $contextweight = 3;
my $maxmerge = 100;

my $forcecomputeclusters = 0; # if 0 then clusters will be read from clusterfile, if it exists, clustercomputation will be skipped, no file written; otherwise clusters will be computed and written to clusterfile.

my ($filein, $fileout, $clusterfile, $infofile, $modeldir) = @ARGV;

my $infocollatfile = $infofile.'-collat%s.txt';
my $infomasterfile = $infofile.'-master%s.txt';
my $infocontextfile = $infofile.'-context%s.txt';
my $sqlfile = $fileout.'.sql';
my $modelfile = $modeldir.'/collat_dirk.sql';

my %sources = ();
my %words = ();
my @preparedwords = (); # auxiliary, to speed up the similarity calculations
my @clusters = ();
my $nclusters;
my %cluster2num = (); # auxiliary, to do cluster lookups
my %source_index = ();
my %passage_index = ();
my %similarity = ();

# parameters to write into the collation result

my %collationinfo = (
	id => 111,
	name => 'collat_dirk',
	author => 'Dirk Roorda',
	version => '0.8',
	algorithm => 'masterbag',
	parameters => sprintf("%s = %.1f; %s = %.1f; %s = %.1f; %s = %.1f; %s = %.1f",
		'cluster threshold', $clusterthreshold,
		'skeleton threshold', $skeletonthreshold,
		'max context width', $contextwidth,
		'min context weight', $contextweight,
	),
	description => 'collation by mapping words in a passage to an unordered bag of word clusters.',
);

# datastructure for linking

my %masterbag = ();
my %linkto = ();
my %linkfrom = ();
my %context = ();
my %weight = ();

sub makemasters {
	print STDERR "linking the sources ...\n";
	for my $passage (sort {$a <=> $b} keys %sources) {
		printf STDERR "Linking %d ...\n", $passage;
		my $passageinfo = $sources{$passage};
		for my $source (sort keys %$passageinfo) {
			addlink($passage, $source, $passageinfo->{$source});
		}
	}
}

sub computecontext {
	my $iteration = shift;
	%context = ();
	printf STDERR "computing the context ...(with threshold %f)\n", $skeletonthreshold;
	for my $passage (sort {$a <=> $b} keys %sources) {
		printf STDERR "contexting %d ...\n", $passage;
		my $passageinfo = $sources{$passage};
		for my $source (sort keys %$passageinfo) {
			addcontext($passage, $source, $passageinfo->{$source});
		}
	}
	writecontext($iteration);
}

sub addlink {
	my ($passage, $source, $words) = @_;
	if (!exists $masterbag{$passage}) {
		$masterbag{$passage} = {};
	}
	my %curmasteritemcount = (); # keep count of the occurrences of clusters in the source passage because multiple occurrences in a source require multiple occurrences in the master bag
	for (my $i = 0; $i <= $#$words; $i++) {
		my $word = $words->[$i];
		my $clusternum = $cluster2num{$word};
		$curmasteritemcount{$clusternum}++;;
		my $curcount = $curmasteritemcount{$clusternum};

# update the master bag
		my $masterinfo = $masterbag{$passage};
		$masterinfo->{$clusternum}->{$curcount}++;

# update the link to
		$linkto{$passage}->{$source}->{$i} = [$clusternum, $curcount];

# update the link from
		$linkfrom{$passage}->{$clusternum}->{$curcount}->{$source}->{$i} = 1;
	}
}

sub addcontext {
	my ($passage, $source, $words) = @_;
	my $nsources = scalar keys %{$sources{$passage}};
	my @clustersequence = ();
	for (my $i = 0; $i <= $#$words; $i++) {
		my $word = $words->[$i];
		my ($clusternumber, $occurrencenumber) = @{$linkto{$passage}->{$source}->{$i}};
		my $weight = $masterbag{$passage}->{$clusternumber}->{$occurrencenumber};
		my $relativeweight = $weight / $nsources;
		my $clusterocc = sprintf "%d#%d", $clusternumber, $occurrencenumber;
		$weight{$passage}->{$clusterocc} = $relativeweight;
		push @clustersequence, [$clusterocc, $relativeweight];
	}

# make a skeleton sequence
	my @skeletonsequence = ();
	for my $item (@clustersequence) {
		my ($clusterocc, $relativeweight) = @$item;
		if ($relativeweight < $skeletonthreshold) {
			push @skeletonsequence, '*';
		}
		else {
			push @skeletonsequence, $clusterocc;
		}
	}

# now fill the global context datastructure
	for (my $i = 0; $i <= $#clustersequence; $i++) {

#		determine left and right contexts for clusterocc i with enough but not too much significant skeleton elements
		my ($clusterocc, $relativeweight) = @{$clustersequence[$i]};

#		do the left and right contexts separately. Start with a minimal context, and expand as far as needed
		my $leftboundary = $i - 1;
		my $rightboundary = $i + 1;
		my $leftskeletonitems = 0;
		my $rightskeletonitems = 0;
		my $contextlength;

#		left context: move to the left and count significant skeleton elements
		for (my $j = $i - 1; $j >= 0; $j--) {
			$leftboundary = $j;
			if ($skeletonsequence[$j] ne '*') {
				$leftskeletonitems++;
			}
#			stop when we have enough significant skeleton elements
			if ($leftskeletonitems >= $contextwidth) {
				last;
			}
#		or stop when we have run out of context
		}
		if ($leftboundary < 0) {
			$leftboundary = 0;
		}

#		if we could not get enough significant elements, we may have a head of insignificant elements
#		we strip them, but we stop stripping if the context length reaches a value contextwidth
		$contextlength = $i - $leftboundary;
		while ($contextlength > $contextwidth) {
			if ($skeletonsequence[$leftboundary] eq '*') {
				$leftboundary++;
			}
			else {
				last;
			}
		}

#		right context: move to the right and count significant skeleton elements
		for (my $j = $i + 1; $j <= $#skeletonsequence; $j++) {
			$rightboundary = $j;
			if ($skeletonsequence[$j] ne '*') {
				$rightskeletonitems++;
			}
#			stop when we have enough significant skeleton elements
			if ($rightskeletonitems >= $contextwidth) {
				last;
			}
#		or stop when we have run out of context
		}
		if ($rightboundary > $#skeletonsequence) {
			$rightboundary = $#skeletonsequence;
		}

#		if we could not get enough significant elements, we may have a tail of insignificant elements
#		we strip them, but we stop stripping if the context length reaches a value contextwidth
		$contextlength = $rightboundary - $i;
		while ($contextlength > $contextwidth) {
			if ($skeletonsequence[$rightboundary] eq '*') {
				$rightboundary--;
			}
			else {
				last;
			}
		}

		if ($leftskeletonitems + $rightskeletonitems < $contextweight) {
			next;
		}
		my $leftcontext = join("|",  @skeletonsequence[$leftboundary..$i-1]);
		my $rightcontext = join("|", @skeletonsequence[$i+1..$rightboundary]);
		my $allcontext = sprintf "|%s|▲|%s|", $leftcontext, $rightcontext;
		$context{$passage}->{$allcontext}->{$clusterocc}->{$source}->{$i} = 1;
	}
}

sub mergecontext {
	my %lastmerged = ();
	$nclusters = scalar @clusters;
	for (my $i = 1; $i <= $maxmerge; $i++) {
		computecontext($i);
		my $totalmerged = 0;
		printf "Merging iteration %d\n", $i;
		for my $passage (sort keys %context) {
			if (exists $lastmerged{$passage} and $lastmerged{$passage} == 0) {
				next;
			}
			else {
				my $nmerged = mergecontextpassage($passage, $i);
				$totalmerged += $nmerged;
				$lastmerged{$passage} = $nmerged;
				printf "\t[%s]: %d mergers\n", $passage, $nmerged;
			}
		}
		printf "Total %d mergers in iteration %d\n", $totalmerged, $i;
		if ($totalmerged == 0) {
			last;
		}
	}
}

sub mergecontextpassage {
	my $passage = shift;
	my $iteration = shift;
	my $contextinfo = $context{$passage};
	my $mergers = 0;

	my $masterinfo = $masterbag{$passage};
	for my $context (keys %$contextinfo) {
		my $clusterinfo = $contextinfo->{$context};
		my $ncluster = scalar keys %$clusterinfo;
		if ($ncluster < 2) {
			next;
		}
		$mergers += $ncluster;
		my $affectedsources = 0;

		my $newclusternum = $nclusters++;
		my $newcluster = $newclusternum . "#1";

		$masterinfo->{$newclusternum}->{1} = 0;

		for my $cluster (keys %$clusterinfo) {
			my $sourceinfo = $clusterinfo->{$cluster};
			my $nsources = scalar keys %$sourceinfo;
			$affectedsources += $nsources;

			my ($clusternum, $clustercount) = split /#/, $cluster;

			$masterinfo->{$newclusternum}->{1} += $masterinfo->{$clusternum}->{$clustercount};

			for my $source (keys %$sourceinfo) {
				my $numinfo = $sourceinfo->{$source};
				for my $num (keys %$numinfo) {
					$linkto{$passage}->{$source}->{$num} = [$newclusternum, 1];

					$linkfrom{$passage}->{$newclusternum}->{1}->{$source}->{$num} = 1;
					delete $linkfrom{$passage}->{$clusternum}->{$clustercount}->{$source}->{$num};
					if (!scalar(keys(%{$linkfrom{$passage}->{$clusternum}->{$clustercount}->{$source}}))) {
						delete $linkfrom{$passage}->{$clusternum}->{$clustercount}->{$source};
					}
					if (!scalar(keys(%{$linkfrom{$passage}->{$clusternum}->{$clustercount}}))) {
						delete $linkfrom{$passage}->{$clusternum}->{$clustercount};
					}
					if (!scalar(keys(%{$linkfrom{$passage}->{$clusternum}}))) {
						delete $linkfrom{$passage}->{$clusternum};
					}
				}
			}
		}

		printf STDERR "\t\tmerged %d clusters in %d sources\n", $ncluster, $affectedsources;
	}
	return $mergers;
}

=head test

$context{$passage}->{$allcontext}->{$cluster}->{$source}->{num} = 1;

# update the master bag
		my $masterinfo = $masterbag{$passage};
		$masterinfo->{$clusternum}->{$curcount}++;

# update the link to
		$linkto{$passage}->{$source}->{$i} = [$clusternum, $curcount];

# update the link from
		$linkfrom{$passage}->{$clusternum}->{$curcount}->{$source}->{$i} = 1;
	}

=cut

sub index_table {
	my ($table, $index) = @_;
	print STDERR "reading the names in table $table and indexing them ...\n";
	my $dbh = DBI->connect('DBI:mysql:jude','root','dipre207');
	$dbh->{'mysql_enable_utf8'}=1;
	if (!$dbh) {
		print STDERR "Cannot connect to mysql database jude\n";
		return 0;
	}
	my $sql = "select id, name from $table;";
	my $sth = $dbh->prepare($sql);
	if (!$sth->execute) {
		print STDERR "Cannot execute query [$sql]\n";
		return 0;
	}
	my $good = 1;
	while (my @row = $sth->fetchrow_array()) {
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
	if (!index_table('passage', \%passage_index)) {
		$good = 0;
	}
	return $good;
}

sub readsourcesql {
	print STDERR "reading the sources from sql ...\n";
	my $dbh = DBI->connect('DBI:mysql:jude','root','dipre207');
	$dbh->{'mysql_enable_utf8'}=1;
	if (!$dbh) {
		print STDERR "Cannot connect to mysql database jude\n";
		return 0;
	}
	my $sql = "
select
	word.glyphs, word.word_number, passage.name, source.name
from
	word
inner join
	passage
on
	word.passage_id = passage.id
inner join
	source
on
	word.source_id = source.id
";
	my $sth = $dbh->prepare($sql);
	if (!$sth->execute) {
		print STDERR "Cannot execute query [$sql]\n";
		return 0;
	}
	my $nwords = 0;
	my %sourcelist = ();
	my %passagelist = ();
	while (my @row = $sth->fetchrow_array()) {
		my ($glyphs, $wordnumber, $passage, $source) = @row;
		$passage =~ s/[\[\]]//g;
		if ($glyphs =~ m/^[ ·]*$/) {
			next;
		}
		$words{$glyphs}++;
		$nwords++;
		$sourcelist{$source} = 1;
		$sources{$passage}->{$source}->[$wordnumber-1] = $glyphs;
	}
	my $sourcepassages = 0;
	for my $p (keys %sources) {
		$sourcepassages += scalar keys %{$sources{$p}};
	}
	printf STDERR "number of sources: %d\n", scalar keys %sourcelist; 
	printf STDERR "number of source passages: %d\n", $sourcepassages; 
	printf STDERR "number of words: %d (%d different ones)\n", $nwords, scalar(keys(%words)); 
	return 1;
}

sub wordsim {
	my ($w1, $w2) = @_;
	my $lw1 = scalar @$w1;
	my $lw2 = scalar @$w2;
	my $lcsl = LCS_length($w1, $w2);
	my $similarity = (2 * $lcsl) / ($lw1 + $lw2);
	return $similarity;
}

sub preparewords {
	for my $word (sort keys %words) {
		my @splitword = split //, $word;
		push @preparedwords, \@splitword;
	}
}

sub prepareclusters {
	for (my $i = 0; $i <= $#clusters; $i++) {
		my $words = $clusters[$i];
		for my $word (@$words) {
			$cluster2num{$word} = $i;
		}
	}
}

sub readclusters {
	if ($forcecomputeclusters) {
		return 0;
	}
	printf STDERR "Reading clusters from file ...\n";
	if (!open(CLUS, "<:encoding(UTF-8)", $clusterfile)) {
		print STDERR "Cannot read file [$clusterfile]\n";
		return 0;
	}
	my $curcluster = [];
	while (my $line = <CLUS>) {
		chomp $line;
		if (substr($line, 0, 10) eq '-' x 10) {
			if (scalar @$curcluster) {
				push @clusters, $curcluster;
				$curcluster = [];
			}
			next;
		}
		push @$curcluster, $line;
	}
	if (scalar @$curcluster) {
		push @clusters, $curcluster;
	}
	close CLUS;
	return 1;
}

sub cluster {
	my @computedclusters = ();
	printf STDERR "Computing clusters ...(with threshold = %f)\n", $clusterthreshold;
	my $nwords = 0;
	my $nclusters = 0;
	for my $w1 (@preparedwords) {
		$nwords++;
		my $inserted = 0;
		for my $cluster (@computedclusters) {
			for my $w2 (@$cluster) {
				if (wordsim($w1, $w2) > $clusterthreshold) {
					push @$cluster, $w1;
					$inserted = 1;
					last;
				}
			}
			if ($inserted) {
				last;
			}
		}
		if (!$inserted) {
			push @computedclusters, [$w1];
			$nclusters++;
		}
		print STDERR "\r$nwords - $nclusters        ";
	}
# now replaces the words as arrays of letters by words as strings
	for my $cluster (@computedclusters) {
		my $thiscluster = [];
		for my $w (@$cluster) {
			push @$thiscluster, join('', @$w);
		}
		push @clusters, $thiscluster;
	}
}

sub writeclusters {
	printf STDERR "\nNumber of clusters = %d\n", scalar(@clusters);
	printf STDERR "Writing clusters to file ...\n";
	if (!open(CLUS, ">:encoding(UTF-8)", $clusterfile)) {
		print STDERR "Cannot write file [$clusterfile]\n";
		return 0;
	}
	for my $cluster (@clusters) {
		print CLUS '-' x 20, "\n";
		for my $w (@$cluster) {
			print CLUS $w, "\n";
		}
	}
	close CLUS;
}

sub writemaster {
	my $version = shift;
	my $infomasterversionfile = sprintf $infomasterfile, $version;
	printf STDERR "Writing masterbag $version to file ...\n";
	if (!open(INF, ">:encoding(UTF-8)", $infomasterversionfile)) {
		print STDERR "Cannot write file [$infomasterversionfile]\n";
		return 0;
	}
	for my $passage (sort {$a <=> $b} keys %masterbag) {
		printf INF "[%d]\n", $passage;
		my $passageinfo = $masterbag{$passage};
		my $ci = 0;
		my @lines = ();
		my @widths = ();
		for my $clusternum (sort {$a <=> $b} keys %$passageinfo) {
			if ($clusternum == 666) {
				dummy();
			}
			my $clusterinfo = $passageinfo->{$clusternum};
			for my $clustercount (sort {$a <=> $b} keys %$clusterinfo) {
# the weight counts how many surface word occurrences in the sources are linked to this cluster occurrence
				my $weight = $clusterinfo->{$clustercount};
				my $cell = sprintf "%d#%d x%d", $clusternum, $clustercount, $weight;
				$lines[0]->[$ci] = $cell;
				if (length($cell) > $widths[$ci]) {
					$widths[$ci] = length($cell);
				}
				my $wi = 0;

				my %collectedwords = ();
				my $sourceinfo = $linkfrom{$passage}->{$clusternum}->{$clustercount};
				for my $source (sort keys %$sourceinfo) {
					my $wordinfo = $sourceinfo->{$source};
					for my $wordnum (sort keys %$wordinfo) {
						my $word = $sources{$passage}->{$source}->[$wordnum];
						$collectedwords{$word}++;
					}
				}
				for my $word (sort {$collectedwords{$b} <=> $collectedwords{$a}} keys %collectedwords) {
					my $cell = sprintf "%dx %s", $collectedwords{$word}, $word;
					$lines[$wi+1]->[$ci] = $cell;
					if (length($cell) > $widths[$ci]) {
						$widths[$ci] = length($cell);
					}
					$wi++;
				}
				$ci++;
			}
		}
		for my $line (@lines) {
			print INF "|";
			my $ci = 0;
			for my $word (@$line) {
				my $width = $widths[$ci];
				printf INF '%-'.$width.'s|', $word;
				$ci++;
			}
			print INF "\n";
		}
		print INF "\n";
	}
	close INF;
}

sub writecontext {
	my $iteration = shift;
	my $infocontextiterfile = sprintf $infocontextfile, $iteration;
	printf STDERR "Writing context $iteration to file ...\n";
	if (!open(INF, ">:encoding(UTF-8)", $infocontextiterfile)) {
		print STDERR "Cannot write file [$infocontextiterfile]\n";
		return 0;
	}
	for my $passage (sort {$a <=> $b} keys %context) {
		printf INF "[%s]\n", $passage;
		my $passageinfo = $context{$passage};
		for my $cnt (sort keys %$passageinfo) {
			printf INF "\t%s\n", $cnt;
			my $clusinfo = $passageinfo->{$cnt};
			for my $clus (sort keys %$clusinfo) {
				printf INF "\t\t%s\n", $clus;
				my $srcinfo = $clusinfo->{$clus};
				for my $src (sort keys %$srcinfo) {
					my $numinfo = $srcinfo->{$src};
					for my $num (sort {$a <=> $b} keys %$numinfo) {
						printf INF "\t\t\t%s[%d]\n", $src, $num;
					}
				}
			}
		}
	}
	close INF;
}

sub dummy {
	1;
}

sub main {
	if (!readnames()) {
		return 0;
	}
	if (!readsourcesql()) {
		return 0;
	}
	preparewords();
	if (!readclusters()) {
		cluster();
		writeclusters();
	}
	prepareclusters();
	makemasters();
	writemaster('pure');
	mergecontext();
	writemaster('final');
	return 1;
}

exit !main();
