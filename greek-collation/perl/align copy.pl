#!/usr/bin/perl

=head2 idea

Use collatex

=cut

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my $curl = "/usr/bin/curl";
my $demoserver ="http://gregor.middell.net/collatex/api/collate";
my $localserver ="http://localhost:8080/collatex-web-1.1/api/collate";
my $collatex ="$localserver";
my $xmlhead = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>';

my ($filein, $fileout, $output_type) = @ARGV;

sub dummy {
	1;
}

sub processsource {
	my $good = 1;
	my $jsep = '';
	if (!open(AF, "<:encoding(UTF-8)", $filein)) {
		print STDERR "Can't read file [$filein]\n";
		return 0;
	}
	if (!open(A, ">:encoding(UTF-8)", $fileout)) {
		print STDERR "Can't write to file [$fileout]\n";
		return 0;
	}
	if ($output_type =~ m/xml/) {
		print A $xmlhead, "\n";
	}
	elsif ($output_type =~ m/json/) {
		print A "[\n";
	}

	my $curtext = '';
	my $curpass;
	while (my $line = <AF>) {
		if ($line =~ m/^===/) {
			if (length $curtext) {
				my ($thisgood, $atext) = align($curpass, $curtext);
				if (!$thisgood) {
					$good = 0;
				}
				else {
					serialize($curpass, $atext, $jsep);
					$jsep = "\n, ";
				}
			}
			$curtext = '';
			($curpass) = $line =~ m/^=+([^=]+)=+/; 
			next;
		}
		$curtext .= $line;
	}
	my ($thisgood, $atext) = align($curpass, $curtext);
	if (!$thisgood) {
		$good = 0;
	}
	else {
		serialize($curpass, $atext, $jsep);
	}
	if ($output_type =~ m/json/) {
		print A "\n]\n";
	}
	close AF;
	close A;

	printf STDERR "\nResults written to [$fileout]\n";
	return $good;
}

sub align {
	my ($pass, $text) = @_;
	printf STDERR "\r$pass: aligning with collatex\t\t";
	my @curl = (
		$curl, '--silent',
		'-X', 'POST',
		'--header', 'Content-Type: application/json;charset=UTF-8;',
		'--header', "Accept: $output_type;",
		'--data-binary', "$text",
        $localserver
	);
	if (!(open(CURL, "-|:encoding(UTF-8)", @curl))) {
		return (0, '');
	}
	my @response = <CURL>;
	my $response = join '', @response;
	if (!close CURL) {
		return (0, $response);
	}
	return (1, $response);
}

sub serialize {
	my ($pass, $text, $jsep) = @_;
	if ($output_type =~ m/xml/) {
		$text =~ s/<\?xml[^\n]*\n//;
		print A "<!-- $pass -->\n";
	}
	elsif ($output_type =~ m/html/) {
		print A "<h1>$pass</h1>\n";
	}
	elsif ($output_type =~ m/json/) {
		#$text =~ s/(\"t\":\"[^"]*\"),(\"n\":\"[^"]*\")/$2,$1/sg;
		$text =~ s/\{(\"alignment\")/\{\"verse\": \"$pass\", $1/;
		print A $jsep;
	}
	print A $text;
	return 1;
}

sub main {
	if (!processsource()) {
		return 0;
	}
}

exit !main();

close A;
