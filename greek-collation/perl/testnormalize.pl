#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my $testset = [
	[1,2,3],
	[4,5,6],
	[7,8,9],
	[10,11,12],
	[4,8,13],
	[8,10,14],
	[15,16,17],
	[10,13,17],
	[18,19,20, 21],
	[22,23,24,25,13],
];

my $reducetest = [1,2,3,3,4,5,6,6,7,8];


my %indexmap = ();

sub normalize {
	my ($setofsets) = @_;

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
	printsets();
	for my $elem (sort keys %index) {
		my @setindexes = sort keys %{$index{$elem}};
		if (scalar(@setindexes) > 1) {
			printf STDERR "Merging %s\n", join(",", @setindexes);
			my ($target, @sources) = @setindexes;
			my $realtarget = $indexmap{$target};
			for my $source (@sources) {
				my $realsource = $indexmap{$source};
				if ($realsource == $realtarget) {
					next;
				}
				printf "\ttarget = %d => %d; source = %d => %d\n", $target, $realtarget, $source, $realsource;
				push @{$setofsets->[$realtarget]}, @{$setofsets->[$realsource]};
				$setofsets->[$realsource] = undef;
				reduce($setofsets->[$realtarget]);
				for my $si (keys %indexmap) {
					if ($indexmap{$si} == $realsource) {
						$indexmap{$si} = $realtarget;
					}
				}
				printsets();
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

sub printsets {
	my $i = 0;
	for my $set (@$testset) {
		printf STDERR "%d => %d\t[%s],\n", $i, $indexmap{$i}, join(",", @$set);
		$i++;
	}
}

#reduce($reducetest);
#printf STDERR "\t[%s],\n", join(",", @$reducetest);

normalize($testset);
printsets();
