package HTML::FillInForm::PurePerl;

use strict;
use warnings;
#use utf8;
use Carp;
use vars qw( $VERSION );

$VERSION = '0.97';

sub new {
	return bless {}, shift;
}

sub fill {
	my $self = shift;
	my %p = @_;
	
	my $target = $p{target};
	my $fill_password = exists( $p{fill_password} ) ? $p{fill_password} : 1;
	my $ignore_fields = $p{ignore_fields} || [];

	# cgi->param をHASHに展開
	my %querys;

	if ( $p{fobject} ) {
		my $cgi_arr = ( ref( $p{fobject} ) eq 'ARRAY' )
			? $p{fobject} : [ $p{fobject} ];
		foreach my $obj ( @{$cgi_arr} ) {
			if ( $obj->can('param') ) {
				foreach( $obj->param ) {
					$querys{$_} = [ $obj->param($_) ];
				}
			} else {
				croak 'bad fobject parameter';
			}
		}
	}
	if ( $p{fdat} ) {
		my $cgi_arr = ( ref( $p{fdat} ) eq 'ARRAY' )
			? $p{fdat} : [ $p{fdat} ];
		foreach my $obj ( @{$cgi_arr} ) {
			if ( ref( $obj ) eq 'HASH' ) {
				foreach( keys( %{$obj} ) ) {
					$querys{$_} = ( ref($obj->{$_}) eq 'ARRAY' )
						? $obj->{$_} : [ $obj->{$_} ];
				}
			} else {
				croak 'bad fobject parameter';
			}
		}
	}

	# ignore_fields を削除
	foreach( @{$ignore_fields} ) {
		delete( $querys{$_} );
	}
	
	my $text_before = '';
	my $text        = '';
	my $text_after  = '';
	{
		my $org_text;
		if ( $p{file} ) {
			$org_text = _slurp_file( $p{file}, $p{binmode} );
		} elsif ( $p{scalarref} ) {
			$org_text = $p{scalarref};
		}
		
		if ( ! ref( $org_text ) ) {
			$org_text = \$org_text;
		#	croak "'scalarref' parameter is not scalar reference.";
		}
		
		#target の処理
		if ( $target ) {
			if ( ${$org_text} =~ /^
				(.*<form(?:[^>]*)name=["']$target["'](?:[^>]*)>)
				(.*?)
				(<\/form>.*)$/isx
			) {
				$text_before = $1;
				$text        = $2;
				$text_after  = $3;
			} else {
				croak "target form tag not found in $p{file}.";
			}
		} else {
			$text = ${$org_text};
		}
	}

	my @replaced;	#結果を保存。

	{ # <input>
		my %radios;		#ラジオボタンは一つしか checked にならない
		my @tags = ( $text =~ /(<input [^>]+>)/igs );
		foreach my $tag ( @tags ) {
			my $name = _get_attr( 'name', $tag );
			next if ( ! $name );
			next if ( ref( $querys{$name} ) ne 'ARRAY' );
			
			my $type = lc( _get_attr( 'type', $tag ) );
			next if ( ($type eq 'password') && (! $fill_password) );
			
			if ( $type ne 'radio' && $type ne 'checkbox' ) {
				next if ( ! @{$querys{$name}} );
			}

			my $q = $querys{$name};
			my $res;

			if ( (! $type) || $type eq 'text' || $type eq 'hidden'
				|| $type eq 'password' ) {
				my $del;
				for( my $i=0; $i<@{$q}; $i++ ) {
					if ( my $tmp_res = _set_value( $tag, $q->[$i] ) ) {
						$res = $tmp_res;
						$del = $i;
						last;
					}
				}
				splice( @{$q}, $del, 1 ) if ( defined( $del ) );

			} elsif ( $type eq 'checkbox' ) {
				$res = _remove_checked( $tag );
				my $del;
				for( my $i=0; $i<@{$q}; $i++ ) {
					if ( my $tmp_res = _set_checked( $tag, $q->[$i] ) ) { 
						$res = $tmp_res;
						$del = $i;
						last;
					}
				}
				splice( @{$q}, $del, 1 ) if ( defined( $del ) );

			} elsif ( $type eq 'radio' ) {
				$res = _remove_checked( $tag );
				if ( ! $radios{$name} ) {
					my $del;
					for( my $i=0; $i<@{$q}; $i++ ) {
						if ( my $tmp_res = _set_checked( $tag, $q->[$i] ) ) { 
							$res = $tmp_res;
							$del = $i;
							$radios{$name} = 1;
							last;
						}
					}
					splice( @{$q}, $del, 1 ) if ( defined( $del ) );
				}
			}
			if ( $res ) {
				push @replaced, [ $tag, $res ];
			}
		}
	}

	{ # <select>
		my @tags = ( $text =~ /(<select [^>]+>.+?<\/select>)/isg );
		foreach my $tag ( @tags ) {
			my ( $select_tag ) = ( $tag =~ /(<select [^>]+>)/i );
			my $name = _get_attr( 'name', $select_tag );
			next if ( ! $name );
			next if ( ref( $querys{$name} ) ne 'ARRAY' );
			next if ( ! @{$querys{$name}} );

			my $changed = $tag;
			my @options = ( $changed =~ /(<option [^>]+>)/igs );
			
			# まず、規定のselectedを削除する
			foreach my $opttag ( @options ) {
				if ( my $res = _remove_selected( $opttag ) ) {
					$changed =~ s/\Q$opttag\E/$res/;
				}
			}
			
			@options = ( $changed =~ /(<option[^>]*>(?:[^<\r\n]*)(?:<\/option>)?)/igs );

			my $q = $querys{$name};
			OPTTAG: foreach my $opttag ( @options ) {
				my $del;
				for( my $i=0; $i<@{$q}; $i++ ) {
					if ( my $res = _set_selected( $opttag, $q->[$i] ) ) {
						$changed =~ s/\Q$opttag\E/$res/g;
						$del = $i;
						last;
					}
				}
				splice( @{$q}, $del, 1 ) if ( defined( $del ) );
			}
			
			if ( $tag ne $changed ) {
				push @replaced, [ $tag, $changed ];
			}

		}
	}

	{ # <textarea>
		my @tags = ( $text =~ /(<textarea [^>]+>.*<\/textarea>)/ig );
		foreach my $tag ( @tags ) {
			my $name = _get_attr( 'name', $tag );
			next if ( ! $name );
			next if ( ref( $querys{$name} ) ne 'ARRAY' );
			next if ( ! @{$querys{$name}} );

			my $q = shift @{$querys{$name}} || '';
			my ( $start_tag ) = ($tag =~ /^(<textarea[^>]+>)/i);
			my ( $end_tag )   = ($tag =~ /(<\/textarea>)$/i );
			if ( $start_tag && $end_tag ) {
				my $res = $start_tag . _escapeHTML( $q ) . $end_tag;
				push @replaced, [ $tag, $res ];
			}
		}
	}
	
	foreach( @replaced ) {
		$text =~ s/\Q$_->[0]\E/$_->[1]/;
	}

	return $text_before . $text . $text_after;
}

sub _get_attr {
	my $attr = shift;
	my $tag = shift;
	if ( $tag =~ / $attr="([^"]+)"/i
		|| $tag =~ / $attr='([^']+)'/i
		|| $tag =~ / $attr=([^'"\/>\s]+)/i ) {
		return _unescapeHTML( $1 );
	}
	return;
}

