#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my $workdir = "/Users/dirk/Dropbox/DANS/demos/apps/pa/data/TommyWasserman/Transkriptioner_kopior";
#my $workdir = "/Users/dirk/Dropbox/DANS/demos/apps/pa/data/test";
my $destdir = "/Users/dirk/Dropbox/DANS/demos/apps/pa/datatrans";
my $destfile = "$destdir/transcriptions.txt";
my $logfile = "$destdir/transform.log";
my $reportfile = "$destdir/summary.log";
my $commentsoutfile = "comments.txt";
my $commentsinfile = "commentsfiltered.txt";

my %exceptiondirs = (
	'ooÌnskade' => 1,
);

my %gtranstable = (
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
	'õ'		=> 'Ϛ',
	'0387'	=> '·',		# ano teleia
);

my $gvowels = 'αεηιουω';


my %transtable = (
	'§'		=> '?=P',
	'¯'		=> '?=S',
	'¿'		=> '?=Q',
	'Â'		=> '?=A',
	'Ñ'		=> '?=N',
	'õ'		=> '?=O',
	'&'		=> '&',
	','		=> ',',	
);

my %entitytable = (
	'Â'		=> 'lac', # lacuna
	'Âu'	=> 'lacfilm', # FilmFehler
	'Â§'	=> 'abs', # definition by Jan Krans
);

my %diatable = (
	"'"	=> {
		''		=> '῀',
		'η'		=> 'ῆ',
		'ω'		=> 'ῶ',
	},
	"v"	=> {
		''		=> '´',
		'η'		=> 'ή',
		'ω'		=> 'ώ',
	},
	"j" => {
		''		=> '᾿',
		'υ'		=> 'ὐ',
	},
	"J" => {
		''		=> '῾',
		'υ'		=> 'ὑ',
	},
);

my $diachars = join('',keys(%diatable));

my %other = (
	';'		=> ';',	 
	'.'		=> '.',	 
	'?'		=> '?',	 
	':'		=> ':',	 
	'='		=> '=',	 
	''	=> '[C]', # corrector
	'*'		=> '[H]', # first hand	 
);

my $otherchars = join('',keys(%other));

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
	'Á'			=> 'U', # illegible (see GA 02 Alexandrinus 87a 3 John 1 - Jude 12-1, on top of the page, title)
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
	'xxx'		=> 'SPECIAL',
);

my $newtags = join '|', values %tagtable;

my %fixes = (
	'2378' => [
		['&Â(\s|\z)', '\\&'.$entitytable{"Â"}.';$1' ],
	],
	'42' => [
		['»usew~¼','[[usew~]]'],
		['»okrufou¼','[[okrufou]]'],
	],
	'02' => [
		['jpanta', 'panta'],
	],
	'263' => [
		['Ñ', ''],
	],
);

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

my %ientitytable = ();
my %itagtable = ();

my %stats = ();
my %source = ();
my %statkind = ();
my %comments = ();
my %commentsfiltered = ();
my $source;

