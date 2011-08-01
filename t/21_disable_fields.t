#!perl

use strict;
use warnings;

use Test::More 'no_plan';

use_ok('HTML::FillInForm::PurePerl');

TODO: {
	local $TODO = 'disable_fields not ready.';

my $html = qq[
<form>
<input type="text" name="one" value="not disturbed">
<input type="text" name="two" value="not disturbed">
</form>
];

my $result = HTML::FillInForm::PurePerl->new->fill(
					 scalarref => \$html,
					 fdat => {
					   two => "new val 2",
					 },
					 disable_fields => [qw(two)],
					 );

ok($result =~ /not disturbed.+one/,'don\'t disable 1');
ok($result =~ /new val 2.+two.+disable="1"/,'disable 2');

}