sub _set_value {
	my $tag = shift;
	my $val = shift;
	$val = '' if ( ! defined $val );
	
	$val = _escapeHTML( $val );
	if ( $tag =~ s/ (value)="([^"]*)"/ $1="$val"/i
		|| $tag =~ s/ (value)='([^']*)'/ $1='$val'/i
		|| $tag =~ s/ (value)=([^'"\/>\s]+)/ $1="$val"/i
		|| $tag =~ s/( ?\/?)>$/ value="$val"$1>/ ) {
		return $tag;
	}
	return;
}

sub _remove_checked {
	my $tag = shift;
	if ( $tag =~ s/( checked(?:="checked")?)//i ) {
		return $tag;
	}
	return;
}

sub _remove_selected {
	my $tag = shift;
	if ( $tag =~ s/( selected(?:="selected")?)//i ) {
		return $tag;
	}
	return;
}

sub _set_checked {
	my $tag = shift;
	my $val = shift;
	return if ( ! defined( $val ) );

	# 検索用に""に囲まれた文字列を削除しておく。
	my $removed = $tag;
	$removed =~ s/"[^"]*"//g;
	$removed =~ s/'[^']*'//g;
	my $tag_val = _get_attr( 'value', $tag );
	if ( ( defined($tag_val) && ($tag_val eq $val) ) || ($val eq 'on') ) {
		if ( $removed !~ / checked(?:="checked")?/i ) {
			$tag =~ s/( ?\/?)>$/ checked="checked"$1>/;
			return $tag;
		}
		return $tag;
	}
	return;
}

