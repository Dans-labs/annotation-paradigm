#!/usr/bin/perl

=head2 idea

Use my algorithm

Step 0: readsource()
 
the file layersnumeric (which contains the complete transcription data) is parsed,
the SRC layer is taken, split into words (on /[ ·]/).

The words are collectively stored %words, with number of occurrences. 
The passage texts are stored per passage per source in %sources


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

The number of links back from the masterbagitems to the sources, and then counting per word occurrence in the source, so that we can retrieve per source word how many identical words in other sources are linked to it

--------

%linknum{$passage}->{$clusternumber}->{$occurrencenumber}->{word} = $n

The number of links back from the masterbagitems to the sources, irrespective of the specific word in the cluster, so that we can retrieve per cluster occurrence in the masterbag in how many sources it occurs.

We build this datastructure by starting empty and then for each passage adding sources,
which is done by addlink($passage, $source, [$words_in_passage_according_source])

Step 3: context analysis

In order to collate words from different clusters, we analyze contexts.

The $skeletonthreshold is a fraction. A cluster occurrence in a passage that has frequency higher than this threshold, belongs to the skeleton.
More precisely: the frequency of a cluster occurrence in a passage is the number of times this occurrence is linked to from the sources, that is the value in %masterbag.

For every cluster occurrence in the masterbag of a passage we compute the skeleton contexts of it. The skeleton context of a cluster occurrence is a bag of pairs.
Each pair comes from a source and consists of the first cluster occurrence left and the first cluster occurrence right of the cluster occurrence in question. Pairs that occur in more sources are counted, hence a BAG of pairs, not just a set.

%context{passage}->{$clusterocc}->{"$leftskel-$rightskel"} = $n
%weight{passage}->{$clusterocc}-> = $frequency

where $clusterocc = "$clusternumber#$clusteroccurrence" and
where $leftskel and $rightskel have the form "$clusternumber#$clusteroccurrence"

Then we merge the non-skeleton cluster occurrences that have enough identical contexts. First hypothesis: enough = having at least one common significant context. A significant context of a clusteroccurrence is a context in which that occurrence occurs with a frequency greater than the $mergethreshold. The context needs only to be significant for one of the clusteroccurrences.

But then, how do we update the datastructures according to these identifications?

(1a) look at
$masterbag{$passage}->{$cl_num1}->{$cl_count1} = $n1
and
$masterbag{$passage}->{$cl_num2}->{$cl_count2} = $n2

Take the first one and make $n1 into $n1+$n2
Then remove the other one from the masterbag.

(1b) same for $weight{$passage}->{$clusterocc}

(2) find all links to $cl_num2, $cl_count2; (they can be found in the %linkfrom hash)
replace them in %linkto by [$cl_num1, $cl_count1]

(3) in %linkfrom move all key,value pairs in 
$linkfrom{$passage}->{$cl_num2}->{$cl_count2}
to
$linkfrom{$passage}->{$cl_num1}->{$cl_count1}

(4) in %linknum move all key,value pairs in
$linknum{$passage}->{$cl_num2,$cl_count2}
to
$linknum{$passage}->{$cl_num1,$cl_count1}

=cut

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

use Algorithm::Diff qw(LCS_length);

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my $selectpassage = 1;
my $clusterthreshold = 0.8;
my $skeletonthreshold = 0.9;
my $mergethreshold = 0.05;

my $forcecomputeclusters = 0; # if 0 then clusters will be read from clusterfile, if it exists, clustercomputation will be skipped, no file written; otherwise clusters will be computed and written to clusterfile.

my ($filein, $fileout, $clusterfile, $infofile) = @ARGV;

my $infonumfile = $infofile.'-num.txt';
my $infocollatfile = $infofile.'-collat%s.txt';
my $infocontextfile = $infofile.'-context.txt';
my $infomergefile = $infofile.'-merge.txt';
my $infomasterfile = $infofile.'-master%s.txt';

my %sources = ();
my %words = ();
my @preparedwords = (); # auxiliary, to speed up the similarity calculations
my @clusters = ();
my %cluster2num = (); # auxiliary, to do cluster lookups

# datastructure for linking

my %masterbag = ();
my %linkto = ();
my %linkfrom = ();
my %linkcount = ();
my %linknum = ();
my %context = ();
my %weight = ();

my %icontext = (); # inverse of %context, needed for efficient cluster merging
my %mergedclusteroccs = (); # stores the merge instructions

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

sub computecontexts {
	print STDERR "computing the contexts ...\n";
	for my $passage (sort {$a <=> $b} keys %sources) {
		printf STDERR "contexting %d ...\n", $passage;
		my $passageinfo = $sources{$passage};
		for my $source (sort keys %$passageinfo) {
			addcontext($passage, $source, $passageinfo->{$source});
		}
	}
}

