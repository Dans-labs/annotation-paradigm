#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my $testext = $ARGV[0];

my $basedir = "..";
my $destdir = "$basedir/datatrans";
my $modeldir = "$basedir/models";
my $numericfile = "$destdir/layersnumeric.txt";
my $createfile = "$modeldir/jude_create.sql";
my $sqlfile = "$destdir/layers.sql";
my $logfile = "$destdir/layersql.log";

my $contentchars = 'αβχδεφγηικλμνοπθρστυωξψζςϚ·,.;?:῀ῆῶ´ήώ᾿ὐ῾ὑ';

my $fmt_stat		= "%-2s %-39s: %7d\n";
my $fmt_stat_sh		= "%-2s %s\n";
my $fmt_stat_sub	= "    %-40s: %7d [%s]\n";
my $fmt_stat_fl		= "    %-40s: %7d\n";
my $fmt_stat_occ	= "        %-36s: %7d\n";

my %stat_chunking = (
	COMMENT => 2,
	TOTALS => 1,
);

my @statkinds = ('OK', 'I', 'W', 'E');
my %legalstatkind = ();
for my $kind (@statkinds) {
	$legalstatkind{$kind} = 1;
}

my %stats = ();
my %source = ();
my %statkind = ();
my $source;
my $wordnum;
my $createsql;

my %ids = (
	source => 0,
	passage => 0,
	layer => 0,
	layerdata => 0,
	word => 0,
);

my %textfields = (
	source => [0, 1, 1, 1, 1],
	passage => [0, 1, 0],
	layer => [0, 1],
	layerdata => [0, 0, 0, 0, 0, 1],
	word => [0, 0, 0, 0, 1],
);

my %records = (
	source => [],
	passage => [],
	layer => [],
	layerdata => [],
	word => [],
);

my %index = (
	passage => {},
	layer => {},
);

my %cur = (
	source => undef,
	passage => undef,
	layer => undef,
);

my @tableorder = (
	'layer',
	'passage',
	'source',
	'word',
	'layerdata',
);

if (!open(NF, "<:encoding(UTF-8)", $numericfile)) {
	print STDERR "Cannot read [$numericfile]\n";
	exit 1;
}
if (!open(SF, ">:encoding(UTF-8)", $sqlfile)) {
	print STDERR "Cannot write [$sqlfile]\n";
	exit 1;
}

sub gensql {
	if (!open(CF, "<:encoding(UTF-8)", $createfile)) {
		print STDERR "Cannot read [$createfile]\n";
		exit 1;
	}
	{local $/; $createsql = <CF>;}
	close CF;

	print STDERR "Reading information ...\n";

	my $lineno = 0;
	my $good = 1;
	while (my $line = <NF>) {
		#if ($lineno > 5) {
		#	last;
		#}
		$lineno++;
		chomp $line;
		if ($line eq '') {
			next;
		}
		if (substr($line, 0, 1) eq '!') {
			newsource(split('\t', $line));
			next;
		}
		my ($passage, $layer, $material) = $line =~ m/^([^\t]+)\t([^=]+)=(.*)/;
		if (!defined $passage) {
			print STDERR "Strange line $lineno [$line]\n";
			$good = 0;
			next;
		}
		my $seq = $passage;
		$seq =~ s/\D//g;
		checktable('passage', $passage, $seq);
		checktable('layer', $layer);
		newdata($material, $layer eq 'SRC');
	}

	print STDERR "\nWriting tables ...\n";
	writetables();
}

sub newsource {
	shift;
	my ($name, $period, $provenance, $remarks) = @_;
	my $table = 'source';
	my $records = $records{$table};
	my $id = ++$ids{$table};
    $wordnum = 0;
	print STDERR "\r$id - $name         ";
	push @$records, [$id, $name, $period, $provenance, $remarks];
	$cur{$table} = $id;
}

sub checktable {
	my $table = shift;
	my $value = shift;
	my $extra = shift;
	my $id = $index{$table}->{$value};
	if (!defined $id) {
		my $records = $records{$table};
		$id = ++$ids{$table};
		$index{$table}->{$value} = $id;
		if (defined $extra) {
			push @$records, [$id, $value, $extra];
		}
		else {
			push @$records, [$id, $value];
		}
	}
	$cur{$table} = $id;
}

sub newdata {
	my ($material, $issource) = @_;
	my ($pre, $newaddress, $newrest);
	my $rest = $material;
	my $address = 1;
	while (length($rest)) {
		($pre, $newaddress, $newrest) = $rest =~ m/^([^«]*)«([^»]+)»(.*)$/;
		if (!defined $newaddress) {
			if (length $rest) {
				newchunk($address, $rest, $issource);
			}
			$rest = '';
			last;
		}
		if (length($pre)) {
			newchunk($address, $pre, $issource);
		}
		$address = $newaddress;
		$rest = $newrest;
	}
}