sub _set_selected {
	my $tag = shift;
	my $val = shift;
	return if ( ! defined( $val ) );

	# 検索用に""に囲まれた文字列を削除しておく。
	my $removed = $tag;
	$removed =~ s/"[^"]*"//g;
	$removed =~ s/'[^']*'//g;
	my $tag_val = _get_attr( 'value', $tag );
	if ( ! defined( $tag_val ) ) {
		if ( $tag =~ /<option[^>]*>([^<\r\n]+)(?:<\/option>)?/i ) {
			$tag_val = $1;
			$tag_val =~ s/^\s+//;
		}
	}
	
	if ( ( defined($tag_val) && $tag_val eq $val ) || $val eq 'on' ) {
		if ( $removed !~ / selected(?:="selected")?/i ) {
			$tag =~ s/(<option[^>]*)( ?\/?)>/$1 selected="selected"$2>/i;
		}
		return $tag;
	}
	return;
}


sub _slurp_file {
	my $file = shift;
	my $binmode = shift;
	open( my $fh, ($binmode ? "<:encoding($binmode)" : '<'), $file ) or croak $!;
	my $text = do { local $/; <$fh> };
	close( $fh );
	return \$text;
}

sub _escapeHTML {
	my $str = shift;
	return $str if ( ! $str );
	$str =~ s/&/&amp;/g;
	$str =~ s/"/&quot;/g;
	$str =~ s/'/&#39;/g;
	$str =~ s/</&lt;/g;
	$str =~ s/>/&gt;/g;
	return $str;
}

sub _unescapeHTML {
	my $str = shift;
	return $str if ( ! $str );
	$str =~ s/&amp;/&/g;
	$str =~ s/&quot;/"/g;
	$str =~ s/&#39;/'/g;
	$str =~ s/&lt;/</g;
	$str =~ s/&gt;/>/g;
	$str =~ s/&nbsp;/ /g;
	return $str;
}



1;
__END__

=head1 NAME

HTML::FillInForm::PurePerl - Pure Perl, regular expression based HTML::FillInForm.

=head1 SYNOPSIS

  my $q = new CGI;

  $q->param( "name", "Makog" );

  my $fif = HTML::FillInForm::PurePerl->new();
  my $output = $fif->fill(
      scalarref => \$html,
      fobject => $q
  );

=head1 DESCRIPTION

HTML::FillInForm は、HTMLフォームからのデータを input や textarea や select タグに自動的に挿入するものです。このモジュールは HTML::Parser を利用しており、また、HTML::Parser は XSモジュールなので、権限を持ってインストールを行える環境でないと、これらのモジュールを使うことができません。

というわけで、HTML::FillInForm と似たようなことを、HTML::Parser が使えない環境でも利用できるようにしたかったので、Pure Perl で、正規表現ベースの HTML::FillInForm を作ってみました。HTML::Parser がインストールされている環境では、HTML::FillInForm の利用をお勧めします。

=head1 METHODS

=over 4

=item new

新しい FillInForm オブジェクトを生成します。

 my $fif = HTML::FillInForm::PurePerl->new;

=item fill

