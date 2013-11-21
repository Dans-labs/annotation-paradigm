#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my ($feature_file, $sql_dump1, $sql_dump2, $feature_info) = @ARGV;

if (!open(FW, "<:encoding(UTF-8)", $feature_file)) {
	print STDERR "Can't read file [$feature_file]\n";
	exit 1;
}
if (!open(G1, ">:encoding(UTF-8)", $sql_dump1)) {
	print STDERR "Can't write to file [$sql_dump1]\n";
	exit 1;
}
if (!open(G2, ">:encoding(UTF-8)", $sql_dump2)) {
	print STDERR "Can't write to file [$sql_dump2]\n";
	exit 1;
}
if (!open(GL, ">:encoding(UTF-8)", $feature_info)) {
	print STDERR "Can't write to file [$feature_info]\n";
	exit 1;
}
sub dummy {
	1;
}

my %feature = (
);

my %value = (
);

my %word_target = (
);

my %annot = ();
my $annot_start_id = 1000;
my $target_start_id = 10000;
my $max_inserts = 10000;

my $line;
my $wordn = 0;
my $targetn = 0;
my $targetfn = 0;
my $targetcn = 0;

while ($line = <FW>) {
    $wordn++;
	printf STDERR "%8d\t\r", $wordn;
    chomp $line;
    my ($word, $features) = split /\t/, $line;
    my @features = split ",", $features;
    for my $feature (@features) {
        push @{$annot{$feature}}, $word;
        $targetfn++;
    }
}
close FW;

my $curannot = $annot_start_id;
my $curbody = $annot_start_id;
my $curmeta = $annot_start_id;
my $curtarget = $target_start_id;

my %allfeatures = ();

print G1 "use oannot;\n";
print G2 "use oannot;\n";

for my $fv (sort keys %annot) {
    my $targets = $annot{$fv};
    my ($f, $v) = $fv =~ m/^([^=]+)="([^"]*)"$/;
	printf STDERR "%30s = %30s\t\r", $f, $v;
    my $desc = "$f: $feature{$f}. $v: $value{$v}.";
    $curannot++;
    $curbody++;
    $curmeta++;
    print G1 "-- new annotation --
insert into annot (id) values ($curannot);
-- body of annotation --
insert into body (id, text) values ($curbody,'$f=$v');
insert into annot_body (annot_id, body_id) values ($curannot,$curbody);
-- metadata of annotation --
insert into metarecord (id, annot_type, date_created, date_run, description, publications, research_question, researcher) values ($curmeta, 'feature', '2012-01-01', '', '$desc', '', 'tagging', 'WIVU');
insert into annot_meta (annot_id, metarecord_id) values ($curannot,$curmeta);
";
    my $g1targets = "-- new targets of annotation --\ninsert into target values\n";
	print G2 "-- new annotation --\ninsert into annot_target values\n";
	my $sep1 = "  ";
	my $sep2 = "  ";
	my $ntarget = 0;
    for my $word (@$targets) {
		if ($ntarget > $max_inserts) {
			$ntarget = 0;
			$g1targets .= ";\n";
			print G2 ";\n";
    		$g1targets .= "insert into target values\n";
			print G2 "insert into annot_target values\n";
			$sep1 = "  ";
			$sep2 = "  ";
		}
		$ntarget++;
        $allfeatures{$f}->{$v}++;
		my $thistarget = $word_target{$word};
		my $targetexists = 1;
		if (!defined $thistarget) {
        	$thistarget = $curtarget++;
			$word_target{$word} = $thistarget;
			$targetexists = 0;
		}
		if (!$targetexists) {
        	$g1targets .= "$sep1($thistarget, '$word')\n";
			$targetn++;
			$sep1 = ", ";
		}
		print G2 "$sep2($curannot, $thistarget)\n";
		$targetcn++;
		$sep2 = ", ";
    }
	$g1targets .= ";\n-- end of annotation --\n";
	print G2 ";\n-- end of annotation --\n";
	$g1targets =~ s/insert into target values\n;\n//sg;
	print G1 $g1targets;
}

for my $f (sort keys %allfeatures) {
    my $finfo = $allfeatures{$f};
    printf GL "%-20s\n", $f; 
    for my $v (sort keys %$finfo) {
        my $occ = $finfo->{$v};
        printf GL "%20s%-20s :%-6d\n", '', $v, $occ; 
    }
}

printf STDERR "\nTotal %d words; %d feature values; %d feature instances; %d target cross records; %d target records\n", $wordn, scalar(keys(%annot)), $targetfn, $targetcn, $targetn;

close G1;
close G2;
close GL;
