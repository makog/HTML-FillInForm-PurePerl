# -*- Mode: Perl; -*-

use strict;
use Test;
BEGIN { plan tests => 3 }

use HTML::FillInForm::PurePerl;

my $form = <<EOF;
<FORM name="foo1">
<INPUT TYPE="TEXT" NAME="foo1" value="nada">
</FORM>
<FORM name="foo2">
<INPUT TYPE="TEXT" NAME="foo2" value="nada">
</FORM>
<FORM>
<INPUT TYPE="TEXT" NAME="foo3" value="nada">
</FORM>
EOF
  ;
  
my %fdat = (
  foo1 => 'bar1',
  foo2 => 'bar2',
  foo3 => 'bar3',
);

my $fif = new HTML::FillInForm::PurePerl;
my $output = $fif->fill(
  scalarref => \$form,
  fdat => \%fdat,
  target => 'foo2',
);

my @v = $output =~ m/<input .*?value="(.*?)"/ig;
ok($v[0], 'nada');
ok($v[1], 'bar2');
ok($v[2], 'nada');