sub newchunk {
	my ($address, $chunk, $issource) = @_;
	my $table = 'layerdata';
	my $tablew = 'word';
	my $records = $records{$table};
	my $recordsw = $records{$tablew};
	my $addressw = $address;

# build the word table with words and separators, only for the source layer
# assumption: every passage is just one chunk, no interjections of « » s.
	if ($issource) {
		my $rest = $chunk;
		while ($rest ne '') {
			my ($sep, $word, $newrest) = $rest =~ m/^([ ·]*)([^ ·]+)(.*)/;
			if (!defined $word) {
				if (length $sep) {
					push @$recordsw, [++$ids{$tablew}, $cur{source}, $addressw, undef, $sep];
					$addressw += length($sep);
				}
				$rest = '';
				last;
			}
			if (length $sep) {
				push @$recordsw, [++$ids{$tablew}, $cur{source}, $addressw, undef, $sep];
				$addressw += length($sep);
			}
			if (length $word) {
				push @$recordsw, [++$ids{$tablew}, $cur{source}, $addressw, ++$wordnum, $word];
				$addressw += length($word);
			}
			$rest = $newrest;
		}
	}

# build the character table
	for my $ch (split //, $chunk) {
		push @$records, [++$ids{$table}, $cur{source}, $cur{passage}, $cur{layer}, $address++, $ch];
	}
}

sub writetables {
	print SF $createsql;
	for my $table (@tableorder) {
		writetable($table);
	}
}

sub writetable {
	my $table = shift;
	print STDERR "Writing table [$table] ...\n";
	my $sep = '  ';
	print SF "insert into $table values \n";
	my $nrecords = 0;
	my $thisn = 0;
	my $period = 10000;
	for my $record (@{$records{$table}}) {
		if ($thisn == $period) {
			printf STDERR "\r\t$nrecords     ";
			print SF ";\n";
			print SF "insert into $table values \n";
			$thisn = 0;
			$sep = '  ';
		}
		print SF $sep;
		writerecord($table, $record);
		$sep = ', ';
		$nrecords++;
		$thisn++;
	}
	printf STDERR "\r\t$nrecords     \n";
	print SF ";\n\n";
}

sub writerecord {
	my ($table, $record) = @_;
	print SF '(';
	my $fsep = '';
	for (my $i = 0; $i <= $#$record; $i++) {
		print SF $fsep;
		$fsep = ',';
		if (!defined $record->[$i]) {
			print SF 'null';
		}
		else {
			if ($textfields{$table}->[$i]) {
				print SF sq($record->[$i]);
			}
			else {
				print SF $record->[$i];
			}
		}
	}
	print SF ")\n";
}

sub sq {
	my $text = shift;
	$text =~ s/'/''/sg;
	return "'".$text."'";
}

sub source_stat {
	my ($kind, $stat, $substat, $increment) = @_;
	if (!defined $increment) {
		$increment = 1;
	}
	$stats{$stat}->{$substat} += $increment;
	$source{$stat}->{$substat}->{$source}++;
	my $existingkind = $statkind{$stat};
	if (defined $existingkind and $existingkind ne $kind) {
		print STDERR "!!! Redefining kind for $stat: $existingkind => $kind\n";
	}
	if (!exists $legalstatkind{$kind}) {
		print STDERR "!!! Illegal statistics kind [$kind]\n";
	}
	$statkind{$stat} = $kind;
}

sub dummy {
	1;
}

gensql();

print STDERR "\n";

if (!open(LF, ">:encoding(UTF-8)", $logfile)) {
	print STDERR "\ncannot write $logfile\n";
	return;
}

my %statreport = ();

for my $stat (sort keys %stats) {
	my $kind = $statkind{$stat};
	my $report = '';
	my $filereport = '';
	my $compact = $stat_chunking{$stat};
	$filereport .= sprintf $fmt_stat_sh, $kind, $stat;
	my $substats = $stats{$stat};
	my $firstsubstat;
	my $firstsource;
	my $nstat = 0;
	my $thisreport = '';
	for my $substat (sort keys %$substats) {
		if (!defined $firstsubstat) {
			$firstsubstat = $substat;
		}
		my $substatinfo = $substats->{$substat};
		my $sourceinfo = $source{$stat}->{$substat};
		my @sources = sort keys %$sourceinfo;
		my $firstw = $sources[0];
		if (!defined $firstsource) {
			$firstsource = $firstw;
		}
		if ($compact != 2) {
			$thisreport .= sprintf $fmt_stat_sub, $substat, $substatinfo, $sources[0];
		}
		$filereport .= sprintf $fmt_stat_fl, $substat, $substatinfo;
		if ($compact != 1) {
			for my $w (@sources[0 .. $#sources]) {
				$filereport .= sprintf $fmt_stat_occ, $w, $sourceinfo->{$w};
				$nstat += $sourceinfo->{$w};
			}
		}
	}
	$report .= sprintf $fmt_stat, $kind, $stat, $nstat, $firstsource, $source{$stat}->{$firstsubstat};
	$report .= $thisreport;
	push @{$statreport{$kind}}, [$report, $filereport]; 
}

print STDERR "\n";

for my $kind (@statkinds) {
	for my $item (@{$statreport{$kind}}) {
		my ($report, $filereport) = @$item;
		print STDERR $report, "\n";
		print LF $filereport, "\n";
	}
}

close LF;
close NF;
close SF;
