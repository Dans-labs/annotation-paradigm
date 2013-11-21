#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

use DBI;

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my ($resultout) = @ARGV;

my %database = (
	db => 'jude',
	usr => 'root',
	pwd => 'dipre207',
);

my $resultpath = "$resultout-%s.txt";

my %sindex = ();

sub readsourcesql {
	my $good = 1;
	for (1) {
		my $rows = sql("
	select
		source.id, source.name
	from
		source
	");
		if (!$rows) {
			$good = 0;
			next;
		}

		while (my @row = &$rows()) {
			my ($source_id, $source_name) = @row;
			if (!exists $sindex{$source_name}) {
				$sindex{$source_name} = $source_id;
			}
            else {
                printf STDERR "Duplicate source name: [%s], with ids %d and %d]\n", $source_name, $source_id, $sindex{$source_name};
                $good = 0;
            }
		}
	}
	return $good;
}

sub writeindex {
	my $good = 1;
    my $infopath = sprintf $resultpath, 'source';
    printf STDERR "\twriting %s index to file\n", 'source';
    if (!open(CI, ">:encoding(UTF-8)", $infopath)) {
        print STDERR "Cannot write file [$infopath]\n";
        $good = 0;
        next;
    }
    for my $name (sort keys %sindex) {
        printf CI "%s\t%d\n", $name, $sindex{$name};
    }
    close CI;
	return $good;
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

sub dummy {
	1;
}

sub main {
	my $good = 1;
	for (1) {
		if (!readsourcesql()) {
			$good = 0;
			next;
		}
		writeindex();
	}
	return $good;
}

exit !main();