HTML::FillInForm 1.x とほぼ同様の使い方ができます。

 my $cgi = CGI->new;
 my $output = $fif->fill(
     scalerref => \$html,
     fobject   => $cgi,
 );


fillメソッドの引数には、以下のようなものがあります。一部対応していないものもありますが、ほぼ HTML::FillInForm と同じようにしてあります。

=back

=over 8

=item scalarref => \$html

テンプレートとなるHTMLテキストのリファレンスを渡します。

=item file => $template_file_path

ファイルパスを直接指定することもできます。scalarref と同時に渡した場合、file が優先されます。

=item fobject => $cgi

埋め込む値として、CGI.pm のオブジェクトを渡します。CGI.pm のオブジェクトのように、param メソッドを持っているものが対象となります。

=item fdat => $hash_ref

埋め込む値として、fobject の代わりに、連想配列のリファレンスを渡すこともできます。

 my $hash_ref = {
 	familyname => 'makog',
 	lastname   => 'makoto',
 	favorite   => [ 'Mac', 'Perl', 'tansuikabutsu' ]
 };
 $output = $fif->fill(
 	scalerref => \$html,
 	fdat      => $hash_ref,
 );

=item target => $target_form_name

HTMLに複数のフォームがある場合、対象となるformタグのname属性を指定します。

 $output = $fif->fill(
 	scalerref => \$html,
 	fdat      => $hash_ref,
 	target    => 'form1',
 );

=item fill_password => 1 # or 0

passwordフィールドに値を埋め込みたく無い場合は、「0」を指定します。
デフォルトでは、埋め込むようになっています。


=item ignore_fields => [ $igonore_field_name1, $name2 ... ]

埋め込みたくないものを、配列のリファレンスで指定します。

=back

=head1 BUGS AND LIMITATIONS

=over 4

=item 同じ入力タグが複数ある場合、上に詰まります。

例えば、

 姓：<input type="text" name="name" value="">
 名：<input type="text" name="name" value="">

というHTMLがあり、「名」だけに「Makoto」と入力して submit した場合、以下のように値が埋め込まれます。

 姓：<input type="text" name="name" value="Makoto">
 名：<input type="text" name="name" value="">

これは、元のHTMLテキストに対して正規表現により置換を行っているためです。
例えば、以下のようにすれば大丈夫です。

 姓：<input type="text" name="name" value="" id="familyname">
 名：<input type="text" name="name" value="" id="lastname">

=back

=head1 HTML::FillInForm 1.x とのちょっとした違い

=over 4

=item タグの変換

HTML::FillInForm は、タグの大文字→小文字の変換を行うようです。また、fobject や fdat で渡されていない値でも、value属性のついていない<input>タグには、value="" を加えるようです。例えば、

 <INPUT NAME="name"> → <input name="name" value="">

HTML::FillInForm::PurePerl は、なるべく元のテキストを変更しません。

 <INPUT NAME="name"> → <INPUT NAME="name">

=item name属性が同じタグが複数ある場合の動作

例えば、

 <input type="text" name="name" value="default1" id="familyname">
 <input type="text" name="name" value="default2" id="lastname">

というHTMLがあり、以下のような値をfdatとして渡した場合、

 $fdat = { 'name' => [ 'bar1' ] };
 $fif->fill( file => $file, fdat => $fdat );

HTML::FillInForm の場合

 <input type="text" name="name" value="bar1" id="familyname">
 <input type="text" name="name" value="" id="lastname">

となりますが、HTML::FillInForm::PurePerl の場合、

 <input type="text" name="name" value="bar1" id="familyname">
 <input type="text" name="name" value="default2" id="lastname">

となります。これは、二つめの name="name" の値が undef であると解釈するためです。同じように動作させたい場合、HTML::FillInForm::PurePerl では、以下のようにします。

 $fdat = { 'name' => [ 'bar1', '' ] };
 $fif->fill( file => $file, fdat => $fdat );

=back

=head1 SEE ALSO

L<HTML::FillInForm>

=head1 AUTHOR

Written by Makoto Ogawa. <ogawa@nun.co.jp>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut