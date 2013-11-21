#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings "uninitialized";
no strict "refs";

my $template = '<Letters><Identifier>$id</Identifier>
@{brieven{<Date>$brieven[0]</Date>
<Sender>$brieven[1]</Sender><Recipient>$brieven[2]</Recipient>
}}</Letters>
';

my %variables = (
	id => '0123456789',
	brieven => [ 
		['1648', 'Huygens', 'Grotius'],
		['1650', 'van Leeuwenhoek', 'Huygens'],
	],
);

sub fill_in {
	my ($template, $variables) = @_;
	$template =~ s/\@\{([^\{]*)\{(.*?)\}\}/fill_in_list($2, $1, $variables)/sge;
	$template =~ s/\$([A-Za-z_0-9]+)/fill_in_var($1, $variables)/sge;
	return $template;
}

sub fill_in_list {
	my ($template, $list, $variables) = @_;
	if (!exists $variables->{$list}) {
		print STDERR "list [$list] not defined in variables\n";
		return $template;
	}
	my $listvar = $variables->{$list};
	if (ref($listvar) ne 'ARRAY') {
		print STDERR "list [$list] is not defined as list in variables\n";
		return $template;
	}
	my $result = '';
	for my $values (@$listvar) {
		my $templatecopy = $template;
		$templatecopy =~ s/\$$list\[([0-9]+)\]/$values->[$1]/sg;
		$result .= $templatecopy;
	}
	return $result;
}

sub fill_in_var {
	my ($var, $variables) = @_;
	if (!exists $variables->{$var}) {
		print STDERR "list [$var] not defined in variables\n";
		return '$'.$var;
	}
	return $variables->{$var};
}

print fill_in($template, \%variables);
