=for gpg
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

=head1 NAME

Time::Format - Easy-to-use date/time formatting.

=head1 VERSION

This documentation describes version 0.03 of Time::Format.pm, June 11, 2003.

=cut

use strict;
package Time::Format;
use Exporter;

use vars qw($VERSION @ISA @EXPORT_OK %EXPORT_TAGS);
$VERSION = 0.03;
@ISA = 'Exporter';
@EXPORT_OK   = qw(%time %strftime %manip);
%EXPORT_TAGS = (all => \@EXPORT_OK);

my @Months   = qw/January February March April May June July August September October November December/;
my @Weekdays = qw/Sunday Monday Tuesday Wednesday Thursday Friday Saturday/;

use vars qw(%time %strftime %manip);
tie %time,     'Time::Format', \&tf_time;
tie %strftime, 'Time::Format', \&tf_strftime;
tie %manip,    'Time::Format', \&tf_manip;

sub TIEHASH
{
    my $class = shift;
    my $func  = shift || die "Bad call to $class\::TIEHASH";
    bless $func, $class;
}

sub FETCH
{
    my $self = shift;
    my $key  = shift;
    my @args = split $;, $key, -1;
    join $", $self->(@args);
}

*STORE = *EXISTS = *CLEAR = *FIRSTKEY = *NEXTKEY = sub
{
    require Carp;
    Carp::croak("Invalid call to Time::Format internal function");
};


# Helper function -- returns localtime() hashref
my %loc_cache;
my ($checked_hires, $hires_ok);
sub _loctime
{
    my $time;
    if (@_  &&  $_[0] ne 'time')
    {
        $time = shift;
    }
    else
    {
        unless ($checked_hires)
        {
            eval 'use Time::HiRes';
            $hires_ok = 1 unless $@;
        }
        $time = $hires_ok? Time::HiRes::time() : time();
    }
    my $it = int $time;
    my $msec = sprintf '%03d', int (0.5 +     1_000 * ($time - $it));
    my $usec = sprintf '%06d', int (0.5 + 1_000_000 * ($time - $it));

    # Cached, because I expect this'll be called on the same time values frequently.
    if (exists $loc_cache{$it})
    {
        my $h = $loc_cache{$it};
        @$h{qw/mmm uuuuuu/} = ($msec, $usec);
        return $h;
    }

    my @t = localtime int $time;
    $t[4]++; $t[5]+=1900;
    my $h12 = $t[2]>12? $t[2]-12 : ($t[2] || 12);

    # Populate a whole mess o' data elements
    my %th;

    # year, month, day, hour, minute, second, millisecond, microsecon
    @th{qw[yyyy 1mon d h 1min s H mmm uuuuuu]} = (@t[5,4,3,2,1,0], $h12, $msec, $usec);
    @th{qw[yy 2mon dd hh HH 2min ss hh]} = map $_<10?"0$_":$_, $t[5]%100, @th{qw[1mon d h H 1min s]}, $t[2];
    @th{qw[?mon ?d ?h ?H ?min ?s]} = map $_<10?" $_":$_, @th{qw[1mon d h H 1min s]};

    # AM/PM
    $th{am}     = $th{pm}     = $th{hh}<12? 'am'   : 'pm';
    $th{'a.m.'} = $th{'p.m.'} = $th{hh}<12? 'a.m.' : 'p.m.';
    @th{qw/AM PM A.M. P.M./} = map uc, @th{qw/am pm a.m. p.m./};

    # Weekday name
    $th{Weekday} = $Weekdays[$t[6]];
    $th{WEEKDAY} = uc $th{Weekday};
    $th{weekday} = lc $th{Weekday};
    @th{qw/Day DAY day/} = map substr($_,0,3), @th{qw/Weekday WEEKDAY weekday/};

    # Month name
    $th{Month} = $Months[$t[4]-1];
    $th{MONTH} = uc $th{Month};
    $th{month} = lc $th{Month};
    @th{qw/Mon MON mon/} = map substr($_,0,3), @th{qw/Month MONTH month/};

    # Date/time pattern
    $th{pat} = qr/(?=[dDy?12hHsaApPMmWwu])(?:Day|DAY|day|yy(?:yy)?|[?12]m[oi]n|[?d]?d|[?h]?h|[?H]?H|[?s]?s|[apAP]\.?[mM]\.?|Mon(?:th)?|MON(?:TH)?|mon(?:th)?|Weekday|WEEKDAY|weekday|mmm|uuuuuu)/;

    return $loc_cache{$it} = \%th;
}


