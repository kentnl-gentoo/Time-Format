=for gpg
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

=head1 NAME

Time::Format - Easy-to-use date/time formatting.

=head1 VERSION

This documentation describes version 0.07 of Time::Format.pm, June 21, 2003.

=cut

use strict;
package Time::Format;
use Exporter;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION = 0.07;
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
    $self->(@args);
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
 th       => [qw[/th st nd rd th th th th th th th th th th th th th th th th th st nd rd th th th th th th th st]],
);
my %names;
my $locale;
my %loc_cache;              # Cache for remembering times that have already been parsed out.
my $cache_size=0;           # Number of keys in %loc_cache
my $cache_size_limit = 256; # Max number of times to cache

# Date/time pattern
my $code_pat = qr/
                  (?<!\\)                      # Don't expand something preceded by backslash
                  (?=[dDy?12hHsaApPMmWwutT])   # Jump to one of these characters
                  (
                     Day|DAY|day               # Weekday abbreviation
                  |  yy(?:yy)?                 # Year
                  |  [?12]m[oi]n               # backward-compatible Unambiguous month-minute codes
                  |  [?m]?m\{[oi]n\}           # new unambiguous month-minute codes
                  |  th | TH                   # day suffix
                  |  [?d]?d                    # Day
                  |  [?h]?h                    # Hour (24)
                  |  [?H]?H                    # Hour (12)
                  |  [?s]?s                    # Second
                  |  [apAP]\.?[mM]\.?          # am and pm strings
                  |  Mon(?:th)?|MON(?:TH)?|mon(?:th)?    # Month names and abbrev
                  |  Weekday|WEEKDAY|weekday   # Weekday names
                  |  mmm|uuuuuu                # millisecond and microsecond
                  |  tz                        # time zone
                  )/x;

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
    $names{th}      = $english_names{th};
    $names{TH}      = [map uc, @{$english_names{th}}];

    foreach my $name (keys %names)
    {
        my $aref = $names{$name};
        @$aref = map ucfirst lc, @$aref;       # mixed-case
        $names{uc $name} = [map uc, @$aref];   # upper=case
        $names{lc $name} = [map lc, @$aref];   # lower-case
    }

    %loc_cache = ();          # locale changes are rare.  Clear out cache.
    $cache_size = 0;
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
    my ($h,$d,$mx,$wx) = @t[2,3,4,6];    # Month, hour, Month, Weekday indexes.
    $t[4]++;
    my $h12 = $h>12? $h-12 : ($h || 12);
    my $tz = _have('POSIX')? POSIX::strftime('%Z',@t) : '';

    # Populate a whole mess o' data elements
    my %th;

    # NOTE: When adding new codes, be wary of adding any that interfere
    # with the user's ability to use the words "at", "on", or "of" literally.

    # year, hour(12), month, day, hour, minute, second, millisecond, microsecond, time zone
    @th{qw[yyyy H  m{on}  d  h  m{in}  s  mmm uuuuuu tz]} = (    $t[5]+1900, $h12, @t[4,3,2,1,0], $msec, $usec, $tz);
    @th{qw[yy  HH mm{on} dd hh mm{in} ss]} = map $_<10?"0$_":$_, $t[5]%100,  $h12, @t[4,3,2,1,0];
    @th{qw[    ?H ?m{on} ?d ?h ?m{in} ?s]} = map $_<10?" $_":$_,             $h12, @t[4,3,2,1,0];

    # temporary backwards compatibility -- this will go away in v1.0 (or maybe sooner)
    @th{qw[2mon 2min 1mon 1min ?mon ?min]} = @th{qw[mm{on} mm{in} m{on} m{in} ?m{on} ?m{in}]};

    # AM/PM
    my $a = $h<12? 'a' : 'p';
    $th{am}     = $th{pm}     = $a . 'm';
    $th{'a.m.'} = $th{'p.m.'} = $a . '.m.';
    @th{qw/AM PM A.M. P.M./} = map uc, @th{qw/am pm a.m. p.m./};

    $th{$_} = $names{$_}[$wx] for qw/Weekday WEEKDAY weekday Day DAY day/;
    $th{$_} = $names{$_}[$mx] for qw/Month   MONTH   month   Mon MON mon/;
    $th{$_} = $names{$_}[$d]  for qw/th TH/;

    # Don't let the time cache grow boundlessly.
    if (++$cache_size == $cache_size_limit)
    {
        $cache_size = 0;
        %loc_cache = ();
    }
    return $loc_cache{$it} = \%th;
}


my %disam;    # Disambiguator for 'm' format.
$disam{$_} = "{on}" foreach qw/yy d dd ?d/;           # If year or day is nearby, it's 'month'
$disam{$_} = "{in}" foreach qw/h hh ?h H HH ?H s ss ?s/;   # If hour or second is nearby, it's 'minute'
sub time_format
{
    my $fmt  = shift;
    my $time = &_loctime;

    # "Guess" how to interpret ambiguous 'm'
    $fmt =~ s/
              (?<!\\)          # Must not follow a backslash
              (?=[ydhH])       # Must start with one of these
              (                # $1 begins
                (              # $2 begins.  Capture:
                    yy         #     a year
                  | [dhH]      #     a day or hour
                )
              [^?m\\]?         # Followed by something that's not part of a month
              )
              (?![?m]?m\{[io]n\})   # make sure it's not already unambiguous
              (?!mon)          # don't confuse "mon" with "m" "on"
              ([?m]?m)         # $3 is a month code
             /$1$3$disam{$2}/gx;

    $fmt =~ s/(?<!\\)         # ignore things that begin with backslash
              ([?m]?m)        # $1 is a month code
              (               # $2 begins.
                 [^\\]?       #     0 or 1 characters
                 (?=[?dsy])   #     Next char must be one of these
                 (            #     $3 begins.  Capture:
                    \??[ds]   #         a day or a second
                  | yy        #         or a year
                 )
              )/$1$disam{$3}$2/gx;

    $fmt =~ s/$code_pat/$time->{$1}/go;
    $fmt =~ tr/\\//d;
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
 print "Another time is $time{'H:mm am tz', $another_time}\n";
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
when that hash is being interpolated into a string.  This allows you
to do computations on the fly while formatting times and inserting
them into strings.  See the "yesterday" example above.

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
second, "minute" is assumed.

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
    th         day suffix (st, nd, rd, or th)
    TH         uppercase suffix
    
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
    
    tz         time zone abbreviation

Millisecond and microsecond require Time::HiRes, otherwise they'll
always be zero.  Timezone requires POSIX, otherwise it'll be the empty
string.

Anything in the format string other than the above patterns is left
intact.  Also, any character preceded by a backslash is left alone and
not used for any part of a format code.

For the most part, each of the above formatting codes takes up as much
space as the output string it generates.  The exceptions are the codes
whose output is variable length: C<Weekday>, C<Month>, time zone, and
the single-character codes.

Note that the "C<mm>", "C<m>", and "C<?m>" formats are ambiguous.
C<%time> tries to guess whether you meant "month" or "minute" based on
nearby characters in the format string.  Thus, a format of
"C<yyyy/mm/dd hh:mm:ss>" is correctly parsed as "year month day, hour
minute second".  To remove the ambiguity, you can use the following
codes:

    mm{on}       month, 01-12
    m{on}        month, 1-12
    ?m{on}       month, 1-12 with leading space if < 10
    
    mm{in}       minute, 00-59
    m{in}        minute, 0-59
    ?m{in}       minute, 0-59 with leading space if < 10

In other words, append "C<{on}>" or "C<{in}>" to make "C<mm>", "C<m>",
or "C<?m>" unambiguous.

Note: Previous version of Time::Format (before v0.05) used the codes
"C<2mon>", "C<1mon>", "C<?mon>", "C<2min>", "C<1min>", and "C<?min>"
denote unambiguous months and minutes.  These codes are deprecated and
will be removed before v1.0.

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
 $time{'yymmdd',time-86400}       030604
 $time{'dth of Month'}            5th of June

 $time{'H:mm:ss am'}              1:02:14 pm
 $time{'hh:mm:ss.uuuuuu'}         13:02:14.171447

 $time{'yyyy/mm{on}/dd hh:mm{in}:ss.mmm'}  2003/06/05 13:02:14.171
 $time{'yyyy/mm/dd hh:mm:ss.mmm'}          2003/06/05 13:02:14.171

 $time{"It's H:mm."}              It'14 1:02.    # OOPS!
 $time{"It'\\s H:mm."}            It's 1:02.     # Backslash fixes it.

 $strftime{'%A %B %e, %Y'}                 Thursday June  5, 2003
 $strftime{'%A %B %e, %Y',time+86400}      Friday June  6, 2003

 $manip{'%m/%d/%Y'}                                   06/05/2003
 $manip{'%m/%d/%Y','yesterday'}                       06/04/2003
 $manip{'%m/%d/%Y','first monday in November 2000'}   11/06/2000


=head1 INTERNATIONALIZATION

If the I18N::Langinfo module is available, Time::Format will return
weekday and month names in the language appropriate for the current
locale.  If not, English names will be used.

Some testers have suggested making alternate hash variable names
available for different languages.  Thus, for example, a French
programmer could use C<%temps> instead of C<%time>, and a German
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
 POSIX, if you choose to use %strftime or want the C<tz> format to work.
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

iD8DBQE+9NizY96i4h5M0egRAmG5AKDIoinycnP/63nShy4D8RjSGkCCpQCgi2MQ
s6AuQn49+OIwbPR8+xkMzB0=
=tuwY
-----END PGP SIGNATURE-----

=end gpg