sub mergeclusters {
	print STDERR "computing clusters based on context ...\n";
	for my $passage (sort {$a <=> $b} keys %icontext) {
		printf STDERR "Merging clusters in %d ...\n", $passage;
		my $contextinfo = $icontext{$passage};
		my %done = ();
		dummy();
		for my $context (sort keys %$contextinfo) {
			my $clusteroccs = $contextinfo->{$context};
			my $significant = 1;
			for my $clusterocc (keys %$clusteroccs) {
				if ($clusteroccs->{$clusterocc} < $mergethreshold) {
					$significant = 0;
				}
				else {
					printf STDERR "%f > %f\n", $clusteroccs->{$clusterocc}, $mergethreshold;
				}
			}
			if (!$significant) {
				next;
			}
			push @{$mergedclusteroccs{$passage}}, [keys %$clusteroccs];
		}
		normalize($mergedclusteroccs{$passage});
		mergecluster($passage);
	}
}

sub normalize {
	my ($setofsets) = @_;
	my %indexmap = ();

# make the membership info quickly accessible
	my %index = ();
	my %powerset = ();
	for (my $setindex = 0; $setindex <= $#$setofsets; $setindex++) {
		my $set = $setofsets->[$setindex];
		for my $elem (@$set) {
			$index{$elem}->{$setindex} = 1;
			$powerset{$setindex}->{$elem} = 1;
		}
	}

# investigate which sets have to be merged
	my %setswithintersection = ();
	for my $elem (sort keys %index) {
		my @setindexes = sort keys %{$index{$elem}};
		if (scalar(@setindexes) > 1) {
			for my $setindex (@setindexes) {
				$setswithintersection{$setindex} = 1;
			}
		}
	}

# merge the sets that need it in situ
	for (my $setindex = 0; $setindex <= $#$setofsets; $setindex++) {
		$indexmap{$setindex} = $setindex;
	}
	for my $elem (sort keys %index) {
		my @setindexes = sort keys %{$index{$elem}};
		if (scalar(@setindexes) > 1) {
			#printf STDERR "Merging %s\n", join(",", @setindexes);
			my ($target, @sources) = @setindexes;
			my $realtarget = $indexmap{$target};
			for my $source (@sources) {
				my $realsource = $indexmap{$source};
				if ($realsource == $realtarget) {
					next;
				}
				#printf "\ttarget = %d => %d; source = %d => %d\n", $target, $realtarget, $source, $realsource;
				push @{$setofsets->[$realtarget]}, @{$setofsets->[$realsource]};
				$setofsets->[$realsource] = undef;
				reduce($setofsets->[$realtarget]);
				for my $si (keys %indexmap) {
					if ($indexmap{$si} == $realsource) {
						$indexmap{$si} = $realtarget;
					}
				}
			}
		}
	}

# filter the empty subsets
	my @newsetofsets = ();
	for my $set (@$setofsets) {
		if (scalar @$set) {
			push @newsetofsets, $set;
		}
	}
	$_[0] = \@newsetofsets;
}

sub reduce {
	my ($set) = @_;
	my %setf = ();
	for my $elem (@$set) {
		$setf{$elem} = 1;
	}
	my @newset = ();
	for my $elem (sort keys %setf) {
		push @newset, $elem;
	}
	$_[0] = \@newset;
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

# update the link num
		$linknum{$passage}->{$clusternum}->{$curcount}->{$word}++;
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

# determine the leftcontext of each cluster occurrence
	my $curleftcontext = '#';
	my @leftcontext = ();
	for (my $i = 0; $i <= $#clustersequence; $i++) {
		push @leftcontext, $curleftcontext;
		my ($context, $relativeweight) = @{$clustersequence[$i]};
		if ($relativeweight > $skeletonthreshold) {
			$curleftcontext = $context;;
		}
		else {
			$curleftcontext .= '*';
		}
	}
# determine the rightcontext of each cluster occurrence
	my $currightcontext = '#';
	my @rightcontext = ();
	for (my $i = $#clustersequence; $i >= 0; $i--) {
		unshift @rightcontext, $currightcontext;
		my ($context, $relativeweight) = @{$clustersequence[$i]};
		if ($relativeweight > $skeletonthreshold) {
			$currightcontext = $context;
		}
		else {
			$currightcontext = '*'.$currightcontext;
		}
	}
# now fill the global context datastructure
	for (my $i = 0; $i <= $#clustersequence; $i++) {
		my $leftcontext = $leftcontext[$i];
		my $rightcontext = $rightcontext[$i];
		my ($clusterocc, $relativeweight) = @{$clustersequence[$i]};
		$context{$passage}->{$clusterocc}->{"$leftcontext-$rightcontext"}++;
	}
# fill the auxiliary datastructure for context merging
	for my $clusterocc (keys %{$context{$passage}}) {
		my $ncontexts = 0;
		my $contextinfo = $context{$passage}->{$clusterocc};
		for my $context (keys %$contextinfo) {
			$ncontexts += $contextinfo->{$context};
		}
		for my $context (keys %$contextinfo) {
			my $thisncontexts = $context{$passage}->{$clusterocc}->{$context};
			$icontext{$passage}->{$context}->{$clusterocc} = $thisncontexts / $ncontexts;
		}
	}
}

sub mergecluster {
	my $passage = shift;
	my $mergeinstructions = $mergedclusteroccs{$passage};
	if (!defined $mergeinstructions) {
		return;
	}
	for my $mergeinstruction (@$mergeinstructions) {
		my ($targetclusterocc, @sourceclusteroccs) = @$mergeinstruction;
		my ($tnum, $tocc) = $targetclusterocc =~ m/^([^#]+)#(.*)$/;
		for my $sourceclusterocc (@sourceclusteroccs) {
			my ($snum, $socc) = $sourceclusterocc =~ m/^([^#]+)#(.*)$/;

# (1a) weight
			$masterbag{$passage}->{$tnum}->{$tocc} += $masterbag{$passage}->{$snum}->{$socc};
			delete $masterbag{$passage}->{$snum}->{$socc};
			if (!scalar(keys(%{$masterbag{$passage}->{$snum}}))) {
				delete $masterbag{$passage}->{$snum};
			}

# (1a) masterbag
			$weight{$passage}->{$targetclusterocc} += $weight{$passage}->{$sourceclusterocc};
			delete $masterbag{$passage}->{$sourceclusterocc};

# (2, 3) linkto and linkfrom
			my $linkfrom_s = $linkfrom{$passage}->{$snum}->{$socc};
			for my $source (keys %$linkfrom_s) {
				for my $pos (keys %{$linkfrom_s->{$source}}) {
					my $val = $linkfrom_s->{$source}->{$pos};
					$linkto{$passage}->{$source}->{$pos} = [$tnum, $tocc];
					$linkfrom{$passage}->{$tnum}->{$tocc}->{$source}->{$pos} = 1;
				}
			}
			delete $linkfrom{$passage}->{$snum}->{$socc};
			if (!scalar(keys(%{$linkfrom{$passage}->{$snum}}))) {
				delete $linkfrom{$passage}->{$snum};
			}

# (4) linknum

			my $linknum_s = $linknum{$passage}->{$snum}->{$socc};
			for my $word (keys %$linknum_s) {
				$linknum{$passage}->{$tnum}->{$tocc}->{$word} = $linknum_s->{$word};
			}
			delete $linknum{$passage}->{$snum}->{$socc};
			if (!scalar(keys(%{$linknum{$passage}->{$snum}}))) {
				delete $linknum{$passage}->{$snum};
			}
		}
	}
}

sub readsource {
	print STDERR "reading the sources ...\n";
	if (!open(INF, "<:encoding(UTF-8)", $filein)) {
		print STDERR "Cannot read file [$filein]\n";
		return 0;
	}
	my $cursource;
	my $nsources = 0;
	my $nwords = 0;
	my $sourcepassages = 0;
	while (my $line = <INF>) {
		chomp $line;
		if (substr($line, 0, 1) eq '!') {
			my @fields = split /\t/, $line;
			$cursource = $fields[1];
			$nsources++;
			printf STDERR "\r\t%d #%d (%d): %s          ", $nsources, $nwords, $sourcepassages, $cursource;
			next;
		}
		my ($passage, $passagetext) = $line =~ m/^([0-9]+)\tSRC=(.*)$/;
		if (!defined $passage) {
			next;
		}
		if (defined $selectpassage and $selectpassage != $passage) {
			next;
		}
		$sourcepassages++;
		my @words = split /[ ·]+/, $passagetext;
		for my $word (@words) {
			$words{$word}++;
		}
		$nwords += scalar @words;
		$sources{$passage}->{$cursource} = \@words;
	}
	close INF;
	printf STDERR "\nnumber of sources: %d\n", $nsources; 
	printf STDERR "number of source passages: %d\n", $sourcepassages; 
	printf STDERR "number of words: %d (%d different ones)\n", $nwords, scalar(keys(%words)); 
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

sub test {
	my $start = 600;
	my $diff = 20;
	for (my $i = $start + 0; $i <= $start + $diff; $i++) {
		for (my $j = $start + $diff; $j > $i; $j--) {
			my $w1 = $preparedwords[$i];
			my $w2 = $preparedwords[$j];
			printf STDERR "[%d,%d] %s <=(%d)=%f=> %s\n", $i, $j, join('', @$w1), LCS_length($w1, $w2), wordsim($w1, $w2), join('', @$w2); 
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
	printf STDERR "Computing clusters ...\n";
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

sub writeclustermerge {
	printf STDERR "Writing cluster merge info to file ...\n";
	if (!open(INF, ">:encoding(UTF-8)", $infomergefile)) {
		print STDERR "Cannot write file [$infomergefile]\n";
		return 0;
	}
	for my $passage (sort {$a <=> $b} keys %mergedclusteroccs) {
		printf INF "[%d]\n", $passage;
		my $mergeinfo = $mergedclusteroccs{$passage};
		for my $set (@$mergeinfo) {
			printf INF "\t%s\n", join(", ", @$set);
		}
	}
	close INF;
}

sub writelinknums {
	printf STDERR "Writing link numbers to file ...\n";
	if (!open(INF, ">:encoding(UTF-8)", $infonumfile)) {
		print STDERR "Cannot write file [$infonumfile]\n";
		return 0;
	}
	for my $passage (sort {$a <=> $b} keys %linknum) {
		printf INF "[%d]\n", $passage;
		my $passageinfo = $linknum{$passage};
		for my $clusternum (sort {$a <=> $b} keys %$passageinfo) {
			my $clusterinfo = $passageinfo->{$clusternum};
			for my $clustercount (sort {$a <=> $b} keys %$clusterinfo) {
				my $wordinfo = $clusterinfo->{$clustercount};
				printf INF "\t{%d # %d}\n", $clusternum, $clustercount;
				for my $word (sort keys %$wordinfo) {
					printf INF "\t\t%s : %d x\n", $word, $wordinfo->{$word};
				}
			}
		}
	}
	close INF;
}

sub writecollat {
	my $version = shift;
	my $infocollatversionfile = sprintf $infocollatfile, $version;
	printf STDERR "Writing collation $version to file ...\n";
	if (!open(INF, ">:encoding(UTF-8)", $infocollatversionfile)) {
		print STDERR "Cannot write file [$infocollatversionfile]\n";
		return 0;
	}
	for my $passage (sort {$a <=> $b} keys %sources) {
		printf INF "[%d]\n", $passage;
		my $passageinfo = $sources{$passage};
		for my $source (sort keys %$passageinfo) {
			printf INF "%-15s|", $source;
			my $textinfo = $passageinfo->{$source};
			for (my $i = 0; $i <= $#$textinfo; $i++) {
# look up related info for this word occurrence
				my $word = $textinfo->[$i];
				my ($clusternumber, $occurrencenumber) = @{$linkto{$passage}->{$source}->{$i}};
# the weight counts in how many sources this exact word occurs and is linked to this cluster occurrence
				my $weight = $linknum{$passage}->{$clusternumber}->{$occurrencenumber}->{$word};
				printf INF "%d#%d %s %dx|", $clusternumber, $occurrencenumber, $word, $weight;
			}
			printf INF "\n";
		}
	}
	close INF;
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
		printf INF "[%d] |", $passage;
		my $passageinfo = $masterbag{$passage};
		for my $clusternum (sort {$a <=> $b} keys %$passageinfo) {
			my $clusterinfo = $passageinfo->{$clusternum};
			for my $clustercount (sort {$a <=> $b} keys %$clusterinfo) {
# the weight counts how many surface word occurrences in the sources are linked to this cluster occurrence
				my $weight = $clusterinfo->{$clustercount};
				my $word = $clusters[$clusternum]->[0];
				printf INF "%d#%d %s x%d|", $clusternum, $clustercount, $word, $weight;
			}
		}
		print INF "\n";
	}
	close INF;
}

sub writecontexts {
	printf STDERR "Writing contexts to file ...\n";
	if (!open(INF, ">:encoding(UTF-8)", $infocontextfile)) {
		print STDERR "Cannot write file [$infocontextfile]\n";
		return 0;
	}
	for my $passage (sort {$a <=> $b} keys %context) {
		printf INF "[%d]\n", $passage;
		my $passageinfo = $context{$passage};
		for my $clusterocc (sort keys %$passageinfo) {
			printf INF "\t%s @ %f\n", $clusterocc, $weight{$passage}->{$clusterocc};
			my $contexts = $passageinfo->{$clusterocc};
			for my $context (sort keys %$contexts) {
				printf INF "\t\t%-15s x %d @ %f\n", $context, $contexts->{$context}, $icontext{$passage}->{$context}->{$clusterocc};
			}
		}
	}
	close INF;
}

sub dummy {
	1;
}

sub main {
	if (!readsource()) {
		return 0;
	}
	preparewords();
	if (!readclusters()) {
		cluster();
		writeclusters();
	}
	prepareclusters();
	makemasters();
	writelinknums();
	writecollat(1);
	writemaster(1);
	computecontexts();
	writecontexts();
	mergeclusters();
	writeclustermerge();
	writecollat(2);
	writemaster(2);
	return 1;
}

exit !main();
