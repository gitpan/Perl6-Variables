package Perl6::Variables;
$VERSION = '0.02_001'; 
use Filter::Simple;

my $ident = qr/ [_a-z] \w* (?: :: [_a-z] \w* )* /ix;
my $listlikely = qr/ (?: \.\. | => | , | qw | \@ $ident \b [^[] ) /x;
my $alist = qr/ [^]]* $listlikely /x;
my $hlist = qr/ [^}]* $listlikely /x;
my $clist = qr/ [^>]* /x;

FILTER {

    $DB::single=1;
    my $text = "";
    pos = 0;

    while (pos($_)<length($_)) {

        # array reference slice
        m/\G \$ ($ident) \.? \[ (?=$alist) /sxgc and
                $text .= qq/\@{\$$1}[/ and next;

        # array reference
        m/\G \$ ($ident) \.? \[ (?!$alist) /sxgc and
                $text .= qq/\$$1\->[/ and next;

        # hash reference constant slice
        m/\G \$ ($ident) \.? << (?=$clist) /sxgc and do {
                my $varname = $1;
                my $quotedwords = $2;
                m/\G (.*?) >> /sxgc;
                if($quotedwords =~ /\s/) {
                    # $hashref->{foo}
                    # warn 'hash reference constant non-slice: ' .  '# $' . $varname . '->{q<' . $1 . '>}';
                    $text .=  '$' . $varname . '->{q<' . $1 . '>}';
                } else {
                    # @{$hashref}{foo, bar};
                    # warn 'hash reference constant slice: ' .  '# @{$' . $varname . '}{qw<' . $1 . '>}';
                    $text .=  '@{$' . $varname . '}{qw<' . $1 . '>}';
                }
                next;
        };

        # hash reference slice
        m/\G \$ ($ident) \.? \{ (?=$hlist) /sxgc and
                $text .= qq/\@{\$$1}{/ and next;

        # hash reference with function subscript
        m/\G \$ ($ident) \.? \{ ($ident) \} /sxgc and
                $text .= '$' . $1 . '->{' . $2 . '()}' and next;

        # hash reference
        m/\G \$ ($ident) \.? \{ (?!$hlist) /sxgc and
                $text .= qq/\$$1\->{/ and next;

        # array slice
        m/\G \@ ($ident) \[ (?=$alist) /sxgc and
                $text .= qq/\@$1\[/ and next;

        # array
        m/\G \@ ($ident) \[ (?!$alist) /sxgc and
                $text .= qq/\$$1\[/ and next;

        # hash constant slice
        m/\G \% ($ident) << (?=$clist) /sxgc and do {
                my $varname = $1;
                my $quotedwords = $2;
                m/\G (.*?) >> /sxgc;
                # $hash{foo} or @hash{foo, bar}
                # warn "debug: hash constant slice: " . (split(/\s+/, $quotedwords) == 1 ? '$' : '@') . $varname . '{qw<' . $1 . '>}';
                $text .= ($quotedwords =~ /\s/ ? '$' : '@') . $varname . '{qw<' . $1 . '>}';
                next;
        };

        # hash slice
        m/\G \% ($ident) \{ (?=$hlist) /sxgc and
                $text .= qq/\@$1\{/ and next;

        # hash with function subscript
        m/\G \% ($ident) \{ ($ident) \} /sxgc and
                $text .= '$' . $1 . '{' . $2 . '()}' and next;

        # hash
        m/\G \% ($ident) \{ (?!$hlist) /sxgc and
                $text .= qq/\$$1\{/ and next;

        m/\G ([^\$\@%]+|.) /xgcs and
                $text .= $1;

    }
    $_ = $text . substr($_, pos);
};

__END__

Hi! Handy when debugging: perl -Iblib/lib -MO=Deparse test.pl

=head1 NAME

Perl6::Variables - Perl 6 variable syntax for Perl 5

=head1 VERSION

This document describes version 0.02 of Perl6::Variables,
yet to be released as version 0.02 as of March 28, 2004.

=head1 SYNOPSIS

        use Perl6::Variables;

        sub show { print @_[0], @_[1..$#_], "\n" }

        my %hash  = (a=>1, b=>2, z=>26);
        my @array = (0..10);

        my $arrayref = \@array;
        my $hashref = \%hash;

        show %hash;
        show @array;
        show $hashref;
        show $arrayref;

        show %hash{shift};
        show %hash{a=>'b'};
        show %hash{'a','z'};
        show %hash{qw(a z)};
        show %hash<<a z>>;

        show @array[1];
        show @array[1..3];
        show @array[@array];

        show $hashref{shift};
        show $hashref{a=>'b'};
        show $hashref{'a','z'};
        show $hashref.{qw(a z)};
        show $hashref<<a z>>;
        show $hashref.<<a z>>;

        show $arrayref[1];
        show $arrayref[1..3];
        show $arrayref.[@array];

=head1 DESCRIPTION

The Perl6::Variables module lets you try out the new Perl variable access
syntax in Perl 5.

That syntax is:

        Access through...       Perl 5          Perl 6
        =================       ======          ======
        Scalar variable         $foo            $foo
        Array variable          $foo[$n]        @foo[$n]
        Hash variable           $foo{$k}        %foo{$k}
        Array reference         $foo->[$n]      $foo[$n] (or $foo.[$n])
        Hash reference          $foo->{$k}      $foo{$k} (or $foo.{$k})
        Code reference          $foo->(@a)      $foo(@a) (or $foo.(@a))
        Array slice             @foo[@ns]       @foo[@ns]
        Hash slice              @foo{@ks}       %foo{@ks}

To avoid confusion with bareword keys that look like function calls, Perl 6
reuses the list quoting construct, C<< E<lt>E<lt>E<gt>E<gt> >>, as a sort of subscript.

        Access through...       Perl 5          Perl 6
        =================       ======          ======
        Hash keyed by func      $foo{bar()}     %foo{bar}
        Hash with const key     $foo{'bar'}     %foo<<bar>>

C<$foo{shift}> no longer means C<$foo{'shift'}> as it did in Perl 5 but instead
implies C<< $foo->{shift()} >> or C<$foo.{shift()}>. This is new as of this
proposed XXX version 0.02 and will break large amounts of code.

=head1 DEPENDENCIES

The module is implemented using Filter::Simple
and requires that modules to be installed. 

=head1 AUTHOR

Damian Conway (damian@conway.org)

Scott Walters (scott@slowass.net) choked up a C<< %hashE<lt>E<lt>E<gt>E<gt> >> implementation.
XXX - Scott is proposing this version.

=head1 BUGS

This module is not designed for serious implementation work.

It uses some very simple heuristics to translate Perl 6 syntax back to
Perl 5. It I<will> make mistakes, if you get even moderately tricky inside
a subscript. Version 0.01 was only 20 lines long, for crying out loud.

Nevertheless, bug reports are most welcome.

=head1 COPYRIGHT

Copyright (c) 2001, Damian Conway. All Rights Reserved.
This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License
  (see http://www.perl.com/perl/misc/Artistic.html)
