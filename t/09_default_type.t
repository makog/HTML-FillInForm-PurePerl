# -*- Mode: Perl; -*-

use strict;

$^W = 1;

print "1..2\n";

use HTML::FillInForm::PurePerl;

print "ok 1\n";

my $hidden_form_in = qq{<INPUT NAME="foo1" value="nada">
<input type="hidden" name="foo2">};

my %fdat = (foo1 => 'bar1',
	foo2 => 'bar2');

my $fif = new HTML::FillInForm::PurePerl;
my $output = $fif->fill(scalarref => \$hidden_form_in,
			fdat => \%fdat);
if ($output =~ m/^<INPUT( (NAME="foo1"|value="bar1")){2}>\s*<input( (type="hidden"|name="foo2"|value="bar2")){3}>$/){
	print "ok 2\n";
} else {
	print "Got unexpected out for $hidden_form_in:\n$output\n";
	print "not ok 2\n";
}
