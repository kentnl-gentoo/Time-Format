=for gpg
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

=head1 NAME

Time::Format - Easy-to-use date/time formatting.

=head1 VERSION

This documentation describes version 0.04 of Time::Format.pm, June 13, 2003.

=cut

use strict;
package Time::Format;
use Exporter;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION = 0.04;
@ISA = 'Exporter';
@EXPORT      = qw(%time time_format);
@EXPORT_OK   = qw(%time %strftime %manip time_format time_strftime time_manip);
%EXPORT_TAGS = (all => \@EXPORT_OK);

use vars qw(%time %strftime %manip);
tie %time,     'Time::Format', \&time_format;
tie %strftime, 'Time::Format', \&time_strftime;
tie %manip,    'Time::Format', \&time_manip;

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

use subs qw(
 STORE    EXISTS    CLEAR    FIRSTKEY    NEXTKEY  );
*STORE = *EXISTS = *CLEAR = *FIRSTKEY = *NEXTKEY = sub
{
    require Carp;
    Carp::croak("Invalid call to Time::Format internal function");
};

# Module finder
{
    my %have;
    sub _have
    {
        my $module = shift || return;
        return $have{$module}  if exists $have{$module};
        eval "use $module ()";
        return $have{$module} = $@? 0 : 1;
    }
}


# Default names for months, days
my %english_names =
(
 Month    => [qw[January February March April May June July August September October November December]],
 Weekday  => [qw[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]],
);
my %names;
my $locale;
my %loc_cache;    # Cache for remembering times that have already been parsed out.

# Internal function to initialize locale info
sub setup_locale
{
    # Do nothing if locale has not changed since %names was set up.
    my $locale_in_use;
    $locale_in_use = POSIX::setlocale(POSIX::LC_TIME()) if _have('POSIX');
    $locale_in_use = '' if  !defined $locale_in_use;
    return if defined $locale  &&  $locale eq $locale_in_use;

    my (@Month, @Mon, @Weekday, @Day);

    eval {
        require I18N::Langinfo;
        I18N::Langinfo->import
                qw(  MON_1   MON_2   MON_3   MON_4   MON_5   MON_6   MON_7   MON_8   MON_9   MON_10   MON_11   MON_12
                     ABMON_1 ABMON_2 ABMON_3 ABMON_4 ABMON_5 ABMON_6 ABMON_7 ABMON_8 ABMON_9 ABMON_10 ABMON_11 ABMON_12
                     DAY_1   DAY_2   DAY_3   DAY_4   DAY_5   DAY_6   DAY_7
                     ABDAY_1 ABDAY_2 ABDAY_3 ABDAY_4 ABDAY_5 ABDAY_6 ABDAY_7
                     langinfo);
        @Month = map langinfo($_),   MON_1(),   MON_2(),   MON_3(),   MON_4(),    MON_5(),    MON_6(),
                                     MON_7(),   MON_8(),   MON_9(),   MON_10(),   MON_11(),   MON_12();
        @Mon   = map langinfo($_), ABMON_1(), ABMON_2(), ABMON_3(), ABMON_4(),  ABMON_5(),  ABMON_6(),
                                   ABMON_7(), ABMON_8(), ABMON_9(), ABMON_10(), ABMON_11(), ABMON_12();
        @Weekday = map langinfo($_),   DAY_1(),   DAY_2(),   DAY_3(),   DAY_4(),   DAY_5(),   DAY_6(),   DAY_7();
        @Day     = map langinfo($_), ABDAY_1(), ABDAY_2(), ABDAY_3(), ABDAY_4(), ABDAY_5(), ABDAY_6(),  ABDAY_7();
    };
    if ($@)    # Internationalization didn't work for some reason; go with English.
    {
        @Month   = @{ $english_names{Month} };
        @Weekday = @{ $english_names{Weekday} };
        @Mon     = map substr($_,0,3), @Month;
        @Day     = map substr($_,0,3), @Weekday;
    }

    # Store in %names, setting proper case
    $names{Month}   = [map ucfirst lc, @Month];
    $names{Weekday} = [map ucfirst lc, @Weekday];
    $names{Mon}     = [map ucfirst lc, @Mon];
    $names{Day}     = [map ucfirst lc, @Day];

    foreach my $name (keys %names)
    {
        my $aref = $names{$name};
        @$aref = map ucfirst lc, @$aref;       # mixed-case
        $names{uc $name} = [map uc, @$aref];   # upper=case
        $names{lc $name} = [map lc, @$aref];   # lower-case
    }

    %loc_cache = ();          # locale changes are rare.  Clear out cache.
    $locale = $locale_in_use;
}


# Helper function -- returns localtime() hashref
sub _loctime
{
    my $time;
    if (@_  &&  $_[0] ne 'time')
    {
        $time = shift;
    }
    else
    {
        $time = _have('Time::HiRes')? Time::HiRes::time() : time();
    }
    my $it = int $time;
    my $msec = sprintf '%03d', int (0.5 +     1_000 * ($time - $it));
    my $usec = sprintf '%06d', int (0.5 + 1_000_000 * ($time - $it));

    setup_locale;

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

    $th{$_} = $names{$_}[$t[6]]   for qw/Weekday WEEKDAY weekday Day DAY day/;
    $th{$_} = $names{$_}[$t[4]-1] for qw/Month   MONTH   month   Mon MON mon/;

    # Date/time pattern
    $th{pat} = qr/(?=[dDy?12hHsaApPMmWwu])(?:Day|DAY|day|yy(?:yy)?|[?12]m[oi]n|[?d]?d|[?h]?h|[?H]?H|[?s]?s|[apAP]\.?[mM]\.?|Mon(?:th)?|MON(?:TH)?|mon(?:th)?|Weekday|WEEKDAY|weekday|mmm|uuuuuu)/;

    return $loc_cache{$it} = \%th;
}


my %disam;    # Disambiguator for 'm' format.
my %dis2 = qw/mm 2 m 1 ?m ?/;
$disam{$_} = "mon" foreach qw/yyyy yy d dd ?d/;           # If year or day is nearby, it's 'month'
$disam{$_} = "min" foreach qw/h hh ?h H HH ?H s ss ?s/;   # If hour or second is nearby, it's 'minute'
sub time_format
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
sub time_strftime
{
    # Check if POSIX is available  (why wouldn't it be?)
    return 'NO_POSIX' unless _have('POSIX');

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
sub time_manip
{
    return "NO_DATEMANIP" unless _have('Date::Manip');

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

 # These can also be used as standalone functions:
 use Time::Format qw(time_format time_strftime time_manip);

 print "Today is ", time_format('yyyy/mm/dd', $some_time), "\n";
 print "POSIXish: ", time_strftime('%A %B %d, %Y',$some_time), "\n";
 print "Date::Manip: ", time_manip('%m/%d/%Y',$some_time), "\n";

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
use, and to take up just as many characters as the output time value
whenever possible.  For example, the four-digit year code is
"C<yyyy>", the three-letter month abbreviation is "C<Mon>".

The format strings are designed with programmers in mind.  What do you
need most frequently?  4-digit year, month, day, 24-based hour,
minute, second -- usually with leading zeroes.  These six are the
easiest formats to use and remember in Time::Format: C<yyyy>, C<mm>,
C<dd>, C<hh>, C<mm>, C<ss>.  Variants on these formats follow a simple
and consistent formula.  This module is for everyone who is weary of
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
    
    ss         second, 00-61
    s          second, 0-61
    ?s         second, 0-61 with leading space if < 10
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

=head1 FUNCTIONS

=over 4

=item time_format

 time_format($format);
 time_format($format, $unix_time);

This is a function interface to C<%time>.  It accepts the same
formatting codes and everything.  This is provided for people who want
their function calls to I<look> like function calls, not hashes. :-)
The following two are equivalent:

 $x = $time{'yyyy/mm/dd'};
 $x = time_format('yyyy/mm/dd');

=item time_strftime

 time_strftime($format, $sec,$min,$hour, $mday,$mon,$year, $wday,$yday,$isdst);
 time_strftime($format, $unixtime);
 time_strftime($format);

This is a function interface to C<%strftime>.  It simply calls
POSIX::C<strftime>, but it does provide a bit of an advantage over
calling C<strftime> directly, in that you can pass the time as a unix
time (seconds since the epoch), or omit it in order to get the current
time.

=item time_manip

 manip($format);
 manip($format,$when);

This is a function interface to C<%manip>.  It calls
Date::Manip::C<UnixDate> under the hood, but it has a slight advantage
over calling C<UnixDate> directly, in that you can omit the C<$when>
parameter in order to get the current time.

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


=head1 INTERNATIONALIZATION

If the I18N::Langinfo module is available, Time::Format will return
weekday and month names in the language appropriate for the current
locale.  If not, English names will be used.

Some testers have suggested making alternate hash variable names
available for different languages.  Thus, for example, a French
programmer could use C<%temps> instead of C<%time>, while a German
could use C<%zeit>.  This would be nice, but would require
Time::Format (and its author!)  to provide an equivalent to the word
'time' in an arbitrary number of languages.

Instead, I would recommend that non-English programmers provide an
alias to C<%time> in their own preferred language.  This can be done
by assigning C<\%time> to a typeglob:

    # French
    use Time::Format;
    use vars '%temps';  *temps = \%time;

    # German
    use Time::Format;
    use vars '%zeit';   *zeit = \%time;

etc.

=head1 EXPORTS

The following symbols are exported into your namespace by default:

 %time
 time_format

The following symbols are available for import into your namespace:

 %strftime
 %manip
 time_strftime
 time_manip

The C<:all> tag will import all of these into your namespace.
Example:

 use Time::Format ':all';

=head1 REQUIREMENTS

 Carp (included with Perl).
 Exporter (included with Perl).
 I18N::Langinfo, if you want non-English locales to work.
 POSIX, if you choose to use %strftime.
 Time::HiRes, if you want the C<mmm> and C<uuuuuu> time formats to work.
 Date::Manip, if you choose to use %manip.
 Time::Local (only needed to run the 'make test' suite).

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

iD8DBQE+6eYwY96i4h5M0egRArhfAKD7Is1I2JShF/D+ioEcGdbIVbOVmACfUCwC
zf8xyGLpwRLL1snQrc96Gbs=
=OQk9
-----END PGP SIGNATURE-----

=end gpg
