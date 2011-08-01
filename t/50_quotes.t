#!perl

BEGIN {
	use lib './lib';
}

use Test::More 'no_plan';

use CGI;
use_ok('HTML::FillInForm::PurePerl');

my %fdat = (
	foo1 => 'bar1',
	foo2 => 'bar2'
);
my $fif = new HTML::FillInForm::PurePerl;

{
	my $hidden_form_in = qq{<INPUT NAME='foo1' value='nada'><input type='hidden' name='foo2'>};
	my $output = $fif->fill(
		scalarref => \$hidden_form_in,
		fdat => \%fdat
	);
	is( $output,
		qq{<INPUT NAME='foo1' value='bar1'><input type='hidden' name='foo2' value="bar2">},
		'Single Quotes' );
}

{
	my $hidden_form_in = qq{<INPUT NAME=foo1 value=nada><input type=hidden name=foo2>};
	my $output = $fif->fill(
		scalarref => \$hidden_form_in,
		fdat => \%fdat
	);
	is( $output,
		qq{<INPUT NAME=foo1 value="bar1"><input type=hidden name=foo2 value="bar2">},
		'No Quotes' );
}

{
	my $hidden_form_in = qq{<INPUT value=nada NAME=foo1><input name=foo2 type=hidden>};
	my $output = $fif->fill(
		scalarref => \$hidden_form_in,
		fdat => \%fdat
	);
	is( $output,
		qq{<INPUT value="bar1" NAME=foo1><input name=foo2 type=hidden value="bar2">},
		'No Quotes' );
}

{
my $hidden_form_in = qq{<select multiple name='foo1'>
	<option value='0'>bar1</option>
	<option value='bar2'>bar2</option>
	<option value='bar3'>bar3</option>
</select>
<select multiple name="foo2">
	<option value="bar1">bar1</option>
	<option value="bar2">bar2</option>
	<option value="bar3">bar3</option>
</select>
<select multiple name=foo3>
	<option value=bar1>bar1</option>
	<option selected value=bar2>bar2</option>
	<option value=bar3>bar3</option>
</select>
<select multiple name=foo4>
	<option value=bar1>bar1</option>
	<option selected value=bar2>bar2</option>
	<option value=bar3>bar3</option>
</select>};

my $q = new CGI( {
	foo1 => '0',
	foo2 => ['bar1', 'bar2',],
	foo3 => '' }
);

my $output = $fif->fill(scalarref => \$hidden_form_in,
                       fobject => $q);

my $is_selected = join(" ",map { m/selected/ ? "yes" : "no" } grep /option/, split ("\n",$output));

is( $is_selected, "yes no no yes yes no no no no no yes no", 'select' );

}