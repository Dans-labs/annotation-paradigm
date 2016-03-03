#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my $workdir = "/Users/dirk/SURFdrive/demos/apps/pa/data/TommyWasserman/Transkriptioner_kopior";
my $destdir = "/Users/dirk/SURFdrive/demos/apps/pa/datatrans/TommyWasserman/Transkriptioner_kopior";
my $logfile = "transform.log";
my $commentsoutfile = "comments.txt";
my $commentsinfile = "commentsfiltered.txt";

my %transtable = (
	a		=> 'α',
	b		=> 'β',
	c		=> 'χ',
	d		=> 'δ',
	e		=> 'ε',
	f		=> 'φ',
	g		=> 'γ',
	h		=> 'η',
	i		=> 'ι',
	k		=> 'κ',
	l		=> 'λ',
	m		=> 'μ',
	n		=> 'ν',
	o		=> 'ο',
	p		=> 'π',
	q		=> 'θ',
	r		=> 'ρ',
	s		=> 'σ',
	t		=> 'τ',
	u		=> 'υ',
	w		=> 'ω',
	x		=> 'ξ',
	y		=> 'ψ',
	z		=> 'ζ',
	'~'		=> 'ς',
	''	=> '?=#82',
	''	=> '?=#8c',
	''	=> '?=#8d',
	'§'		=> '?=P',
	'¯'		=> '?=S',
	'³'		=> 'FZY',	# previous letter partly visible (usually represented as a dot below the character in question)
	'¿'		=> '?=Q',
	'Â'		=> '?=A',
	'Ñ'		=> '?=N',
	'õ'		=> '?=O',
	'&'		=> '&',
	'0387'	=> '·',		# ano teleia
	','		=> ',',		# ano teleia
);

my %entitytable = (
	'Â'		=> 'lac', # lacuna
);

my %tagtable = (
	'*'			=> 'H', # first hand
	'*×'		=> 'Hx', # first hand and omission
	''		=> 'C', # corrector
	'×'		=> 'Cx',
	'1×'	=> 'C1x',
	'2'		=> 'C2',
	'2a'	=> 'C2a',
	'2b'	=> 'C2b',
	'2×'	=> 'C2x',
	'Á'			=> 'ILL', # illegible (see GA 02 Alexandrinus 87a 3 John 1 - Jude 12-1, on top of the page, title)
	'A'			=> 'A', # alternative reading
	'A×'		=> 'Ax',
	'A2'		=> 'A2',
	'K'			=> 'K', # commentary reading
	'T'			=> 'T', # question for Tommy: it looks as if T is first hand and Z1, Z2 correctors, but what is the difference with * and C, C1, C2?
	'T×'		=> 'Tx',
	'Z'			=> 'Z',
	'Z×'		=> 'Zx',
	'Z1'		=> 'Z1',
	'Z2'		=> 'Z2',
	'okrufou'	=> '?=okrufou',
	'usew~'		=> '?=usew~',
);

my $fmt_stat = "%-20s: %4d [%s]\n";
my $fmt_state = "%-20s: %4d [%s] : %d\n";

my %stat_chunking = (
	COMMENT => 1,
);

my %stats = ();
my %witness = ();
my %comments = ();
my %commentsfiltered = ();
my $witness;

if (open(CF, "<:encoding(UTF-8)", $commentsinfile)) {
	while (my $line = <CF>) {
		chomp $line,
		my $plainline = $line;
		$plainline =~ s/[{}]//g;
		$commentsfiltered{$plainline} = $line;
	}
	close CF;
}

sub comment {
	my $text = shift;
	witness_stat('COMMENT', $text);
	$comments{$text}++;
	my $resulttext = $text;
	if (exists $commentsfiltered{$text}) {
		$resulttext = $commentsfiltered{$text};
	}
	else {
		witness_stat('COMMENT not FILTERED', $text);
	}
	return '<COMMENT>}'.$resulttext.'{</COMMENT>';
}

sub dodir {
	my $path = shift;
	my $dest = shift;
	if (!opendir(WD, $path)) {
		print STDERR "\nCannot read directory $path\n";
		return;
	}
	my @items = readdir WD;
	closedir WD;
	for my $item (@items) {
		if ($item eq '.' or $item eq '..' or substr($item, 0, 1) eq '.') {
			next;
		}
		my $ext;
		($witness, $ext) = $item =~ m/^(.*)\.([^.]*)$/;
		if ($ext eq 'txt') {
			if (-f "$path/$item") {
				print STDERR "\r\t$witness                   ";
				transform("$path/$item", "$dest/$item");
			}
		}
		elsif ($ext eq '') {
			if (-d "$path/$item") {
				printf STDERR "\n$path/$item\n";
				mkdir "$dest/$item";
				dodir("$path/$item", "$dest/$item");
			}
		}
	}

}

sub trans {
	my $occ = shift;
	my $fc = substr $occ, 0, 1;
	my $lc = substr $occ, -1, 1;
	if (($fc eq '<' and $lc eq '>') or ($fc eq '}' and $lc eq '{') or ($fc eq '&' and $lc eq ';')) {
		return $occ;
	}
	if ($fc eq '@' and $lc eq '@') {
		$occ = substr $occ, 1, length($occ) - 2;
	}
	if (!exists $transtable{$occ}) {
		return $occ;
	}
	return $transtable{$occ};
}

sub transtag {
	my ($bb, $close, $tag, $eb) = @_;
	my $tagrep = $tagtable{$tag};
	if (!defined $tagrep or substr($tagrep, 0, 2) eq '?=') {
		if (!defined $tagrep) {
			$tagrep = "UNKNOWN[$tag]";
		}
		witness_stat('UNTREATED TAGS', $tag);
	}
	else {
		witness_stat('RECOGNIZED TAGS', "$tagrep <= $tag");
	}
	my $closerep = $close?'/':'';
	return "<$closerep$tagrep>";
}

