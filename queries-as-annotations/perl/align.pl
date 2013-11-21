#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

use Algorithm::Diff qw(sdiff);

my ($wivu_nt, $westm_nt, $alignment) = @ARGV;

my @hebrew_cantillation = (
	hex("0591") .. hex("05AF"),
);
my @hebrew_point = (
	hex("05B0") .. hex("05BD"),
	hex("05BF"),
	hex("05C1"),
	hex("05C2"),
	hex("05C4"),
	hex("05C5"),
	hex("05C7"),
);
my @hebrew_punctuation = (
	hex("05BE"),
	hex("05C0"),
	hex("05C3"),
	hex("05C6"),
	hex("05F3"),
	hex("05F4"),
);

my @hebrew_letter = (
	hex("05D0") .. hex("05F2"),
),

my %hebrew_mark = ();
my %hebrew_punct = ();
my %hebrew_let = ();

for my $h (@hebrew_cantillation, @hebrew_point) {
	$hebrew_mark{$h} = 1;
}
for my $h (@hebrew_punctuation) {
	$hebrew_punct{$h} = 1;
}
for my $h (@hebrew_letter) {
	$hebrew_let{$h} = 1;
}

sub hchunk {
	my ($hstr) = @_;
	my @hchars = split //, $hstr;
	my @result = ();
	my $chunk = '';
	for my $hc (@hchars) {
		my $ho = ord($hc);
		if ($hebrew_mark{$ho}) {
			$chunk .= $hc;
			next;
		}
		if (length $chunk) {
			push @result, $chunk;
		}
		$chunk = $hc;
	}
	if (length $chunk) {
		push @result, $chunk;
	}
	return \@result;
}

sub hcmp {
	my ($hc) = @_;
	return substr $hc, 0, 1;
}

sub align {
	my ($sa, $sb) = @_;
	my @cmp = sdiff($sa, $sb, \&hcmp);
	my $result = '';
	my $pc = undef;
	my $pas = '';
	my $pbs = '';
	for my $cm (@cmp, [undef, '','']) {
		my ($c, $as, $bs) = @$cm;
		if ($c ne $pc) {
			if ($pas eq $pbs) {
				$result .= $pas;
			}
			else {
				$result .= sprintf "(%s|%s)", $pas, $pbs;
			}
			$pas = '';
			$pbs = '';
		}
		if ($c eq 'u' and $as ne $bs) {
			$pas .= "[$as~$bs]";
			$pbs .= "[$as~$bs]";
		}
		else {
			$pas .= $as;
			$pbs .= $bs;
		}
		$pc = $c;
	}
	return $result;
}

my %bk_id_acro = (
	1	=> 'gen',
	2	=> 'exo',
	3	=> 'lev',
	4	=> 'num',
	5	=> 'deu',
	6	=> 'jos',
	7	=> 'jud',
	8	=> 'sa1',
	9	=> 'sa2',
	10	=> 'ki1',
	11	=> 'ki2',
	12	=> 'isa',
	13	=> 'jer',
	14	=> 'eze',
	15	=> 'hos',
	16	=> 'joe',
	17	=> 'amo',
	18	=> 'oba',
	19	=> 'jon',
	20	=> 'mic',
	21	=> 'nah',
	22	=> 'hab',
	23	=> 'zep',
	24	=> 'hag',
	25	=> 'zec',
	26	=> 'mal',
	27	=> 'psa',
	28	=> 'job',
	29	=> 'pro',
	30	=> 'rut',
	31	=> 'can',
	32	=> 'ecc',
	33	=> 'lam',
	34	=> 'est',
	35	=> 'dan',
	36	=> 'ezr',
	37	=> 'neh',
	38	=> 'ch1',
	39	=> 'ch2',
);

my %bk_acro_id = ();
for my $id (keys %bk_id_acro) {
	$bk_acro_id{$bk_id_acro{$id}} = $id;
};

printf STDERR "%d books\n", scalar(keys(%bk_acro_id));

my %anchors = ();
my %aligned = ();

sub passsort {
	my ($bka, $cha, $vsa) = $a =~ m/^(...) ([^:]+):(.*)/;
	my ($bkb, $chb, $vsb) = $b =~ m/^(...) ([^:]+):(.*)/;
	my $bia = $bk_acro_id{$bka};
	my $bib = $bk_acro_id{$bkb};
	if ($bia == $bib) {
		if ($cha == $chb) {
			return $vsa <=> $vsb;
		}
		return $cha <=> $chb;
	}
	return $bia <=> $bib;
}

sub readanchors {
	my ($file, $key) = @_;
	if (!open(AF, "<:encoding(UTF-8)", $file)) {
		print STDERR "Can't read file [$file]\n";
		return 0;
	}
	print STDERR "reading $key normalised text ...\n";
	while (my $line = <AF>) {
		chomp $line;
		my ($pass, $text) = split /\t/, $line, 2;
		$anchors{$pass}->{$key} = $text;
	}
	close AF;
}

if (!open(A, ">:encoding(UTF-8)", $alignment)) {
	print STDERR "Can't write to file [$alignment]\n";
	exit 1;
}

if (!readanchors($wivu_nt, 'wivu')) {
	exit 1;
}
if (!readanchors($westm_nt, 'westm')) {
	exit 1;
}

print STDERR "sequencing ...\n";

for my $pass (sort passsort keys %anchors) {
	print STDERR "\r\t$pass ...\t\t";
	my $info = $anchors{$pass};
	my $both = 1;
	for my $var ('wivu', 'westm') {
		if (!exists $info->{$var}) {
			$both = 0;
			print STDERR "missing in $var\n";
		}
	}
	if (!$both) {
		for my $var ('wivu', 'westm') {
			if (exists $info->{$var}) {
				$aligned{$pass} = $info->{$var};
			}
		}
	}
	else {
		$aligned{$pass} = align(hchunk($info->{'wivu'}), hchunk($info->{'westm'}));
	}
}
print STDERR "\n";

print STDERR "writing ...\n";

for my $pass (sort passsort keys %aligned) {
	print STDERR "\r\t$pass ...\t\t";
	printf A "%s\t%s\n", $pass, $aligned{$pass};
}
print STDERR "\n";

close A;
