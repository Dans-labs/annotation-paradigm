#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my $corpus_acro = 'huyg003';
my $keyword_auto = 'CKCC-auto';
my $topic_auto = 'LDA-auto';
my $weight_threshold = 0.1;

my %researchers = (
    dvm => 'Dirk van Miert',
    edh => 'Egbert de Haan',
    ej  => 'Erik Jorink',
    ejb => 'Erik-Jan Bos',
    hz  => 'Huib Zuidervaart',
    xx  => 'unknown',
);

my ($cannot_create_template, $topic_create_template, $data_dir, $id_map, $sql_dump) = @ARGV;

if (!open(ST, "<:encoding(UTF-8)", $topic_create_template)) {
	print STDERR "Can't read file [$topic_create_template]\n";
	exit 1;
}
if (!open(SA, "<:encoding(UTF-8)", $cannot_create_template)) {
	print STDERR "Can't read file [$cannot_create_template]\n";
	exit 1;
}
if (!open(I, "<:encoding(UTF-8)", $id_map)) {
	print STDERR "Can't read file [$id_map]\n";
	exit 1;
}
if (!open(G, ">:encoding(UTF-8)", $sql_dump)) {
	print STDERR "Can't write to file [$sql_dump]\n";
	exit 1;
}
my @keywordmandatafiles = glob("$data_dir/labels-*.csv");
if (!scalar(@keywordmandatafiles)) {
	print STDERR "No keywordman data found in [$data_dir]\n";
	exit 1;
}
my @keywordautodatafiles = glob("$data_dir/keywords*.csv");
if (!scalar(@keywordautodatafiles)) {
	print STDERR "No keywordauto data found in [$data_dir]\n";
	exit 1;
}

if (!scalar(@keywordautodatafiles)) {
	print STDERR "No keywordauto data found in [$data_dir]\n";
	exit 1;
}

my @topicautobodyfiles = (
	['fr', "$data_dir/lda-results/fr/letterWordTopicCountsFile.txt"],
	['nl', "$data_dir/lda-results/nl/letterWordTopicCountsFile.txt"],
);
my @topicautowordsfiles = (
	['fr', "$data_dir/lda-results/fr/letterTopicKeysFile.txt"],
	['nl', "$data_dir/lda-results/nl/letterTopicKeysFile.txt"],
);
my @topicautotargetfiles = (
	['fr', "$data_dir/lda-results/fr/letterTopicsFile.txt"],
	['nl', "$data_dir/lda-results/nl/letterTopicsFile.txt"],
);


sub sq {
	$_[0] =~ s/'/''/g;
	return $_[0];
}

my @lines;
my $create;

@lines = <ST>;
close ST;
$create = join '', @lines;
$create =~ s/\$\{db\}/topic/sg;
print G $create;

@lines = <SA>;
close SA;
$create = join '', @lines;
$create =~ s/\$\{db\}/cannot/sg;
print G $create;

sub dummy {
	1;
}

my $annot_id = 0;
my $target_id = 0;

my %annots = ();
my %targets = (
	letter => {},
	topic => {},
);
my %words = ();
my %wordsfiltered = ();
my %topicbodies = ();
my %topicwords = ();
my %topicidoffset = ();
my %wordidoffset = ();

my $rlines = 0;

