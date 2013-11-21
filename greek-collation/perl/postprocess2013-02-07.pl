#!/usr/bin/perl

=head2 idea

Use collatex

=cut

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";
use JSON;

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my ($filein, $fileout, $bychar, $inputtype, $selectedverse) = @ARGV;

my $inputfileext;

sub dummy {
	1;
}

my %types = (
	json => {
		ext => 'json',
	},
	plain => {
		ext => 'txt',
	},
	svg => {
		ext => 'svg',
	},
);

my $input;
my $info;

my %nodelabel = ();
my %labelnode = ();
my %edgesin = ();
my %edgesout = ();
my %tedgesin = ();
my %tedgesout = ();
my $duplicatenodes = 0;
my $duplicatenodelabels = 0;
my $nedges = 0;
my $nsourceedges = 0;
my $ncedges = 0;

my %grid = ();

sub processsource {
	my $good = 1;

	for my $alignedfile (glob("$filein-verse-*.$inputfileext")) {
		my ($curverse) = $alignedfile =~ m/-verse-([^.]+)/;
		if (defined $selectedverse and $selectedverse ne $curverse) {
			next;
		}
		printf STDERR "\tverse %s\n", $curverse;
		if (!open(A, "<:encoding(UTF-8)", $alignedfile)) {
			print STDERR "Can't read file [$alignedfile]\n";
			return 0;
		}
		$input = undef;
		{local $/; $input = <A>};
		close A;
		my $prettyfile = sprintf "%s-verse-%s.%s.txt", $fileout, $curverse, $inputfileext;
		if (!open(P, ">:encoding(UTF-8)", $prettyfile)) {
			print STDERR "Can't write to file [$prettyfile]\n";
			return 0;
		}
		if ($inputtype eq 'json') {
			prettify_json();
		}
		elsif ($inputtype eq 'plain') {
			prettify_plain();
		}
		elsif ($inputtype eq 'svg') {
			print STDERR "No prettifying for svg implemented\n";
		}
		close P;
	}
	return $good;
}

sub prettify_plain {
	my @lines = split /\n/, $input;

	for my $line (@lines) {
		my ($node, $node1, $node2, $label, $sources);

#	nodes
#  	v13858 [label = "ιουδας"];

		($node, $label) = $line =~ m/^\s*(\S+)\s*\[label\s*=\s*"(.*)"\];\s*$/;
		if (defined $node) {
			if (exists $nodelabel{$node}) {
				$duplicatenodes++;
			}
			$nodelabel{$node} = $label;
			$labelnode{$label}->{$node}++;
			if ($labelnode{$label}->{$node} > 1) {
				$duplicatenodelabels++;
			}
			next;
		}

#	edges
#  	v13854 -> v13858 [label = "0142, 049, 056, 1, 1003, 101, 102, 1022, 103, 104, 1040, 105, 1058, 1066"];

		($node1, $node2, $sources) = $line =~ m/^\s*(\S+)\s*->\s*(\S+)\s*\[label\s*=\s*"(.*)"\];\s*$/;
		if (defined $node1) {
			$nedges++;
			my @sources = split /,\s*/, $sources;
			$nsourceedges += scalar(@sources);
			$edgesout{$node1}->{$node2} = \@sources;
			$edgesin{$node2}->{$node1} = \@sources;
			next;
		}

#	cycle edges
#   v13971 -> v14042 [color = "lightgray", style = "dashed" arrowhead = "none", arrowtail = "none" ];

		($node1, $node2) = $line =~ m/^\s*(\S+)\s*->\s*(\S+)\s*\[color[^]]*\];\s*$/;
		if (defined $node1) {
			$ncedges++;
			$tedgesout{$node1}->{$node2} = 1;
			$tedgesin{$node2}->{$node1} = 1;
			next;
		}
	}

# sanity checks and statistics;
	# nodes

	printf STDERR "Nodes: %d, labels %d\n", scalar(keys(%nodelabel)), scalar(keys(%labelnode));
	printf STDERR "Multiple node definitions: %d\n", $duplicatenodes;
	printf STDERR "Multiple node label definitions: %d\n", $duplicatenodelabels;

	# edges

	printf STDERR "Edges: %d, source edges %d\n", $nedges, $nsourceedges;

	# trans edges

	my @tlinks = ();
	for my $node1 (keys(%tedgesout)) {
		my $tedgesoutinfo = $tedgesout{$node1};
		for my $node2 (keys(%$tedgesoutinfo)) {
			push @tlinks, sprintf "%s -> %s", $nodelabel{$node1}, $nodelabel{$node2};
		}
	}
	for my $tlink (sort @tlinks) {
		printf STDERR "\t%s\n", $tlink;
	}
	
	print STDERR "Walk through the graph and make a grid of all sources\n";
	walkgraph();
	print STDERR "\n";
	writegrid();
}

sub walkgraph {
	my $givennode = shift;

# assume that there is a least node in the graph, i.e. from each node you can follow the incoming edges back,
# and what ever path you walk, you end up at the same node, the start node, or least node.
# find the least node first

	if (!defined $givennode) {
		my @keys = keys %edgesout;
		my $startnode = $keys[0];
		my $found = 0;
		while (!$found) {
			my $previous = $edgesin{$startnode};
			@keys = keys %$previous;
			if (!scalar(@keys)) {
				$found = 1;
			}
			else {
				$startnode = $keys[0];
			}
		}
		$givennode = $startnode;
	}

	for my $node (keys %{$edgesout{$givennode}}) {
		for my $source (@{$edgesout{$givennode}->{$node}}) {
			push @{$grid{$source}}, $node;
		}
	}
	for my $node (keys %{$edgesout{$givennode}}) {
		walkgraph($node);
	}
}

sub writegrid {
	print STDERR "Pretty printing the grid\n";
	for my $source (sort keys %grid) {
		printf P "%-12s", $source;
		my $sourceinfo = $grid{$source};
		my @words = ();
		for my $node (@$sourceinfo) {
			printf P " %s", $nodelabel{$node};
		}
		print P "\n";
	}
}

sub prettify_json {
	$info = from_json($input);
	my $sigils = $info->{sigils};
	my $table = $info->{table};
	my $colums = $info->{columns};
	my $rows = $info->{rows};
	my $rownum = 0;
	my %lines = ();
	my @colwidth = ();
	for my $row (@$table) {
		my $colnum = 0;
		for my $col (@$row) {
			my $source = $sigils->[$colnum];
			if (!ref $col) {
				$lines{$source}->[$rownum] = '';
			}
			else {
				my $chunk = '';
				for my $t (@$col) {
					if ($bychar) {
						$chunk .= $t->{t};
					}
					else {
						$chunk .= $t;
					}
				}
				$lines{$source}->[$rownum] = $chunk;
				$colwidth[$rownum] = max($colwidth[$rownum], length($chunk));
			}
			$colnum++;
		}
		$rownum++;
	}
	for my $source (sort keys %lines) {
		my $chunks = $lines{$source};
		printf P "%-15s|", $source;
		for (my $i = 0; $i < $#colwidth; $i++) {
			my $fmtstr = sprintf "%%-%ds|", $colwidth[$i];
			printf P $fmtstr, $chunks->[$i];
		}
		print P "\n";
	}
}

sub max {
	my ($n1, $n2) = @_;
	if ($n1 > $n2) {
		return $n1;
	}
	return $n2;
}

sub main {
	if (!exists $types{$inputtype}) {
		printf STDERR "Wrong inputtype [%s]. Should be one of (%s)\n", $inputtype, join(", ", sort(keys(%types)));
		return 0;
	}
	$inputfileext = $types{$inputtype}->{ext}; 
	if (!processsource()) {
		return 0;
	}
}

exit !main();
