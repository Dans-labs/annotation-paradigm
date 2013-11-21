#!/usr/bin/perl

=head2 USAGE

qr.pl query_file_in results_file_in

=cut

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my ($query_in, $results_in, $last_ids) = @ARGV;

if (!open(Q, "<:encoding(UTF-8)", $query_in)) {
	print STDERR "Can't read file [$query_in]\n";
	exit 1;
}
if (!open(R, "<:encoding(UTF-8)", $results_in)) {
	print STDERR "Can't read file [$results_in]\n";
	exit 1;
}

binmode(STDOUT, ":utf8");

sub dummy {
	1;
}

print STDERR "$query_in + $results_in = oannot \n";

my @lines;

my $annot_id = 0;
my $body_id = 0;
my $meta_id = 0;
my $target_id = 0;

# read the current values of the relevant last inserted records

if (open(I, "<:encoding(UTF-8)", $last_ids)) {
	my $line = <I>;
	chomp $line;
	close I;
	($annot_id, $body_id, $meta_id, $target_id) = split /\t/, $line;
}

# read the query file in which the body and the metadata reside and create sql for the tables
# annot, body, metareocrd, annot_body, annot_meta 

@lines = <Q>;
my $qtext = join '', @lines;
my ($pre, $qbody) = split /\/\/==========\n/s, $qtext;

$qbody =~ s/'/''/g;
print "-- new annotation --\n";
printf "insert into annot (id) values (%d);\n", ++$annot_id;

print "-- body of annotation --\n";
printf "insert into body (id, text) values (%d,'%s');\n", ++$body_id, $qbody;

printf "insert into annot_body (annot_id, body_id) values (%d,%d);\n", $annot_id, $body_id;

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
print "-- metadata of annotation --\n";
print "insert into metarecord (id, annot_type";
for my $field (sort keys %metarecord) {
	print ", $field";
}
printf ") values (%d, 'query'", ++$meta_id;
for my $field (sort keys %metarecord) {
	my $value = $metarecord{$field};
	$value =~ s/'/''/g;
	print ", '$value'";
}
print ");\n";

printf "insert into annot_meta (annot_id, metarecord_id) values (%d,%d);\n", $annot_id, $meta_id;

# read the results file and create sql for the tables
# target, annot_target

@lines = <R>;
my $rtext = join '', @lines;

# results should be filtered for overlapping ranges

print "-- targets of annotation --\n";
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
	printf "insert into target (id, word_num) values (%d, %d);\n", ++$target_id, $word_num;
	printf "insert into annot_target (annot_id, target_id) values (%d, %d);\n", $annot_id, $target_id;
}
print "-- end of annotation --\n\n";

close Q;
close R;

# write the current values of the relevant last inserted records

if (open(I, ">:encoding(UTF-8)", $last_ids)) {
	print I join "\t", ($annot_id, $body_id, $meta_id, $target_id);
	close I;
}
else {
	print STDERR "Can't write file [$last_ids]\n";
	exit 1;
}

