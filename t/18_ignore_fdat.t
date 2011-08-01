#!/usr/local/bin/perl

# contributed by James Tolley

use strict;
use warnings FATAL => 'all';

use Test::More tests => 4;

use_ok('HTML::FillInForm::PurePerl');

my $html = qq[
<form>
<input type="text" name="one" value="not disturbed">
<input type="text" name="two" value="not disturbed">
<input type="text" name="three" value="not disturbed">
</form>
];

my $result = HTML::FillInForm::PurePerl->new->fill(
					 scalarref => \$html,
					 fdat => {
					   two => "new val 2",
					   three => "new val 3",
					 },
					 ignore_fields => [qw(one two)],
					 );

ok($result =~ /one.+not disturbed/,'ignore 1');
ok($result =~ /two.+not disturbed/,'ignore 2');
ok($result =~ /three.+new val 3/,'ignore 3');