for my $item (keys %entitytable) {
	$ientitytable{$entitytable{$item}} = 1;
}
for my $item (keys %tagtable) {
	$itagtable{$tagtable{$item}} = 1;
}

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
	source_stat('I', 'COMMENT', $text);
	$comments{$text}++;
	my $resulttext = $text;
	if (exists $commentsfiltered{$text}) {
		$resulttext = $commentsfiltered{$text};
	}
	else {
		source_stat('E', 'COMMENT not FILTERED', $text);
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
		if ($item =~ m/^o/) {
			print STDOUT "$item\n";
		}
		if ($item eq '.' or $item eq '..' or substr($item, 0, 1) eq '.' or exists $exceptiondirs{$item}) {
			next;
		}
		my $ext;
		($source, $ext) = $item =~ m/^(.*)\.([^.]*)$/;
		if ($ext eq 'txt') {
			if (-f "$path/$item") {
				print STDERR "\r\t$source                   ";
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
	my $nogreek = shift;
	my $fc = substr $occ, 0, 1;
	my $lc = substr $occ, -1, 1;
	if (($fc eq '<' and $lc eq '>') or ($fc eq '&' and $lc eq ';') or ($occ eq '[[' or $occ eq ']]')) {
		return $occ;
	}
	if ($fc eq '@' and $lc eq '@') {
		$occ = substr $occ, 1, length($occ) - 2;
	}
	if ($fc eq '}' and $lc eq '{') {
		$occ = substr $occ, 1, length($occ) - 2;
		$occ =~ s/((?:\[\[)|(?:\]\])|(?:<[^>]*>)|(?:&<[^>]+>\S*;)|(?:&\S*;)|(?:\@[0-9]+\@)|[^ \n$diachars$otherchars-])/trans($1,1)/sge;
		return '}'.$occ.'{';
	}

	my $occrep;
	my $isgreek = 0;
	if ($nogreek) {
		if ($occ =~ m/^[a-zA-Z0-9]+$/) {
			$occrep = $occ;
		}
	}
	else {
		$occrep = $gtranstable{$occ};
		$isgreek = 1;
	}
	if (!defined $occrep) {
		$occrep = $transtable{$occ};
		$isgreek = 0;
	}
	if (!defined($occrep)) {
		$occrep = "<UNTREATED CHAR: $occ>";
		source_stat('E', 'UNTREATED CHAR', $occ);
	}
	elsif (substr($occrep, 0, 2) eq '?=') {
		my $occrepshort = substr($occrep, 2);
		$occrep = "<UNRESOLVED CHAR: $occrepshort =: $occ>";
		source_stat('E', 'UNRESOLVED CHAR', "$occrepshort =: $occ");
	}
	else {
		my $label = $isgreek?' GREEK':'';
		source_stat('OK', "RECOGNIZED$label CHAR", "$occrep =: $occ");
	}
	return $occrep;
}

sub transtag {
	my ($bb, $close, $tag, $eb) = @_;
	my $tagrep;
	$tagrep = $itagtable{$tag};
	if (defined $tagrep) {
		source_stat('OK', 'RECOGNIZED TAG', $tag);
		$tagrep = $tag;
	}
	else {
		$tagrep = $tagtable{$tag};
		if (!defined $tagrep) {
			$tagrep = "<UNTREATED TAG: $tag>";
			source_stat('E', 'UNTREATED TAG', $tag);
		}
		elsif (substr($tagrep, 0, 2) eq '?=') {
			my $tagrepshort = substr($tagrep, 2);
			$tagrep = "<UNRESOLVED TAG: $tagrepshort =: $tag>";
			source_stat('E', 'UNRESOLVED TAG', "$tagrepshort =: $tag");
		}
		else {
			source_stat('OK', 'RECOGNIZED TAG', "$tagrep =: $tag");
		}
	}
	my $closerep = $close?'/':'';
	return "<$closerep$tagrep>";
}

sub transentity {
	my ($bb, $entity, $eb) = @_;
	my $entityrep;
	$entityrep = $ientitytable{$entity};
	if (defined $entityrep) {
		source_stat('OK', 'RECOGNIZED ENT', $entity);
		$entityrep = $entity;
	}
	else {
		$entityrep = $entitytable{$entity};
		if (!defined $entityrep) {
			$entityrep = "<UNTREATED ENT: ($entity)>";
			source_stat('E', 'UNTREATED ENT', $entity);
		}
		elsif (substr($entityrep, 0, 2) eq '?=') {
			my $entityrepshort = substr($entityrep, 2);
			$entityrep = "<UNRESOLVED ENT: $entityrepshort =: $entity>";
			source_stat('E', 'UNRESOLVED ENT', "$entityrepshort =: $entity");
		}
		else {
			source_stat('OK', 'RECOGNIZED ENT', "$entityrep =: $entity");
		}
	}
	return "$bb$entityrep$eb";
}

sub transcomment {
	my ($btag, $text, $etag) = @_;
	$text =~ s/\^([$diachars])\^/$1/sg;
	$text =~ s/((?:\[\[)|(?:\]\])|(?:<[^>]*>)|(?:\[[A-Z0-9-]+\])|(?:&<[^>]+>\S*;)|(?:&\S*;)|[$otherchars])/transother($1, 1)/sge;
	$text =~ s/([0-9][0-9-]*)/transnumber($1, 1, 'CMT')/sge;
	return $btag.$text.$etag;
}

sub transelementnum {
	my ($btag, $text, $etag, $element) = @_;
	$text =~ s/([0-9][0-9-]*)/transnumber($1, 1, $element)/sge;
	return $btag.$text.$etag;
}

sub transdia {
	my ($chunk, $pre, $dia, $flag) = @_;

	my $fc = substr $chunk, 0, 1;
	my $lc = substr $chunk, -1, 1;
	if ($fc eq '}' and $lc eq '{') {
		return $chunk;
	}
	my $diarep;
	$diarep = $diatable{$dia};
	my $diamsg;
	if (!defined $diarep) {
		$diamsg = $dia;
	}
	else {
		$diamsg = "$diarep->{''} =: $dia";
	}
	if ($flag == 0) {
		$diarep =  "$pre<UNTREATED DIA: $diamsg>";
		source_stat('E', 'UNTREATED DIA', "$pre$diamsg");
	}
	elsif ($flag == 1) {
		$diarep = $diatable{$dia};
		if (defined $diarep) {
			$diarep = $diarep->{$pre};
		}
		if (!defined $diarep) {
			$diarep = "<UNRESOLVED DIA: $diamsg>";
			source_stat('E', 'UNRESOLVED DIA', "$pre$diamsg");
		}
		else {
			source_stat('OK', 'RECOGNIZED DIA', "$diarep =: $pre$diamsg");
		}
	}
	return $diarep;
}

sub transother {
	my ($pre, $flag) = @_;
	my $fc = substr $pre, 0, 1;
	my $lc = substr $pre, -1, 1;
	if (($fc eq '[' and $lc eq ']') or ($fc eq '<' and $lc eq '>') or ($fc eq '&' and $lc eq ';') or ($pre eq '[[' or $pre eq ']]')) {
		return $pre;
	}
	elsif ($fc eq '^' and $lc eq '^') {
		return substr($pre, 1, length($pre) - 2);
	}
	my $otherrep;
	if ($flag == 0) {
		$otherrep =  "<UNTREATED CHAR CMT: $pre>";
		source_stat('E', 'UNTREATED CHAR CMT', $pre);
	}
	elsif ($flag == 1) {
		$otherrep = $other{$pre};
		if (!defined $otherrep) {
			$otherrep = "<UNRESOLVED CHAR CMT: $pre>";
			source_stat('E', 'UNRESOLVED CHAR CMT', $pre);
		}
		else {
			source_stat('OK', 'RECOGNIZED CHAR CMT', "$otherrep =: $pre");
			$otherrep = '^'.$otherrep.'^';
		}
	}
	return $otherrep;
}

sub transnumber {
	my ($pre, $flag, $label) = @_;
	my $fc = substr $pre, 0, 1;
	my $lc = substr $pre, -1, 1;
	if (($fc eq '[' and $lc eq ']') or ($fc eq '<' and $lc eq '>')) {
		return $pre;
	}
	my $numrep;
	if ($flag == 0) {
		$numrep =  "<UNTREATED NUM: $pre>";
		source_stat('E', 'UNTREATED NUM', $pre);
	}
	elsif ($flag == 1) {
		$numrep = "[$pre]";
		source_stat('OK', "RECOGNIZED NUM $label", "$numrep =: $pre");
	}
	return $numrep;
}

sub transdot {
	my ($dotted, $tags, $markup) = @_;
	my $ndots = length $markup;
	if ($ndots > 1) {
		source_stat('W', 'DOTS REPEATED', "$ndots x");
	}
	if (length $tags) {
		source_stat('W', 'DOTS INTERFERING WITH TAGS', $tags);
	}
	my $tag = 'd' x $ndots;
	source_stat('OK', 'RECOGNIZED DOTS', "$ndots dot below '$dotted'");
	return "<$tag>$dotted</$tag>";
}

sub transform {
	my ($filein) = @_;

	if (!open(F, "<", $filein)) {
		print STDERR "\ncannot read $filein\n";
		return;
	}
	source_stat('I', 'TOTALS', '# of sources');
	source_stat('I', 'SOURCE', 'name');

	my $text;
	{local $/; $text = <F>}
	close F;

	source_stat('I', 'TOTALS', 'KB in sources', length($text)/1024);

	my $fixit = $fixes{$source};
	if ($fixit) {
		for my $task (@$fixit) {
			my ($pat, $repl) = @$task;
			my $n = 0;
			my $dochange = "\$n = \$text =~ s/$pat/$repl/sg";
			eval $dochange;
			if ($n) {
				source_stat('W', 'SOURCE FIXES', "$repl =: $pat ($n x)");
			}
		}
	}

	$text =~ s/\r/\n/g;
	$text =~ s//>/sg;

	$text =~ s/< ?×/\n<V/sg;

	$text =~ s/¿\.¯/\@0387\@/sg; # greek colon

	$text =~ s/¿([^¯]*)¯/comment($1)/sge;

	$text =~ s/(»)(Û?)(.*?)(¼)/transtag($1,$2,$3,$4)/sge;

	$text =~ s/(&)(\S*?)(;)/transentity($1,$2,$3)/sge;

	$text =~ s/(.)((?:<[^>]+>)*)(³+)/transdot($1,$2,$3)/sge; # previous letter partly visible (usually represented as a dot below the character in question)

	$text =~ s/([a-z~]*)Ð/<NS>$1<\/NS>/sg;

	$text =~ s/((?:\[\[)|(?:\]\])|(?:<[^>]*>)|(?:\}[^{]*\{)|(?:&<[^>]+>\S*;)|(?:&\S*;)|(?:\@[0-9]+\@)|[^0-9 \n$diachars$otherchars-])/trans($1,0)/sge;
	$text =~ s/((?:\}[^{]*\{)|(?:([$gvowels]?)([$diachars])))/transdia($1, $2, $3, 1)/sge;

	$text =~ s/[{}]//sg;

	$text =~ s/(<COMMENT>)(.*?)(<\/COMMENT>)/transcomment($1,$2,$3)/sge;

	# $text =~ s/(<((?:A|C|H|U|K|T|Z)[12]?[abx]?)>)(.*?)(<\/\2>)/transelementnum($1,$3,$4,$2)/sge;
	$text =~ s/(<((?:$newtags)[12]?[abx]?)>)(.*?)(<\/\2>)/transelementnum($1,$3,$4,$2)/sge;


	$text =~ s/((?:\^[^\^]*\^)|(?:<[^>]*>)|(?:\[[A-Z0-9-]+\])|(?:&<[^>]+>\S*;)|(?:&\S*;)|[$otherchars])/transother($1, 0)/sge;
	$text =~ s/((?:<[^>]*>)|(?:\[[0-9][0-9-]*\])|(?:[0-9][0-9-]*))/transnumber($1, 0)/sge;

	print TF "\n\n<S>$source</S>\n\n";
	print TF $text;
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

if (!open(TF, ">:encoding(UTF-8)", $destfile)) {
	print STDERR "\ncannot write $destfile\n";
	return;
}

dodir($workdir);

print STDERR "\n";

if (!open(LF, ">:encoding(UTF-8)", $logfile)) {
	print STDERR "\ncannot write $logfile\n";
	return;
}

if (!open(SF, ">:encoding(UTF-8)", $reportfile)) {
	print STDERR "\ncannot write $reportfile\n";
	return;
}

if (!open(CM, ">:encoding(UTF-8)", $commentsoutfile)) {
	print STDERR "\ncannot write $commentsoutfile\n";
	return;
}

for my $text (sort keys %comments) {
	printf CM "%s\n", $text;
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
		my $substatrep = formatch($substat);
		my $substatinfo = $substats->{$substat};
		my $sourceinfo = $source{$stat}->{$substat};
		my @sources = sort keys %$sourceinfo;
		my $firstw = $sources[0];
		if (!defined $firstsource) {
			$firstsource = $firstw;
		}
		if ($compact != 2) {
			$thisreport .= sprintf $fmt_stat_sub, $substatrep, $substatinfo, $sources[0];
		}
		$filereport .= sprintf $fmt_stat_fl, $substatrep, $substatinfo;
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
		print SF $report, "\n";
		print LF $filereport, "\n";
	}
}

close LF;
close SF;
close CM;
close TF;