sub transentity {
	my ($bb, $entity, $eb) = @_;
	my $entityrep = $entitytable{$entity};
	if (!defined $entityrep or substr($entityrep, 0, 2) eq '?=') {
		if (!defined $entityrep) {
			$entityrep = "UNKNOWN[$entity]";
		}
		witness_stat('UNTREATED ENTITIES', $entity);
	}
	else {
		witness_stat('RECOGNIZED ENTITIES', "$entityrep <= $entity");
	}
	return "$bb$entityrep$eb";
}

sub transform {
	my ($filein, $fileout) = @_;

	if (!open(F, "<", $filein)) {
		print STDERR "\ncannot read $filein\n";
		return;
	}
	witness_stat('TOTALS', '# of witnesses');

	my $text;
	{local $/; $text = <F>}
	close F;

	witness_stat('TOTALS', 'KB in witnesses', length($text)/1024);


	$text =~ s/\r/\n/g;
	$text =~ s//>/sg;

	$text =~ s/<×/\n<V/sg;

	$text =~ s/¿\.¯/\@0387\@/sg; # greek colon

	$text =~ s/¿([^¯]*)¯/comment($1)/sge;

	$text =~ s/(»)(Û?)(.*?)(¼)/transtag($1,$2,$3,$4)/sge;

	$text =~ s/(&)(\S*?)(;)/transentity($1,$2,$3)/sge;

	$text =~ s/(.)³/<d>$1<\/d>/sg;

	$text =~ s/([a-z~]*)Ð/<NS>$1<\/NS>/sg;

	my (@strangechars) = $text =~ m/((?:<[^>]*>)|(?:\}[^{]*\{)|(?:&\S*;)|(?:\@[0-9]+\@)|[^a-z~ \n])/sg;
	for my $occ (@strangechars) {
		my $fc = substr $occ, 0, 1;
		my $lc = substr $occ, -1, 1;
		if (($fc eq '<' and $lc eq '>') or ($fc eq '}' and $lc eq '{') or ($fc eq '&' and $lc eq ';')) {
			next;
		}
		if ($fc eq '@' and $lc eq '@') {
			$occ = substr $occ, 1, length($occ) - 2;
		}
	 	my $chrep = $transtable{$occ};
	 	if (!defined($chrep) or substr($chrep, 0, 2) eq '?=') {
	 		witness_stat('UNTREATED CHARS', $occ);
		}
	}
	$text =~ s/((?:<[^>]*>)|(?:\}[^{]*\{)|(?:&\S*;)|(?:\@[0-9]+\@)|[a-z~])/trans($1)/sge;

	$text =~ s/[{}]//sg;

	my (@apos) = $text =~ m/(\w*'\w*)/sg;
	for my $apo(@apos) {
	 	witness_stat('APOSTROPHE', $apo);
	}

	if (!open(F, ">:encoding(UTF-8)", $fileout)) {
		print STDERR "\ncannot write $fileout\n";
		return;
	}
	print F $text;
	close F;
}

sub witness_stat {
	my ($stat, $substat, $increment) = @_;
	if (!defined $increment) {
		$increment = 1;
	}
	$stats{$stat}->{$substat} += $increment;
	$witness{$stat}->{$substat}->{$witness}++;
}

sub formatch {
	my $str = shift;
	my @cs = split //, $str;
	my $result = '';
	for (my $i = 0; $i < length($str); $i++) {
		my $c = substr($str, $i, 1);
		my $o = ord($c);
		if (hex('80') <= $o and $o <= hex('9f')) {
			$result .= sprintf "<%02x>", $o;
		}
		else {
			$result .= $c;
		}
	}
	return $result;
}

sub dummy {
	1;
}

mkdir $destdir;
dodir($workdir, $destdir);

print STDERR "\n";

if (!open(LF, ">:encoding(UTF-8)", $logfile)) {
	print STDERR "\ncannot write $logfile\n";
	return;
}

if (!open(CM, ">:encoding(UTF-8)", $commentsoutfile)) {
	print STDERR "\ncannot write $commentsoutfile\n";
	return;
}

for my $text (sort keys %comments) {
	printf CM "%s\n", $text;
}

for my $stat (sort keys %stats) {
	my $compact = $stat_chunking{$stat};
	if (!$compact) {
		print STDERR "\n$stat\n";
	}
	print LF "\n$stat\n";
	my $substats = $stats{$stat};
	my $firstsubstat;
	my $firstwitness;
	my $nstat = 0;
	for my $substat (sort keys %$substats) {
		if (!defined $firstsubstat) {
			$firstsubstat = $substat;
		}
		my $substatrep = formatch($substat);
		my $substatinfo = $substats->{$substat};
		my $witnessinfo = $witness{$stat}->{$substat};
		my @witnesses = sort keys %$witnessinfo;
		my $firstw = $witnesses[0];
		if (!defined $firstwitness) {
			$firstwitness = $firstw;
		}
		if (!$compact) {
			printf STDERR $fmt_stat, $substatrep, $substatinfo, $witnesses[0];
		}
		printf LF $fmt_state, $substatrep, $substatinfo, $firstw, $witnessinfo->{$firstw};
		for my $w (@witnesses[1 .. $#witnesses]) {
			printf LF "\t[%s] : %d\n", $w, $witnessinfo->{$w};
			$nstat += $witnessinfo->{$w};
		}
	}
	dummy();
	if ($compact) {
		print STDERR "\n";
		printf STDERR $fmt_stat, $stat, $nstat, $firstwitness, $witness{$stat}->{$firstsubstat};
	}
}

close LF;
close CM;
