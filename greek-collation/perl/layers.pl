#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my $testext = $ARGV[0];
my $textwidth = $ARGV[1];
if ($textwidth eq '') {
	$textwidth = 100;
}

my $basedir = "..";
my $destdir = "$basedir/datatrans";
my $scriptdir = "$basedir/scripts";
my $listdir = "$basedir/input/list";
my $sourcemetafile = "$listdir/provenance.txt";
my $sourcefile = "$destdir/transcriptions$testext.txt";
my $graphpaperfile = "$destdir/graphpaper.txt";
my $numericfile = "$destdir/layersnumeric.txt";
my $totalfile = "$destdir/layerstotal.txt";
my $logfile = "$destdir/layers.log";

=head2 tagtable

	H	first hand
	Hx	first hand and omission
	C	corrector
	Cx
	C1x
	C2
	C2a
	C2b
	C2x
	U	illegible (see GA 02 Alexandrinus 87a 3 John 1 - Jude 12-1, on top of the page, title)
	A	alternative reading
	Ax
	A2
	K	commentary reading
	T	question for Tommy: it looks as if T is first hand and Z1, Z2 correctors, but what is the difference with * and C, C1, C2?
	Tx
	Z
	Zx
	Z1
	Z2
	NS	nomen sacrum
	d	dot below
	dd	double dot below
	COMMENT

=cut

my %entitytable = (
	abs			=> '♣',
	lac			=> '█',
	lacfilm		=> '░',
);

my $layerinfo = '
SRC
	SRC(H)
	SRC(Hx)
	SRC(T)
	SRC(Tx)
	SRC-NS
	SRC-DOT
A
	A-NS
	A-DOT
Ax
	Ax-NS
	Ax-DOT
A2
	A2-NS
	A2-DOT
C
	C-NS
	C-DOT
Cx
	Cx-NS
	Cx-DOT
C1x
	C1x-NS
	C1x-DOT
C2
	C2-NS
	C2-DOT
C2a
	C2a-NS
	C2a-DOT
C2b
	C2b-NS
	C2b-DOT
C2x
	C2x_NS
	C2x_DOT
K
	K-NS
	K-DOT
Z
	Z-NS
	Z-DOT
Zx
	Zx-NS
	Zx-DOT
Z1
	Z1-NS
	Z1-DOT
Z2
	Z2-NS
	Z2-DOT
COMMENT
';

my %sourcenametweaks = (
        'ℵ 01'			=> '01',
        'K 018'			=> '018',
        'A 02'			=> '02',
        'L 020'			=> '020',
        'P 025'			=> '025',
        'B 03'			=> '03',
        'C 04'			=> '04',
        'Ψ 044'			=> '044',
		'L2394'			=> '2718_L2394?',
);

my %sourcefiletweaks = (
		'L1196_2'		=> 'L1196',
		'L1281_2'		=> 'L1281',
		'L427_2'		=> 'L427',
		'L585_2'		=> 'L585',
		'TRbase'		=> '',
);

my @layerorder;
my %layerinfo = ();

sub initlayers {
	for my $line (split /\n/, $layerinfo) {
		if (!length($line)) {
			next;
		}
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		push @layerorder, $line;
	}
}

initlayers();

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

if (!open(TF, "<:encoding(UTF-8)", $sourcefile)) {
	print STDERR "Cannot read [$sourcefile]\n";
	exit 1;
}
if (!open(GRAPHPAPER, ">:encoding(UTF-8)", $graphpaperfile)) {
	print STDERR "Cannot write [$graphpaperfile]\n";
	exit 1;
}
if (!open(NUMERIC, ">:encoding(UTF-8)", $numericfile)) {
	print STDERR "Cannot write [$numericfile]\n";
	exit 1;
}
if (!open(TOTAL, ">:encoding(UTF-8)", $totalfile)) {
	print STDERR "Cannot write [$totalfile]\n";
	exit 1;
}

