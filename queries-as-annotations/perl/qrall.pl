#!/usr/bin/perl

=head2 USAGE

qr.pl query_file_dir results_file_dir

=cut

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my $annot_id = 0;
my $body_id = 0;
my $meta_id = 0;
my $target_id = 0;

my ($data_dir, $anchor_file, $query_in_dir, $result_in_dir, $sql_file) = @ARGV;

if (!open(S, ">>:encoding(UTF-8)", $sql_file)) {
	print STDERR "Can't write to file [$sql_file]";
	exit 1;
}
if (!open(A, "<:encoding(UTF-8)", $anchor_file)) {
	print STDERR "Can't read file [$anchor_file]";
	exit 1;
}

my %anchors = ();
printf STDERR "%s\n", "Reading anchors";
while (my $line = <A>) {
	chomp $line;
	my ($anch, $wnum) = split /\t/, $line;
	$anchors{$wnum} = $anch;
}
close A;

sub rerunquery {
	my $good = 1;
	my ($qpath, $rpath) = @_;
	system "mql -b 3 -d $data_dir --xml $qpath > $rpath";
	if( $@) {
		printf STDERR "msg=[%s]", $@;
		$good = 0;
	}
	return $good;
}

sub main {
	my @files = glob("$query_in_dir/*.mql");
	my $good = 1;
	for my $qpath (@files) {
		my ($qname) = $qpath =~ m/([^\/]*)$/;
		my $rname = $qname;
		$rname =~ s/^bh_//;
		$rname =~ s/\.mql$/.xml/;
		my $rpath = "$result_in_dir/$rname";
		my $needrerun = -M $rpath > -M $qpath;
		printf STDERR "\rprocessing %s ... ", $qname;
		if ($needrerun) {
			printf STDERR "\rrerunning %s ... ", $qname;
			my $thisgood = rerunquery($qpath, $rpath);
			if (!$thisgood) {
				$good = 0;
				printf STDERR "ERROR\n";
			}
			else {
				print STDERR "OK";
			}
		}
		my $thisgood = makequerysql($qpath, $rpath);
		if (!$thisgood) {
			$good = 0;
			printf STDERR "ERROR\n";
		}
		else {
			print STDERR "OK";
		}
	}
	print STDERR "\n";
	close S;
	return $good;
}

sub dummy {
	1;
}

sub makequerysql {
	my ($query_in, $results_in) = @_;

	if (!open(Q, "<:encoding(UTF-8)", $query_in)) {
		print STDERR "Can't read file [$query_in]\n";
		return 0;
	}
	if (!open(R, "<:encoding(UTF-8)", $results_in)) {
		print STDERR "Can't read file [$results_in]\n";
		return 0;
	}

	my @lines;

# read the query file in which the body and the metadata reside and create sql for the tables
# annot, body, metareocrd, annot_body, annot_meta 

	@lines = <Q>;
	my $qtext = join '', @lines;
	my ($pre, $qbody) = split /\/\/==========\n/s, $qtext;

	$qbody =~ s/'/''/g;
	print S "-- new annotation --\n";
	printf S "insert into annot (id) values (%d);\n", ++$annot_id;

	print S "-- body of annotation --\n";
	printf S "insert into body (id, text) values (%d,'%s');\n", ++$body_id, $qbody;

	printf S "insert into annot_body (annot_id, body_id) values (%d,%d);\n", $annot_id, $body_id;

	my ($meta) = $pre =~ m/<metadata>(.*?)<\/metadata>/s;
	my (@metadata) = $meta =~ m/(<meta.*?(?:\/>|<\/meta>))/sg; 
	my %metarecord = ();
	for my $metafield (@metadata) {
		my ($name) = $metafield =~ m/<meta type="([^"]*)"/;
		my ($value) = $metafield =~ m/<meta [^>]*?value="([^"]*)"/;
		if (!defined $value) {
			($value) = $metafield =~ m/<meta [^>]*>(.*)<\/meta>/s;
		}
		$metarecord{$name} = $value;
	}
	print S "-- metadata of annotation --\n";
	print S "insert into metarecord (id, annot_type";
	for my $field (sort keys %metarecord) {
		print S ", $field";
	}
	printf S ") values (%d, 'query'", ++$meta_id;
	for my $field (sort keys %metarecord) {
		my $value = $metarecord{$field};
		$value =~ s/'/''/g;
		print S ", '$value'";
	}
	print S ");\n";

	printf S "insert into annot_meta (annot_id, metarecord_id) values (%d,%d);\n", $annot_id, $meta_id;

# read the results file and create sql for the tables
# target, annot_target

	@lines = <R>;
	my $rtext = join '', @lines;

# results should be filtered for overlapping ranges

	print S "-- targets of annotation --\n";
	my (@results) = $rtext =~ m/(<matched_object.*?)<\/monad_set>/sg;
	my %resultindex = ();
	for my $result (@results) {
		my ($focus) = $result =~ m/<matched_object[^>]*focus="([^"]*)"/;
		if ($focus eq 'false') {
			next;
		}
		my ($first, $last) = $result =~ m/<mse first="([^"]*)" last="([^"]*)"/;
		for my $i ($first .. $last) {
			$resultindex{$i} = 1;
		}
	}
	for my $word_num (sort {$a <=> $b} keys %resultindex) { 
		my $anch = $anchors{$word_num};
		printf S "insert into target (id, anchor) values (%d, '%s');\n", ++$target_id, $anch;
		printf S "insert into annot_target (annot_id, target_id) values (%d, %d);\n", $annot_id, $target_id;
	}
	print S "-- end of annotation --\n\n";

	close Q;
	close R;

	return 1;
}

exit !main();