for my $file (sort @keywordmandatafiles) {
	my ($fname) = $file =~ m/([^\/]*)\.csv$/;
	printf STDERR "%-10s\n", $fname;
	if (!open(FW, "<:encoding(UTF-8)", $file)) {
		print STDERR "\nCan't read file [$file]\n";
	}
    while (my $line = <FW>) {
        my ($mat) = $line =~ m/^$corpus_acro\/([^#]*);#/;
        if (!defined $mat) {
            next;
        }
        $rlines++;
        my ($lid, $res, @words) = split /;/, $mat;
        my $researcher = $researchers{lc($res)};
        if (!defined $researcher) {
            printf STDERR "Researcher [$res] not in table\n";
            $researcher = "XX";
        }
        for my $word (@words) {
            $annots{keyword}->{manual}->{$researcher}->{$word}->{$lid}++;
        }
    }
	close FW;
}
printf STDERR "%-4d %s\n", $rlines, 'relevant keywordman lines';

$rlines = 0;

for my $file (sort @keywordautodatafiles) {
	my ($fname) = $file =~ m/([^\/]*)\.csv$/;
	printf STDERR "%-10s\n", $fname;
	if (!open(FW, "<:encoding(UTF-8)", $file)) {
		print STDERR "\nCan't read file [$file]\n";
	}
    while (my $line = <FW>) {
		chomp $line;
		$line =~ s/\r//g;
        my ($mat) = $line =~ m/^$corpus_acro\/(.*)/;
        if (!defined $mat) {
            next;
        }
        $rlines++;
        my ($lid, @words) = split /;/, $mat;
        for my $word (@words) {
            $annots{keyword}->{auto}->{$keyword_auto}->{$word}->{$lid}++;
        }
    }
	close FW;
}
printf STDERR "%-4d %s\n", $rlines, 'relevant keywordauto lines';

$rlines = 0;

my $maxtopicid = -1;
my $maxwordid = -1;
for my $item (@topicautobodyfiles) {
	my ($kind, $file) = @$item;
	$topicidoffset{$kind} = $maxtopicid + 1;
	$wordidoffset{$kind} = $maxwordid + 1;
	if (!open(FW, "<:encoding(UTF-8)", $file)) {
		print STDERR "\nCan't read file [$file]\n";
	}
    while (my $line = <FW>) {
		$rlines++;
		chomp $line;
		my @fields = split / /, $line;
		my $word_id = shift @fields;
		my $word = shift @fields;
		my $cword_id = $word_id + $wordidoffset{$kind};
		if ($maxwordid < $cword_id) {
			$maxwordid = $cword_id;
		}
		$words{$kind}->{$word} = $cword_id;
		for my $fl (@fields) {
			my ($topic_id, $weight) = split /:/, $fl;
			my $ctopic_id = $topic_id + $topicidoffset{$kind};
			$topicbodies{$ctopic_id}->{$cword_id} = $weight;
			if ($maxtopicid < $ctopic_id) {
				$maxtopicid = $ctopic_id;
			}
		}
    }
	close FW;
}

printf STDERR "Total %d topics from %d words\n", scalar(keys(%topicbodies)), $rlines;

my $nwords = 0;

$rlines = 0;

for my $item (@topicautowordsfiles) {
	my ($kind, $file) = @$item;
	if (!open(FW, "<:encoding(UTF-8)", $file)) {
		print STDERR "\nCan't read file [$file]\n";
	}
    while (my $line = <FW>) {
		$rlines++;
		chomp $line;
		my @fields = split /\t/, $line;
		my $topic_id = shift @fields;
		my $fraction = shift @fields;
		my $wordstr = shift @fields;
		my @words = split / /, $wordstr;
		my $ctopic_id = $topic_id + $topicidoffset{$kind};
		$topicwords{$ctopic_id} = [$kind, \@words];
		$nwords += scalar @words;
    }
	close FW;
}

printf STDERR "Total %d words for %d topics\n", $nwords, $rlines;

my %f2i = ();
while (my $line = <I>) {
	chomp $line;
	my ($fname, $m_id) = split /\t/, $line;
	$f2i{$fname} = $m_id;
}
close I;

$rlines = 0;

my $ntarget = 0;
for my $item (@topicautotargetfiles) {
	my ($kind, $file) = @$item;
	if (!open(FW, "<:encoding(UTF-8)", $file)) {
		print STDERR "\nCan't read file [$file]\n";
	}
    while (my $line = <FW>) {
		$rlines++;
		chomp $line;
		my @fields = split / /, $line;
		shift @fields;
		my $corpletter = shift @fields;
		my ($corp,$letter) = split /_/, $corpletter;
		if ($corp ne $corpus_acro) {
			next;
		}
		my $mletter = $f2i{$letter};
		if (!defined $mletter) {
			printf STDERR "\nCannot map file name [%s] unto an id\n", $letter;
			next;
		}
		printf STDERR "\r%-10s => %-10s", $letter, $mletter;
		$ntarget++;
		while (scalar @fields) {
			my $topic_id = shift @fields;
			my $ctopic_id = $topic_id + $topicidoffset{$kind};
			my $weight = shift @fields;
			if ($weight >= $weight_threshold) {
            	$annots{topic}->{auto}->{$topic_auto}->{"#$weight#$ctopic_id"}->{$mletter}++;
			}
		}
    }
	close FW;
}

printf STDERR "\nTotal %d topictargets from %d lines\n", $ntarget, $rlines;

my @twlines;

my $ewords = 0;

for my $topic_id (sort {$a <=> $b} keys %topicbodies) {
	push @twlines, sprintf("insert into topic (id) values (%d);\n", $topic_id);
    my $all_word_ids = $topicbodies{$topic_id};
	my ($kind, $topic_words) = @{$topicwords{$topic_id}};
	my $topictotalweight = 0;
	my @topicdata = ();
	for my $word (@$topic_words) {
		my $word_id = $words{$kind}->{$word};
		if (!defined $word_id) {
			printf STDERR "\nInconsistency for topic [%d]: word [%s] has no id\n", $topic_id, $word;
			$ewords++;
			next;
		}
		my $weight = $all_word_ids->{$word_id};
		if (!defined $weight) {
			printf STDERR "\nInconsistency for topic [%d]: word [%s] (%d) has no weight\n", $topic_id, $word, $word_id;
			$ewords++;
			next;
		}
		$topictotalweight += $weight;
		$wordsfiltered{$word_id} = $word;
		push @topicdata, [$topic_id, $word_id, $weight];
	}
	for my $record (@topicdata) {
		my $weight = $record->[2];
		my $nweight = int((100 * $weight / $topictotalweight) + 0.5);
		$record->[2] = $nweight;
        push @twlines, sprintf("insert into topic_word (topic_id,word_id,weight) values (%d,%d,%d);\n", @$record);
	}
}

printf G "use topic;\n";

for my $word_id (sort {$a <=> $b} keys %wordsfiltered) {
	printf G "insert into word (id, word) values (%d,'%s');\n", $word_id, sq($wordsfiltered{$word_id});
}

print G @twlines;

printf STDERR "Total %d words assigned to %d topics; %d words could not be assigned\n", scalar(keys(%wordsfiltered)), scalar(keys(%topicbodies)), $ewords;

print STDERR "Generating SQL for annotations ...\n";

printf G "use cannot;\n";

# $annots{topic}->{auto}->{$topic_auto}->{"#$weight#$ctopic_id"}->{$letter}++;
my %stats = ();
for my $type (sort keys %annots) {
	print STDERR "$type\n";
    my $stypes = $annots{$type};
    for my $stype (sort keys %$stypes) {
	    print STDERR "\t$stype\n";
        my $ress = $stypes->{$stype};
        for my $res (sort keys %$ress) {
            print STDERR "$res\n";
            my $bodies = $ress->{$res};
            for my $body (sort keys %$bodies) {
                $stats{"$type-$stype-annots"}++;
                $stats{"total-annots"}++;
                print STDERR "\r\t$body\t\t\t";
                my $bodyrep = $body;
                my ($bodytext, $bodyinfo, $bodyref) = split /#/, $body;
                $bodytext = sq($bodytext);
                if (!defined $bodyinfo) {
                    $bodyinfo = '';
                }
                else {
                    $bodyinfo = sq($bodyinfo);
                }
                if (!defined $bodyref) {
                    $bodyref = '';
                }
                else {
                    $bodyref = sq($bodyref);
                }
                printf G "insert into annot (id, bodytext, bodyinfo, bodyref,metatype,metasubtype,metaresearcher,metadate_created) values (%d,'%s','%s','%s','%s','%s','%s','%d');\n", ++$annot_id, $bodytext, $bodyinfo, $bodyref, $type, $stype, sq($res), '2012-01-31';
                my $items = $bodies->{$body};
                for my $item (sort keys %$items) {
                    $stats{"$type-$stype-targets"}++;
                    $stats{"total-targets"}++;
                    printf G "insert into target (id,annot_id,anchor) values (%d,%d,'%s');\n", ++$target_id, $annot_id, sq($item);
                }
            }
            print STDERR "\n";
        }
    }
}

close G;

for my $stat (sort keys %stats) {
	printf STDERR "%-20s: %4d\n", $stat, $stats{$stat};
}