sub output {
	my ($text, $total, $numeric, $graphpaper) = @_;
	if ($total) {
		print TOTAL $text;
	}
	if ($numeric) {
		print NUMERIC $text;
	}
	if ($graphpaper) {
		print GRAPHPAPER $text;
	}
}

my %sourcemetadata = ();
my %sourcemetaused = ();

sub initmetadata {
	if (!open(MF, "<:encoding(UTF-8)", $sourcemetafile)) {
		print STDERR "Cannot read [$sourcemetafile]\n";
		exit 1;
	}
	while (my $line = <MF>) {
		chomp $line;
		my ($src, $period, $provenance, $remarks) = split /\t/, $line;
		if ($src =~ m/^[(\[]/) {
			next;
		}
		my ($newsrc) = $src =~ m/^([^=]+)=/;
		if (!defined $newsrc) {
			$newsrc = $src;
		}
		my $xsrc = $newsrc;
		if (exists $sourcenametweaks{$newsrc}) {
			$xsrc = $sourcenametweaks{$newsrc};
			if ($xsrc eq '') {
				$xsrc = $newsrc;
				$src = undef;
			}
		}
		$sourcemetadata{$xsrc} = [$src, $period, $provenance, $remarks];
	}
	close MF;
}

initmetadata();

my $source;
my $sourcetext;

my $ruler = ' ' x 4;
my $uruler = '';
my $druler = '';

my $i;
for ($i = 0; $i <= $textwidth; $i += 10) {
	my $fillchar;
	if ($i == 0) {
		$fillchar = '┃';
	}
	else {
		$fillchar = '│';
	}
	$ruler .= sprintf "%9d%s", $i, $fillchar;
	if ($i == 0) {
		next;
	}
	$uruler .= sprintf "%s┿", '┯' x 9;
	$druler .= sprintf "%s┿", '┷' x 9;
}
if ($i < $textwidth - 1) {
	$uruler .= '┯' x ($textwidth - $i - 1);
	$druler .= '┷' x ($textwidth - $i - 1);
}

$ruler .= "\n";

sub layer {
	my @cur_source_lines = ();
	while (my $line = <TF>) {
		if (substr($line, 0, 3) eq '<S>') {
			if (defined $source) {
				layersource(@cur_source_lines);
			}
			@cur_source_lines = ($line);
			($source) = $line =~ m/^<S>([^<]*)<\/S>/;
		}
		else {
			push @cur_source_lines, $line;
		}
	}
	if (scalar @cur_source_lines) {
		layersource(@cur_source_lines);
	}
}

sub layersource {
	printf STDERR "\r$source     ";
	if ($source eq 'L1196_2') {
		dummy()
	}
	source_stat('I', 'SOURCES', 'number');
	my $sourcekey = $source;
	if (exists $sourcefiletweaks{$source}) {
		$sourcekey = $sourcefiletweaks{$source};
		if ($sourcekey eq '') {
			return;
		}
	}
	my $sourcemeta = $sourcemetadata{$sourcekey};
	if (!defined $sourcemeta) {
		source_stat('E', 'METADATA missing', $sourcekey);
		return;
	}
	my ($origsrc, $period, $provenance, $remarks) = @$sourcemeta;
	if (!defined $origsrc) {
		source_stat('W', 'SOURCE USAGE', 'skipped');
		return;
	}
	if ($remarks eq '') {
		$remarks = ' ';
	}
	$sourcemetaused{$source}++;
	if (!exists $sourcefiletweaks{$source}) {
		$source = $origsrc;
	}
	titleline($source, $period);
	titleline(undef, $provenance);
	titleline($source, $remarks);
	output(sprintf("!\t%s\t%s\t%s\t%s\n\n", $source, $period, $provenance, $remarks), 1, 1, 0);
	output(sprintf("┏%s┓\n", '━' x (12 + $textwidth)), 1, 0, 0);
	my $firstverse = 1;
	for my $line (@_) {
		chomp $line;

		if (substr($line, 0, 3) eq '<V ') {
			if ($firstverse) {
				output(sprintf("┗%s┛\n", '━' x (12 + $textwidth)), 1, 0, 0);
				$firstverse = 0;
			}
			my ($prefix, $mat) = $line =~ m/^(<V [^>]*>) ?(.*)/;
			layerverse($prefix, $mat);
			output(sprintf("┏%s┓\n", '━' x (12 + $textwidth)), 1, 0, 0);
			sourceline($line);
			output(sprintf("┗%s┛\n", '━' x (12 + $textwidth)), 1, 0, 0);
		}
		else {
			sourceline($line);
		}
	}
	output($ruler, 1, 0, 1);
}

sub sourceline {
	my $line = shift;
	my $rest = $line;
	while (length $rest) {
		my $limit = (length($rest) < $textwidth)?length($rest):$textwidth;
		my $chunk = substr($rest, 0, $limit);
		$rest = substr($rest, $limit);
		output(sprintf("┃%s%s┃\n", $chunk, ' ' x (12 + $textwidth - length($chunk))), 1, 0, 0);
	}
}

sub titleline {
	my ($prefix, $text) = @_;
	my $defaultprefix = '█';
	if (!defined $prefix) {
		$prefix = $defaultprefix;
	}
	my $rest = $text;
	my $thisprefix = $prefix;
	while (length $rest) {
		my $limit = (length($rest) < $textwidth)?length($rest):$textwidth;
		my $chunk = substr($rest, 0, $limit);
		$rest = substr($rest, $limit);
		output(sprintf("█%s%s█ %s %s\n", $prefix, '█' x (11 - length($prefix)), $chunk, '█' x ($textwidth - length($chunk))), 1, 0, 1);
		$thisprefix = $defaultprefix;
	}
}

sub layerverse {
	my ($prefix, $line) = @_;

# gather statistics for nomina sacra

	my (@ns) = $line =~ m/((?:<NS>.*?<\/NS>)+)/sg;
	for my $ns (@ns) {
		$ns =~ s/<\/?NS>//g;
		source_stat('I', "NOMINA SACRA", $ns);
	}

# gather statistics for textelements usage

	if ($line =~ m/<[ACHKTZ][^O]/) {
		my ($pre, $trigger, $rest, $newrest);
		my @pieces = ();
		$rest = $line;
		while (length($rest)) {
			($pre, $trigger, $newrest) = $rest =~ m/^(.*?)(<[HT])(.*)$/;
			if (!defined $pre) {
				push @pieces, $rest;
				$rest = '';
			}
			else {
				if (length $pre) {
					push @pieces, $pre;
				}
				push @pieces, $trigger;
				$rest = $newrest;
			}
		}
		my @newpieces = ();
		my $addtopref = 0;
		for my $piece (@pieces) {
			if ($addtopref) {
				$newpieces[$#newpieces] .= $piece;
				$addtopref = 0;
			}
			else {
				push @newpieces, $piece;
				$addtopref = (substr($piece, 0, 1) eq '<' and (substr($piece, 1, 1) eq 'H' or substr($piece, 1, 1) eq 'T'));
			}
		}

		for my $piece (@newpieces) {
			my $textexample = $piece;
			$textexample =~ s/<COMMENT>.*?<\/COMMENT>//g;
			$textexample =~ s/<NS>.*?<\/NS>//g;
			$textexample =~ s/<U>.*?<\/U>//g;
			$textexample =~ s/<d>.*?<\/d>//g;
			$textexample =~ s/<dd>.*?<\/dd>//g;
			$textexample =~ s/^[^<]+//;
			$textexample =~ s/[^>]+$//;
			$textexample =~ s/ //g;
			$textexample =~ s/[$contentchars]+/α/g;
			if (length $textexample) {
				source_stat('I', "TEXT EXAMPLES", $textexample);
			}
		}
	}


	my ($numerictokens, $graphtokens) = tokenize($line);

	my ($prefixrep) = $prefix =~ m/<V\s+([^>]*)>/;

	my @lines = ();
	for my $layer (@layerorder) {
		if (exists $graphtokens->{$layer}) {
			my $text = $graphtokens->{$layer};
			if ($text =~ m/^┼*$/) {
				next;
			}
			if ($layer eq 'COMMENT') {
				my (@comments) = $text =~ m/\(#[0-9]+\)([^〓]*?)〓/sg;
				for my $comment (@comments) {
					my (@commentinfo) = $comment =~ m/( *▲)«[^»]*»([^〓]*)/sg;
					for (my $i = 0; $i <= $#commentinfo / 2; $i++) {
						my $cprefix = $commentinfo[$i];
						my $ctext = $commentinfo[$i+1];
						my $rest = $cprefix;
						my $lineno = 0;
						my $line = '';
						while (length $rest) {
							my $limit = (length($rest) < $textwidth)?length($rest):$textwidth;
							my $chunk = substr($rest, 0, $limit);
							$rest = substr($rest, $limit);
							if ($chunk eq ' ' x $limit) {
								$lineno++;
							}
							else {
								$line .= sprintf "┠%-12s╂%s%s┨\n", $layer, $chunk, ' ' x ($textwidth - length($chunk)); 
								$rest = $ctext;
								while (length $rest) {
									$limit = (length($rest) < $textwidth)?length($rest):$textwidth;
									$chunk = substr($rest, 0, $limit);
									$line .= sprintf "┠%-12s╂%s%s┨\n", $layer, $chunk, ' ' x ($textwidth - length($chunk)); 
									$rest = substr($rest, $limit);
								}
								push @{$lines[$lineno++]}, $line;
								last;
							}
						}
					}
				}
			}
			else {
				my $rest = $text;
				my $lineno = 0;
				while (length $rest) {
					my $limit = (length($rest) < $textwidth)?length($rest):$textwidth;
					my $chunk = substr($rest, 0, $limit);
					$rest = substr($rest, $limit);
					if ($chunk eq '┼' x $limit) {
						$lineno++;
					}
					else {
						my $line = sprintf "┠%-12s╂%s%s┨\n", $layer, $chunk, '┼' x ($textwidth - length($chunk)); 
						push @{$lines[$lineno++]}, $line;
					}
				}
			}
		}
	}
	output($ruler, 1, 0, 1);
	output(sprintf("┏━%s%s━%s%s╋%s┓\n", $source, '━' x (7 - length($source)), $prefixrep, '━' x (3 - length($prefixrep)), $uruler), 1, 0, 1);
	my $nline = 0;
	for my $set (@lines) {
		$nline++;
		if ($nline > 1) {
			my $linerep = sprintf "line %d", $nline;
			output(sprintf("┣━%s%s━%s╋%s┫\n", $linerep, '━' x (7 - length($linerep)), '━' x 3, '┿' x $textwidth), 1, 0, 1);
		}
		output(join('', @$set), 1, 0, 1);
	}
	output(sprintf("┗━%s%s━%s%s╋%s┛\n", $source, '━' x (7 - length($source)), $prefixrep, '━' x (3 - length($prefixrep)), $druler), 1, 0, 1);

	for my $layer (@layerorder) {
		if (exists $numerictokens->{$layer}) {
			output(sprintf("%s\t%s=%s\n", $prefixrep, $layer, $numerictokens->{$layer}), 1, 1, 0);
		}
	}
	output("\n", 0, 1, 0);
}

sub dotify {
	my $spec = shift;
	my ($n, $m) = $spec =~ m/^\s*([0-9]+)\s*-?\s*([0-9]*)\s*$/;
	my $nonemptym = length $m;
	my $result = '['.$spec.']';

	if (!defined $n) {
		source_stat('E', 'DOTIFY wrong spec', $spec);
	}
	else {
		if (! $nonemptym) {
			$m = $n;
		}
		if ($m < $n) {
			source_stat('E', 'DOTIFY wrong range', $spec);
		}
		elsif ($nonemptym and $m == $n) {
			source_stat('E', 'DOTIFY strange range', $spec);
		}
		if ($m == 0) {
			source_stat('E', 'DOTIFY zero range', $spec);
		}
		$result = ('●' x $n) . ('○' x ($m - $n));
	}
	return $result;
}

sub entity {
	my $ent = shift;
	if (!exists $entitytable{$ent}) {
		source_stat("E", "ENTITY UNKNOWN", $ent);
		return '&'.$ent.';';
	}
	return $entitytable{$ent};
}

sub tokenize {
	my $line = shift;
	$line =~ s/\s+$//;
	$line =~ s/\[([0-9 -]*)\]/dotify($1)/ge;
	$line =~ s/\&(abs|lacfilm|lac);/entity($1)/ge;
	my ($pre, $elements, $tags, $maintag, $maincontent, $alttext, $alttag, $comment, $newrest);
	my $rest = $line;
	my %numerictokens = ();
	my %graphtokens = ();
	my $ncomment = 0;
	my $bpos = 0;
	my $bposv = 0;

	while (length($rest)) {

		($pre, $elements, $tags, $newrest) = $rest =~ m/^(.*?)((?:<((?:COMMENT)|(?:[HTACKZ][^>]*))>.*?<\/\3> *)+)(.*)$/;
		if (defined $elements) {
			$rest = $newrest;
			my $bposd = length(markup($bpos, $pre, \%numerictokens, \%graphtokens, 'SRC'));
			$bpos += $bposd;
			$bposv += $bposd;

# comment texts
			my (@commenttexts) = $elements =~ m/<COMMENT>(.*?)<\/COMMENT>/g;
			for my $ctext (@commenttexts) {
				$ctext =~ s/<\/?NS>/⊚/g;
				my $cprefix = ' ' x ($bpos - 1);
				$graphtokens{COMMENT} .= sprintf "(#%d)%s▲«%s»%s〓", ++$ncomment, $cprefix, $bpos, $ctext;
				$numerictokens{COMMENT} .= sprintf "(#%d)«%d»%s\t", $ncomment, $bpos + 1, $ctext;
			}

			$elements =~ s/<COMMENT>.*?<\/COMMENT>//g;
			my $rem = $elements;
			my $newrem;

			while (length($rem)) {
				($maintag, $maincontent, $alttext, $alttag, $newrem) = $rem =~ m/^<([HT][^>]*)>(.*?)<\/\1>((?: *<([ACKZ][^>]*)>.*?<\/\4>)*)(.*)$/;
				if (!defined $maintag) {
					($alttext, $alttag, $newrem) = $rem =~ m/^ *((?: *<([ACKZ][^>]*)>.*?<\/\2>)+)(.*)$/;
				}
				if (defined $alttext) {

# alternative texts
					my $mainparsed = markup($bpos, $maincontent, \%numerictokens, \%graphtokens, 'SRC');
					my $mainlength = length($mainparsed);
					my $portionlength = $mainlength;

					my $htlayer = "SRC($maintag)";
					$graphtokens{$htlayer} .= ('┼' x ($bposv - length($graphtokens{$htlayer}))) . ('▬' x (length($graphtokens{SRC}) - $bposv)); 
					$numerictokens{$htlayer} .= sprintf "«%d»%s\t", $bpos + 1, $mainparsed;

					my %altlengths = ();
					my (@alttexts) = $alttext =~ m/<([ACKZ][^>]*)>(.*?)<\/\1>/g;
					for (my $i = 0; $i < scalar(@alttexts); $i += 2) {
						$alttag = $alttexts[$i];
						$alttext = $alttexts[$i+1];
						my $curaltlength = length $graphtokens{$alttag};
						my $altprefix = '';
						if ($curaltlength < $bposv) {
							$altprefix = '┼' x ($bposv - $curaltlength);
						}
						markup($bpos, sprintf("«%d»", $bpos + 1), \%numerictokens, undef, $alttag);
						markup(0, $altprefix, undef, \%graphtokens, $alttag);
						$altlengths{$alttag} = length(markup($bpos, $alttext, \%numerictokens, \%graphtokens, $alttag));
					}
					for my $atag (keys %altlengths) {
						my $alength = $altlengths{$atag};
						if ($alength > $portionlength) {
							$portionlength = $alength;
						}
					}
					for my $atag (keys %altlengths) {
						my $alength = $altlengths{$atag};
						pad(\%graphtokens, $atag, $alength, $portionlength);
					}
					pad(\%graphtokens, 'SRC', $mainlength, $portionlength);

					$bpos += $mainlength;
					$bposv += $portionlength;
					$rem = $newrem;
					next;
				}
				$rest = $rem . $rest;
				last;
			}
			next;
		}

		my $bposd = length(markup($bpos, $rest, \%numerictokens, \%graphtokens, 'SRC'));
		$bpos += $bposd;
		$bposv += $bposd;

		$rest = '';
		last;

=head2


		($pre, $precomments, $maintag, $maincontent, $alttext, $alttag, $newrest) = $rest =~ m/^(.*?)((?: *<COMMENT>.*?<\/COMMENT> *)*)<([HT][^>]*)>(.*?)<\/\3>((?: *<((?:COMMENT)|(?:[ACKZ][^>]*))>.*?<\/\6>)*)(.*)$/;
		if (!defined $maintag) {
			($pre, $alttext, $alttag, $newrest) = $rest =~ m/^(.*?)((?: *<((?:COMMENT)|(?:[ACKZ][^>]*))>.*?<\/\3>)+)(.*)$/;
			$precomments = '';
		}
		if (defined $alttext) {
			my $bposd = length(markup($bpos, $pre, \%numerictokens, \%graphtokens, 'SRC'));
			$bpos += $bposd;
			$bposv += $bposd;

# comment texts
			my (@commenttexts) = ($precomments.$alttext) =~ m/<COMMENT>(.*?)<\/COMMENT>/g;
			for my $ctext (@commenttexts) {
				$ctext =~ s/<\/?NS>/⊚/g;
				my $cprefix = ' ' x ($bpos - 1);
				$graphtokens{COMMENT} .= sprintf "(#%d)%s▲«%s»%s〓", ++$ncomment, $cprefix, $bpos, $ctext;
				$numerictokens{COMMENT} .= sprintf "(#%d)«%d»%s\t", $ncomment, $bpos + 1, $ctext;
			}

# alternative texts
			my $mainparsed = markup($bpos, $maincontent, \%numerictokens, \%graphtokens, 'SRC');
			my $mainlength = length($mainparsed);
			my $portionlength = $mainlength;

			my $htlayer = "SRC($maintag)";
			$graphtokens{$htlayer} .= ('┼' x ($bposv - length($graphtokens{$htlayer}))) . ('▬' x (length($graphtokens{SRC}) - $bposv)); 
			$numerictokens{$htlayer} .= sprintf "«%d»%s\t", $bpos + 1, $mainparsed;

			my %altlengths = ();
			my (@alttexts) = $alttext =~ m/<([ACKZ][^>]*)>(.*?)<\/\1>/g;
			for (my $i = 0; $i < scalar(@alttexts); $i += 2) {
				$alttag = $alttexts[$i];
				if ($alttag eq 'COMMENT') {
					next;
				}
				$alttext = $alttexts[$i+1];
				my $curaltlength = length $graphtokens{$alttag};
				my $altprefix = '';
				if ($curaltlength < $bposv) {
					$altprefix = '┼' x ($bposv - $curaltlength);
				}
				markup($bpos, sprintf("«%d»", $bpos + 1), \%numerictokens, undef, $alttag);
				markup(0, $altprefix, undef, \%graphtokens, $alttag);
				$altlengths{$alttag} = length(markup($bpos, $alttext, \%numerictokens, \%graphtokens, $alttag));
			}
			for my $atag (keys %altlengths) {
				my $alength = $altlengths{$atag};
				if ($alength > $portionlength) {
					$portionlength = $alength;
				}
			}
			for my $atag (keys %altlengths) {
				my $alength = $altlengths{$atag};
				pad(\%graphtokens, $atag, $alength, $portionlength);
			}
			pad(\%graphtokens, 'SRC', $mainlength, $portionlength);

			$bpos += $mainlength;
			$bposv += $portionlength;
			$rest = $newrest;
			next;
		}

		my $bposd = length(markup($bpos, $rest, \%numerictokens, \%graphtokens, 'SRC'));
		$bpos += $bposd;
		$bposv += $bposd;

		$rest = '';
		last;
=cut

	}

	if (length $testext) {
		debugprintlayer(\%graphtokens);
	}
	return (\%numerictokens, \%graphtokens);
}

sub pad {
	my ($tokens, $atag, $alength, $portionlength) = @_;
	my $pad = '';
	if ($alength < $portionlength) {
		$pad = ' ' x ($portionlength - $alength);
	}
	if (length $pad) {
		$tokens->{$atag} .= $pad;
	}
}

sub debugprintlayer {
	my $tokens = shift;
	for my $layer (sort keys %$tokens) {
		my $stream = $tokens->{$layer};
		printf STDERR "[%s]=%s\n", $layer, $stream;
	}
}

sub debugprinttokens {
	my $layer = shift;
	my $tokens = shift;
	printf STDERR "BEGIN \[$layer\]\n";
	for my $token (@$tokens) {
		if (!ref $token) {
			print STDERR "\ttext=$token\n";
		}
		else {
			my ($code, $name) = ($token->[0], $token->[1]);
			print STDERR "$code-$name\n";
		}
	}
	printf STDERR "END   \[$layer\]\n";
}

sub markup {
	my ($bpos, $text, $numerictokensout, $graphtokensout, $layer) = @_;
	my @tokensin = ();
	my ($pre, $symbol, $newrest);
	my $rest = $text;
	my $pos = 0;
	my $visualpos = 0;
	my %markupfound = ();
	while (length($rest)) {
		($pre, $symbol, $newrest) = $rest =~ m/^(.*?)((?:«[^»]*»)|(?:<[^>]+>))(.*)$/;
		if (!defined $pre) {
			push @tokensin, $rest;
			$pos += length $rest;
			$visualpos += length $rest;
			$rest = '';
		}
		elsif (substr($symbol,0, 1) ne '<') {
			push @tokensin, $pre;
			$pos += length $pre;
			$visualpos += length $pre;

			push @tokensin, [0, $symbol, $pos, $visualpos];
			$visualpos += length $symbol;
			$rest = $newrest;
		}
		else {
			push @tokensin, $pre;
			$pos += length $pre;
			$visualpos += length $pre;

			my $isclose = substr($symbol, 1, 1) eq '/';
			my $posrep = ($isclose and $pos > 0)? $pos - 1 : $pos;
			my $visualposrep = ($isclose and $visualpos > 0)? $visualpos - 1 : $visualpos;
			my $kindrep = $isclose? 2 : 1;
			my $symbolrep = $symbol;
			$symbolrep =~ s/^<\/?//;
			$symbolrep =~ s/>$//;
			$markupfound{$symbolrep}++;
			push @tokensin, [$kindrep, $symbolrep, $posrep, $visualposrep];
			$rest = $newrest;
		}
	}
	if (length($testext)) {
		debugprinttokens($layer, \@tokensin);
	}
	# put the text on the layer
	my $addition = '';
	for my $token (@tokensin) {
		if (!ref $token) {
			$addition .= $token;
		}
		elsif ($token->[0] == 0) {
			$addition .= $token->[1];
		}
	}
	if (defined $graphtokensout) {
		$graphtokensout->{$layer} .= $addition;
	}
	if (defined $numerictokensout) {
		$numerictokensout->{$layer} .= $addition;
	}

	my $layermu;

	# process NS markup

	$layermu = $layer.'-NS';
	if ($markupfound{NS}) {
		my $in_ns = 0;
		for my $token (@tokensin) {
			if (!ref $token) {
				my $fillchar = $in_ns? '⊚': '┼';
				if (defined $graphtokensout) {
					$graphtokensout->{$layermu} .= $fillchar x length($token);
				}
				if ($in_ns) {
					if (defined $numerictokensout) {
						$numerictokensout->{$layermu} .= $token;
					}
				}
			}
			elsif ($token->[0] == 0) {
				if (defined $graphtokensout) {
					$graphtokensout->{$layermu} .= $token->[1];
				}
			}
			else {
				my ($kind, $name) = ($token->[0], $token->[1]);
				if ($kind == 1 and $name eq 'NS') {
					$in_ns = 1;
					if (defined $numerictokensout) {
						$numerictokensout->{$layermu} .= sprintf "«%d»", $token->[2] + $bpos + 1; 
					}
				}
				elsif ($kind == 2 and $name eq 'NS') {
					$in_ns = 0;
				}
			}
		}
	}
	else {
		if (defined $graphtokensout) {
			$graphtokensout->{$layermu} .= '┼' x $visualpos;
		}
	}

	# process d-dd U markup

	$layermu = $layer.'-DOT';
	if ($markupfound{d} or $markupfound{dd} or $markupfound{U}) {
		my $in_dd = 0;
		my $in_d = 0;
		my $in_U = 0;
		for my $token (@tokensin) {
			if (!ref $token) {
				my $fillchar = $in_dd? '●' : ($in_d? '◐' : ($in_U? '◙' : '┼'));
				my $numchar = $in_dd? '2' : ($in_d? '1' : ($in_U? '0' : ''));
				if (defined $graphtokensout) {
					$graphtokensout->{$layermu} .= $fillchar x length($token);
				}
				if (defined $numerictokensout) {
					if ($numchar ne '') {
						$numerictokensout->{$layermu} .= $numchar x length($token);
					}
				}
			}
			elsif ($token->[0] == 0) {
				if (defined $graphtokensout) {
					$graphtokensout->{$layermu} .= $token->[1];
				}
			}
			else {
				my ($kind, $name) = ($token->[0], $token->[1]);
				if ($kind == 1) {
					if (defined $numerictokensout) {
						$numerictokensout->{$layermu} .= sprintf "«%d»", $token->[2] + $bpos + 1; 
					}
				}
				if ($kind == 1 and $name eq 'U') {
					$in_U = 1;
				}
				elsif ($kind == 2 and $name eq 'U') {
					$in_U = 0;
				}
				elsif ($kind == 1 and $name eq 'dd') {
					$in_dd = 1;
				}
				elsif ($kind == 2 and $name eq 'dd') {
					$in_dd = 0;
				}
				elsif ($kind == 1 and $name eq 'd') {
					$in_d = 1;
				}
				elsif ($kind == 2 and $name eq 'd') {
					$in_d = 0;
				}
			}
		}
	}
	else {
		if (defined $graphtokensout) {
			$graphtokensout->{$layermu} .= '┼' x $visualpos;
		}
	}
	return $addition;
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

sub checkmeta {
	for my $src (sort keys %sourcemetadata) {
		$source = $src;
		if (!exists $sourcemetaused{$src}) {
			source_stat('W', 'METADATA unused', $src);
		}
		elsif ($sourcemetaused{$src} > 1) {
			source_stat('W', 'METADATA multiple', $src);
		}
	}
}

sub dummy {
	1;
}

layer();

checkmeta();

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
close GRAPHPAPER;
close NUMERIC;
close TOTAL;
close TF;
