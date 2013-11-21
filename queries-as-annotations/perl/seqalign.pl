#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

#use Algorithm::Diff qw(sdiff);
use Diff qw(sdiff);

binmode(STDOUT, ":utf8");

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

# gen 1:2
#my $wivu  = "וְהָאָ֗רֶץ הָיְתָ֥ה תֹ֨הוּ֙ וָבֹ֔הוּ וְחֹ֖שֶׁךְ עַל־פְּנֵ֣י תְהֹ֑ום וְר֣וּחַ אֱלֹהִ֔ים מְרַחֶ֖פֶת עַל־פְּנֵ֥י הַמָּֽיִם׃ ";
#my $westm = "וְהָאָ֗רֶץ הָיְתָ֥ה תֹ֙הוּ֙ וָבֹ֔הוּ וְחֹ֖שֶׁךְ עַל־פְּנֵ֣י תְה֑וֹם וְר֣וּחַ אֱלֹהִ֔ים מְרַחֶ֖פֶת עַל־פְּנֵ֥י הַמָּֽיִם׃ ";

# gen 1:11
#my $wivu = "וַיֹּ֣אמֶר אֱלֹהִ֗ים תַּֽדְשֵׁ֤א הָאָ֨רֶץ֙ דֶּ֔שֶׁא עֵ֚שֶׂב מַזְרִ֣יעַ זֶ֔רַע עֵ֣ץ פְּרִ֞י עֹ֤שֶׂה פְּרִי֙ לְמִינֹ֔ו אֲשֶׁ֥ר זַרְעֹו־בֹ֖ו עַל־הָאָ֑רֶץ וַֽיְהִי־כֵֽן׃ ";
#my $westm = "וַיֹּ֣אמֶר אֱלֹהִ֗ים תַּֽדְשֵׁ֤א הָאָ֙רֶץ֙ דֶּ֔שֶׁא עֵ֚שֶׂב מַזְרִ֣יעַ זֶ֔רַע עֵ֣ץ פְּרִ֞י עֹ֤שֶׂה פְּרִי֙ לְמִינ֔וֹ אֲשֶׁ֥ר זַרְעוֹ־ב֖וֹ עַל־הָאָ֑רֶץ וַֽיְהִי־כֵֽן׃ ";

#gen 8:17
my $wivu = "כָּל־הַחַיָּ֨ה אֲשֶֽׁר־אִתְּךָ֜ מִכָּל־בָּשָׂ֗ר בָּעֹ֧וף וּבַבְּהֵמָ֛ה וּבְכָל־הָרֶ֛מֶשׂ הָרֹמֵ֥שׂ עַל־הָאָ֖רֶץ הֹוצֵא אִתָּ֑ךְ וְשָֽׁרְצ֣וּ בָאָ֔רֶץ וּפָר֥וּ וְרָב֖וּ עַל־הָאָֽרֶץ׃ ";
my $westm = "כָּל־הַחַיָּ֨ה אֲשֶֽׁר־אִתְּךָ֜ מִכָּל־בָּשָׂ֗ר בָּע֧וֹף וּבַבְּהֵמָ֛ה וּבְכָל־הָרֶ֛מֶשׂ הָרֹמֵ֥שׂ עַל־הָאָ֖רֶץ *הוצא **הַיְצֵ֣א אִתָּ֑ךְ וְשָֽׁרְצ֣וּ בָאָ֔רֶץ וּפָר֥וּ וְרָב֖וּ עַל־הָאָֽרֶץ׃ ";

my $aligned = align(hchunk($wivu), hchunk($westm));

print $wivu, "\n";
print $westm, "\n";
for my $c (@{hchunk($wivu)}) {
	printf "-%s-", $c;
}
print "\n";
for my $c (@{hchunk($westm)}) {
	printf "-%s-", $c;
}
print "\n";
print $aligned;
print "\n";
for my $c (sdiff(hchunk($wivu), hchunk($westm), \&hcmp)) {
	printf "%s <%s> <%s>\n", @$c;
}
