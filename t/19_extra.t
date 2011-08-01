# -*- Mode: Perl; -*-

use strict;

$^W = 1;

#An object without a "param" method
package Support::Object;

sub new{
    my ($proto) = @_;
    my $self = {};
    bless $self, $proto;
    return $self;
}

###
#End of Support::Object

use Test::More tests => 30;

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
                                         ignore_fields => [ 'one' ],
                                         );

ok($result =~ /one.+not disturbed/,'scalar value of ignore_fields');
ok($result =~ /two.+new val 2/,'fill_scalarref worked');
ok($result =~ /three.+new val 3/,'fill_scalarref worked 2');


$html = qq[
<form>
<input type="text" name="one" value="not disturbed">
<input type="text" name="two" value="not disturbed">
</form>
];

#my @html_array = split /\n/, $html;

$result = HTML::FillInForm::PurePerl->new->fill(
                                         scalarref => \$html,
                                         fdat => {
                                           one => "new val 1",
                                           two => "new val 2",
                                         },
                                         );

ok($result =~ /one.+new val 1/, 'fill_arrayref 1');
ok($result =~ /two.+new val 2/, 'fill_arrayref 2');


$result = HTML::FillInForm::PurePerl->new->fill(
                                         file => "t/data/form1.html",
                                         fdat => {
                                           one => "new val 1",
                                           two => "new val 2",
                                           three => "new val 3",
                                         },
                                         );

ok($result =~ /one.+new val 1/,'fill_file 1');
ok($result =~ /two.+new val 2/,'fill_file 2');
ok($result =~ /three.+new val 3/,'fill_file 3');



$html = qq[
<form>
<input type="text" name="one" value="not disturbed">
<input type="text" name="two" value="not disturbed">
</form>
];

eval{
$result = HTML::FillInForm::PurePerl->new->fill(
                                         scalarref => \$html
                                         );
};

#ok($@ =~ 'HTML::FillInForm::PurePerl->fillInForm\(\) called without \'fobject\' or \'fdat\' parameter set', "no fdat or fobject parameters");

$result = HTML::FillInForm::PurePerl->new->fill(
                                    fdat => {}
                                    );

#No meaningful arguments - should not this produce an error?


$html = qq[
<form>
<input type="text" name="one" value="not disturbed">
<input type="text" name="two" value="not disturbed">
</form>
];

my $fobject = new Support::Object;

eval{
$result = HTML::FillInForm::PurePerl->new->fill(
                                         scalarref => $html,
                                         fobject => $fobject
                                         );
};

ok($@, "bad fobject parameter");


$html = qq{<INPUT TYPE="radio" NAME="foo1">
<input type="radio" name="foo1" >
};

my %fdat = (foo1 => 'bar2');

$result = HTML::FillInForm::PurePerl->new->fill(scalarref => \$html,
                        fdat => \%fdat);

ok( $result !~ /selecetd/,'defaulting radio buttons to on');


$html = qq{<INPUT TYPE="password" NAME="foo1">
};

%fdat = (foo1 => ['bar2', 'bar3']);

$result = HTML::FillInForm::PurePerl->new->fill(scalarref => \$html,
                        fdat => \%fdat);

ok($result =~ /foo1.+bar2/,'first array element taken for password fields');


$html = qq{<INPUT TYPE="radio" NAME="foo1" value="bar2">
<INPUT TYPE="radio" NAME="foo1" value="bar3">
};

%fdat = (foo1 => ['bar2', 'bar3']);

$result = HTML::FillInForm::PurePerl->new->fill(scalarref => \$html,
                        fdat => \%fdat);

my $is_checked = join(" ",map { m/checked/ ? "yes" : "no" } split ("\n",$result));

ok($is_checked eq "yes no",'first array element taken for radio buttons');


$html = qq{<TEXTAREA></TEXTAREA>};

%fdat = (area => 'foo1');

$result = HTML::FillInForm::PurePerl->new->fill(scalarref => \$html,
                        fdat => \%fdat);

ok($result !~ /foo1/,'textarea with no name');


$html = qq{<TEXTAREA NAME="foo1"></TEXTAREA>};

%fdat = (foo1 => ['bar2', 'bar3']);

$result = HTML::FillInForm::PurePerl->new->fill(scalarref => \$html,
                        fdat => \%fdat);


ok($result eq '<TEXTAREA NAME="foo1">bar2</TEXTAREA>','first array element taken for textareas');


$html = qq{<INPUT TYPE="radio" NAME="foo1" value="bar2">
<INPUT TYPE="radio" NAME="foo1" value="bar3">
<TEXTAREA NAME="foo2"></TEXTAREA>
<INPUT TYPE="password" NAME="foo3">
};

%fdat = (foo1 => [undef, 'bar1'], foo2 => [undef, 'bar2'], foo3 => [undef, 'bar3']);

$result = HTML::FillInForm::PurePerl->new->fill(scalarref => \$html,
                        fdat => \%fdat);

ok($result !~ m/checked/, "Empty radio button value");
ok($result =~ m#<TEXTAREA NAME="foo2"></TEXTAREA>#, "Empty textarea");
ok($result =~ m/<INPUT( (TYPE="password"|NAME="foo3"|value="")){3}>/, "Empty password field value");


$html = qq[<div></div>
<!--Comment 1-->
<form>
<!--Comment 2-->
<input type="text" name="foo0" value="not disturbed">
<!--Comment

3-->
<TEXTAREA NAME="foo1"></TEXTAREA>
</form>
<!--Comment 4-->
];

%fdat = (foo0 => 'bar1', foo1 => 'bar2');

$result = HTML::FillInForm::PurePerl->new->fill(scalarref => \$html,
                        fdat => \%fdat);

ok($result =~ /foo0.+bar1/,'form with comments 1');
ok($result =~ '<TEXTAREA NAME="foo1">bar2</TEXTAREA>','form with comments 2');
ok($result =~ '<!--Comment 1-->','Comment 1');
ok($result =~ '<!--Comment 2-->','Comment 2');
ok($result =~ '<!--Comment\n\n3-->','Comment 3');
ok($result =~ '<!--Comment 4-->','Comment 4');

$html = qq[<div></div>
<? HTML processing instructions 1 ?>
<form>
<? XML processing instructions 2?>
<input type="text" name="foo0" value="not disturbed">
<? HTML processing instructions

3><TEXTAREA NAME="foo1"></TEXTAREA>
</form>
<?HTML processing instructions 4 >
];

%fdat = (foo0 => 'bar1', foo1 => 'bar2');

$result = HTML::FillInForm::PurePerl->new->fill(scalarref => \$html,
                        fdat => \%fdat);

ok($result =~ /foo0.+bar1/,'form with processing 1');
ok($result =~ '<TEXTAREA NAME="foo1">bar2</TEXTAREA>','form with processing 2');
ok($result =~ '<\? HTML processing instructions 1 \?>','processing 1');
ok($result =~ '<\? XML processing instructions 2\?>','processing 2');
ok($result =~ '<\? HTML processing instructions\n\n3>','processing 3');
ok($result =~ '<\?HTML processing instructions 4 >','processing 4');