my %disam;    # Disambiguator for 'm' format.
my %dis2 = qw/mm 2 m 1 ?m ?/;
$disam{$_} = "mon" foreach qw/yyyy yy d dd ?d/;           # If year or day is nearby, it's 'month'
$disam{$_} = "min" foreach qw/h hh ?h H HH ?H s ss ?s/;   # If hour or second is nearby, it's 'minute'
sub tf_time
{
    my $fmt  = shift;
    my $time = &_loctime;

    # "Guess" how to interpret ambiguous 'm'
    $fmt =~ s/((?=[ydhH?])(yy(?:yy)?|[?d]?d|[?h]?h|[?H]?H)[^?m]?)([?m]?m)/$1$dis2{$3}$disam{$2}/g;
    $fmt =~ s/([?m]?m)(.?(?=[?dsy])([?d]?d|[?s]?s|yy(?:yy)?))/$dis2{$1}$disam{$3}$2/g;

    $fmt =~ s/($time->{pat})/$time->{$1}/go;
    return $fmt;
}


# POSIX strftime, for people who like those weird % formats.
my ($checked_posix, $have_posix);
sub tf_strftime
{
    # Check if POSIX is available  (why wouldn't it be?)
    unless ($checked_posix)
    {
        eval 'use POSIX';
        $have_posix = 1 unless $@;
    }
    return 'NO_POSIX' unless $have_posix;

    my $fmt = shift;
    my @time;

    # If more than one arg, assume they're doing the whole arg list
    if (@_ > 1)
    {
        @time = @_;
    }
    else    # use unix time (current or passed)
    {
        my $time = @_? shift : time;
        @time = localtime $time;
    }

    return POSIX::strftime($fmt, @time);
}


# Date::Manip interface
my ($checked_manip, $have_manip);
sub tf_manip
{
    unless ($checked_manip)
    {
        eval 'use Date::Manip';
        $have_manip = 1 unless $@;
    }
    return "NO_DATEMANIP" unless $have_manip;

    my $fmt  = shift;
    my $time = @_? shift : 'now';

    $time = $1 if $time =~ /^\s* (epoch \s+ \d+)/x;

    return Date::Manip::UnixDate($time, $fmt);
}

1;
__END__

=head1 SYNOPSIS

 use Time::Format qw(%time %strftime %manip);

 print "Today is $time{'yyyy/mm/dd'}\n";
 print "Yesterday was $time{'yyyy/mm/dd', time-24*60*60}\n";
 print "The time is $time{'hh:mm:ss'}\n";
 print "Another time is $time{'H:mm am', $another_time}\n";
 print "Timestamp: $time{'yyyymmdd.hhmmss.mmm'}\n";

 print "POSIXish: $strftime{'%A, %B %d, %Y', 0,0,0,12,11,95,2}\n";
 print "POSIXish: $strftime{'%A, %B %d, %Y', 1054866251}\n";
 print "POSIXish: $strftime{'%A, %B %d, %Y'}\n";       # current time

 print "Date::Manip: $manip{'%m/%d/%Y'}\n";            # current time
 print "Date::Manip: $manip{'%m/%d/%Y','last Tuesday'}\n";

=head1 DESCRIPTION

This module creates global pseudovariables which format dates and
times.  The nice thing about having a variable-like interface instead
of function calls is that the values can be used inside of strings (as
well as outside of strings in ordinary expressions).  Dates are
frequently used within strings (log messages, output, data records,
etc), so having the ability to interpolate them directly is handy.

Perl allows arbitrary expressions within curly braces of a hash, even
when that hash is being interpolated into a string.  See the
"yesterday" example above.

The C<%time> formatting codes are designed to be easy to remember and
use, and to take up as many characters as the output time value
whenever possible.  For example, the four-digit year code is
"C<yyyy>".

The format strings are designed with programmers in mind.  What do you
need most frequently?  4-digit year, month, day, 24-based hour,
minute, second -- usually with leading zeroes.  These six are the
easiest formats to use and remember in Time::Format: C<yyyy>, C<mm>,
C<dd>, C<hh>, C<mm>, C<ss>.  Variants on these formats follow a simple
and consistent formula.  This module is for everyone who is sick of
trying to remember L<strftime(3)>'s arcane codes, or of endlessly
writing C<$t[4]++; $t[5]+=1900>.

Note that C<mm> (and related codes) are used both for months and
minutes.  This is a feature.  C<%time> resolves the ambiguity by
examining other nearby formatting codes.  If it's in the context of a
year or a day, "month" is assumed.  If in the context of an hour or a
minute, "minute" is assumed.

The format strings are not meant to encompass every date/time need
ever conceived.  But hey, how often do you need the day of the year
(strftime's C<%j>) or the week number (strftime's C<%W>)?

For capabilities that C<%time> does not provide, C<%strftime> provides
an interface to POSIX's C<strftime>, and C<%manip> provides an
interface to the Date::Manip module's C<UnixDate> function.

=head1 VARIABLES

=over 4

=item time

 $time{$format}
 $time{$format,$unixtime};

Formats a unix time number according to the specified format.  If the
time expression is omitted, the current time is used.  The format
string may contain any of the following:

    yyyy       4-digit year
    yy         2-digit year
    
    mm         2-digit month, 01-12
    m          1- or 2-digit month, 1-12
    ?m         month with leading space if < 10
    
    Month      full month name, mixed-case
    MONTH      full month name, uppercase
    month      full month name, lowercase
    Mon        3-letter month abbreviation, mixed-case
    MON  mon   ditto, uppercase and lowercase versions
    
    dd         day number, 01-31
    d          day number, 1-31
    ?d         day with leading space if < 10
    
    Weekday    weekday name, mixed-case
    WEEKDAY    weekday name, uppercase
    weekday    weekday name, lowercase
    Day        3-letter weekday name, mixed-case
    DAY  day   ditto, uppercase and lowercase versions
    
    hh         hour, 00-23
    h          hour, 0-23
    ?h         hour, 0-23 with leading space if < 10
    
    HH         hour, 01-12
    H          hour, 1-12
    ?H         hour, 1-12 with leading space if < 10
    
    mm         minute, 00-59
    m          minute, 0-59
    ?m         minute, 0-59 with leading space if < 10
    
    ss         second, 00-60
    s          second, 0-60
    ?s         second, 0-60 with leading space if < 10
    mmm        millisecond, 000-999
    uuuuuu     microsecond, 000000-999999
    
    am   a.m.  The string "am" or "pm" (second form with periods)
    pm   p.m.  same as "am" or "a.m."
    AM   A.M.  same as "am" or "a.m." but uppercase
    PM   P.M.  same as "AM" or "A.M."

Millisecond and microsecond require Time::HiRes, otherwise they'll
always be zero.

Anything in the format string other than the above patterns is left
intact.

For the most part, each of the above formatting codes takes up as much
space as the output string it generates.  The exceptions are the codes
whose output is variable length: C<Weekday>, C<Month>, and the
single-character codes.

Note that the "C<mm>", "C<m>", and "C<?m>" formats are ambiguous.
C<%time> tries to guess whether you meant "month" or "minute" based on
nearby characters in the format string.  Thus, a format of
"C<yyyy/mm/dd hh:mm:ss>" is parsed as "year month day, hour minute
second".  To remove the ambiguity, you can use the following codes:

    2mon       month, 01-31
    1mon       month, 1-31
    ?mon       month, 1-31 with leading space if < 10
    
    2min       minute, 00-59
    1min       minute, 0-59
    ?min       minute, 0-59 with leading space if < 10


=item strftime

 $strftime{$format, $sec,$min,$hour, $mday,$mon,$year, $wday,$yday,$isdst}
 $strftime{$format, $unixtime}
 $strftime{$format}

For those who prefer L<strftime(3)>'s weird % formats, or who need
POSIX compliance.


=item manip

 $manip{$format};
 $manip{$format,$when};

Provides an interface to the Date::Manip module's C<UnixDate>
function.  This function is rather slow, but can parse a very wide
variety of date input.  See the Date::Manip module for details
about the formats accepted.

If you want to use the C<%time> codes, but need the input flexibility
of C<%manip>, you can use Date::Manip's C<%s> format and nest the
calls:

 print "$time{'yyyymmdd',$manip{'%s','last sunday'}}";

=back

=head1 EXAMPLES

 $time{'Weekday Month d, yyyy'}   Thursday June 5, 2003
 $time{'Day Mon d, yyyy'}         Thu Jun 5, 2003
 $time{'dd/mm/yyyy'}              05/06/2003
 $time{yymmdd}                    030605

 $time{'H:mm:ss am'}              1:02:14 pm
 $time{'hh:mm:ss.uuuuuu'}         13:02:14.171447

 $time{'yyyy/2mon/dd hh:2min:ss.mmm'}   2003/06/05 13:02:14.171
 $time{'yyyy/mm/dd hh:mm:ss.mmm'}       2003/06/05 13:02:14.171

 $strftime{'%A %B %e, %Y'}        Thursday June  5, 2003

 $manip{'%m/%d/%Y'}               06/05/2003
 $manip{'%m/%d/%Y','yesterday'}   06/04/2003
 $manip{'%m/%d/%Y','first monday in November 2000'}  11/06/2000


=head1 EXPORTS

The following symbols are available for import into your namespace.
No symbols are exported by default.

 %time
 %strftime
 %manip

The C<:all> tag will import all of these into your namespace.
Example:

 use Time::Format ':all';

=head1 REQUIREMENTS

 Carp (included with Perl)
 Exporter (included with Perl)
 POSIX, if you choose to use %strftime
 Time::HiRes, if you want the C<mmm> and C<uuuuuu> time formats to work
 Date::Manip, if you choose to use %manip
 Time::Local (only needed to run the 'make test' suite)


=head1 AUTHOR / COPYRIGHT

Eric J. Roode, roode@cpan.org

Copyright (c) 2003 by Eric J. Roode. All Rights Reserved.  This module
is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

If you have suggestions for improvement, please drop me a line.  If
you make improvements to this software, I ask that you please send me
a copy of your changes. Thanks.

=begin gpg

-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.2.2 (GNU/Linux)

iD8DBQE+52SmY96i4h5M0egRApTQAJ9jyF8Hl3EP+jpO4xkBkQdxJEIDTQCeKRTK
poxi0sAdqNSTPlptzrdErrg=
=S0Yi
-----END PGP SIGNATURE-----

=end gpg
