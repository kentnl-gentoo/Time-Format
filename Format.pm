=for gpg
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

=head1 NAME

Time::Format - Easy-to-use date/time formatting.

=head1 VERSION

This documentation describes version 0.12 of Time::Format.pm, July 17, 2003.

=cut

use strict;
package Time::Format;

$Time::Format::VERSION = '0.12';

# Check whether the optional XS module is installed.
eval { require Time::Format_XS };
if (!$@  &&  defined &Time::Format_XS::time_format)
{
    *time_format = sub
    {
        my $fmt = shift;
        my $time = (@_  &&  $_[0] ne 'time')? shift : _have('Time::HiRes')? Time::HiRes::time() : time;
        Time::Format_XS::time_format($fmt, $time);
    }
}
else    # Time::Format_XS not installed.  Load the perl routines to do it.
{
    local $/ = undef;
    eval <DATA>;
    die if $@;
}

my @EXPORT      = qw(%time time_format);
my @EXPORT_OK   = qw(%time %strftime %manip time_format time_strftime time_manip);

# We don't need any of Exporter's fancy features, so it's quicker to
# do the import ourselves.
sub import
{
    my $pkg  = shift;
    my ($cpkg,$file,$line) = caller;
    my @symbols;
    if (@_)
    {
        if (grep $_ eq ':all', @_)
        {
            @symbols = (@EXPORT, @EXPORT_OK, grep $_ ne ':all', @_);
        } else {
            @symbols = @_;
        }
        my %seen;
        @symbols = grep !$seen{$_}++, @symbols;
    } else {
        @symbols = @EXPORT;
    }
    my %ok;
    @ok{@EXPORT_OK,@EXPORT} = ();
    my @badsym = grep !exists $ok{$_}, @symbols;
    if (@badsym)
    {
        my $s = @badsym>1? 's'   : '';
        my $v = @badsym>1? 'are' : 'is';
        die ("The symbol$s ", join(', ', @badsym), " $v not exported by Time::Format at $file line $line.\n");
    }

    no strict 'refs';
    foreach my $sym (@symbols)
    {
        $sym =~ s/^([\$\&\@\%])?//;
        my $pfx = $1 || '&';
        my $calsym = $cpkg . '::' . $sym;
        my $mysym  = $pkg  . '::' . $sym;
        if ($pfx eq '%')
        {
            *$calsym = \%$mysym;
        } elsif ($pfx eq '@') {
            *$calsym = \@$mysym;
        } elsif ($pfx eq '$') {
            *$calsym = \$$mysym;
        } else {
            *$calsym = \&$mysym;
        }
    }
}

# Simple tied-hash implementation.

# Each hash is simply tied to a subroutine reference.  "Fetching" a
# value from the hash invokes the subroutine.  If a hash (tied or
# otherwise) has multiple comma-separated values but the leading
# character is a $, then Perl joins the values with $;.  This makes it
# easy to simulate function calls with tied hashes -- we just split on
# $; to recreate the argument list.

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
    my ($pkg,$file,$line) = caller;
    die "Invalid call to Time::Format internal function at $file line $line.";
};


# Module finder
{
    my %have;
    sub _have
    {
        my $module = shift || return;
        return $have{$module}  if exists $have{$module};

        my $incmod = $module;
        $incmod =~ s!::!/!g;
        return $have{$module} = 1  if exists $INC{"$incmod.pm"};

        eval "require $module";
        return $have{$module} = $@? 0 : 1;
    }
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
__DATA__
#line __LINE__ __FILE__
# The following is only compiled if Time::Format_XS is not available.


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

# Internal function to initialize locale info.
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
        I18N::Langinfo->import qw(langinfo);
        @Month = map langinfo($_),   I18N::Langinfo::MON_1(),    I18N::Langinfo::MON_2(),    I18N::Langinfo::MON_3(),
                                     I18N::Langinfo::MON_4(),    I18N::Langinfo::MON_5(),    I18N::Langinfo::MON_6(),
                                     I18N::Langinfo::MON_7(),    I18N::Langinfo::MON_8(),    I18N::Langinfo::MON_9(),
                                     I18N::Langinfo::MON_10(),   I18N::Langinfo::MON_11(),   I18N::Langinfo::MON_12();
        @Mon   = map langinfo($_),   I18N::Langinfo::ABMON_1(),  I18N::Langinfo::ABMON_2(),  I18N::Langinfo::ABMON_3(),
                                     I18N::Langinfo::ABMON_4(),  I18N::Langinfo::ABMON_5(),  I18N::Langinfo::ABMON_6(),
                                     I18N::Langinfo::ABMON_7(),  I18N::Langinfo::ABMON_8(),  I18N::Langinfo::ABMON_9(),
                                     I18N::Langinfo::ABMON_10(), I18N::Langinfo::ABMON_11(), I18N::Langinfo::ABMON_12();
        @Weekday = map langinfo($_), I18N::Langinfo::DAY_1(),    I18N::Langinfo::DAY_2(),    I18N::Langinfo::DAY_3(),
            I18N::Langinfo::DAY_4(), I18N::Langinfo::DAY_5(),    I18N::Langinfo::DAY_6(),    I18N::Langinfo::DAY_7();
        @Day     = map langinfo($_), I18N::Langinfo::ABDAY_1(),  I18N::Langinfo::ABDAY_2(),  I18N::Langinfo::ABDAY_3(),
          I18N::Langinfo::ABDAY_4(), I18N::Langinfo::ABDAY_5(),  I18N::Langinfo::ABDAY_6(),  I18N::Langinfo::ABDAY_7();
    };
    if ($@)    # Internationalization didn't work for some reason; go with English.
    {
        @Month   = @{ $english_names{Month} };
        @Weekday = @{ $english_names{Weekday} };
        @Mon     = map substr($_,0,3), @Month;
        @Day     = map substr($_,0,3), @Weekday;
    }

    # Store in %names, setting proper case
    $names{Month}   = \@Month;
    $names{Weekday} = \@Weekday;
    $names{Mon}     = \@Mon;
    $names{Day}     = \@Day;
    $names{th}      = $english_names{th};
    $names{TH}      = [map uc, @{$names{th}}];

    foreach my $name (keys %names)
    {
        my $aref = $names{$name};              # locale-native case
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
    my $msec = sprintf '%03d', int (    1_000 * ($time - $it));
    my $usec = sprintf '%06d', int (1_000_000 * ($time - $it));

    setup_locale;

    # Cached, because I expect this'll be called on the same time values frequently.
    if (exists $loc_cache{$it})
    {
        my $h = $loc_cache{$it};
        @$h{qw/mmm uuuuuu/} = ($msec, $usec);
        return $h;
    }

    my @t = localtime $it;
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

# The heart of the module.  Didja ever see so many wicked regexes in a row?

my %disam;    # Disambiguator for 'm' format.
$disam{$_} = "{on}" foreach qw/yy d dd ?d/;           # If year or day is nearby, it's 'month'
$disam{$_} = "{in}" foreach qw/h hh ?h H HH ?H s ss ?s/;   # If hour or second is nearby, it's 'minute'
sub time_format
{
    my $fmt  = shift;
    my $time = &_loctime;

    # Remove \Q...\E sequences
    my $rc;
    if (index($fmt, '\Q') >= 0)
    {
        $rc = init_store($fmt);
        $fmt =~ s/\\Q(.*?)(?:\\E|$)/remember($1)/seg;
    }

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

    # Ambiguous 'm', part 2.
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

    # The Big Date/Time Pattern
    $fmt =~ s/
              (?<!\\)                      # Don't expand something preceded by backslash
              (?=[dDy?hHsaApPMmWwutT])     # Jump to one of these characters
              (
                 [Dd]ay|DAY                # Weekday abbreviation
              |  yy(?:yy)?                 # Year
              |  [?m]?m\{[oi]n\}           # Unambiguous month-minute codes
              |  th | TH                   # day suffix
              |  [?d]?d                    # Day
              |  [?h]?h                    # Hour (24)
              |  [?H]?H                    # Hour (12)
              |  [?s]?s                    # Second
              |  [apAP]\.?[mM]\.?          # am and pm strings
              |  [Mm]on(?:th)?|MON(?:TH)?  # Month names and abbrev
              |  [Ww]eekday|WEEKDAY        # Weekday names
              |  mmm|uuuuuu                # millisecond and microsecond
              |  tz                        # time zone
             )/$time->{$1}/gx;

    # Simulate \U \L \u \l
    $fmt =~ s/((?:\\[UL])+)((?:\\[ul])+)/$2$1/g;
    $fmt =~ s/\\U(.*?)(?=\\[EULul]|$)/\U$1/gs;
    $fmt =~ s/\\L(.*?)(?=\\[EULul]|$)/\L$1/gs;
    $fmt =~ s/\\l(.)/\l$1/gs;
    $fmt =~ s/\\u(.)/\u$1/gs;
    $fmt =~ s/\\E//g;

    $fmt =~ tr/\\//d;    # Remove extraneous backslashes.

    if (defined $rc)    # Fixup \Q \E regions.
    {
        $fmt =~ s/$rc(..)/recall($1)/seg;
    }
    return $fmt;
}

# Code for remembering/restoring \Q...\E regions.
# init_store finds a sigil character that's not used within the format string.
# remember stores a string in the next slot in @store, and returns a coded replacement.
# recall looks up and returns a string from @store.
{
    my $rcode;
    my @store;
    my $stx;

    sub init_store
    {
        my $str = shift;
        $stx = 0;
        return $rcode = "\x01" unless index($str,"\x01") >= 0;

        for ($rcode="\x02"; $rcode<"\xFF"; $rcode=chr(1+ord $rcode))
        {
            return $rcode unless index($str, $rcode) >= 0;
        }
        die "Time::Format cannot process string: no unique characters left.";
    }

    sub remember
    {
        my $enc;
        do    # Must not return a code that contains a backslash
        {
            $enc = pack 'S', $stx++;
        } while index($enc, '\\') >= 0;

        $store[$stx-1] = shift;
        return join '', map "\\$_", split //, "$rcode$enc";    # backslash-escape it!
    }

    sub recall
    {
        return $store[unpack 'S', shift];
    }
}

__END__

=head1 SYNOPSIS

 use Time::Format qw(%time %strftime %manip);

 $time{$format}
 $time{$format, $unixtime}
 
 print "Today is $time{'yyyy/mm/dd'}\n";
 print "Yesterday was $time{'yyyy/mm/dd', time-24*60*60}\n";
 print "The time is $time{'hh:mm:ss'}\n";
 print "Another time is $time{'H:mm am tz', $another_time}\n";
 print "Timestamp: $time{'yyyymmdd.hhmmss.mmm'}\n";

 $strftime{$format}
 $strftime{$format, $unixtime}
 $strftime{$format, $sec,$min,$hour, $mday,$mon,$year, $wday,$yday,$isdst}
 
 print "POSIXish: $strftime{'%A, %B %d, %Y', 0,0,0,12,11,95,2}\n";
 print "POSIXish: $strftime{'%A, %B %d, %Y', 1054866251}\n";
 print "POSIXish: $strftime{'%A, %B %d, %Y'}\n";       # current time

 $manip{$format};
 $manip{$format,$when};
 
 print "Date::Manip: $manip{'%m/%d/%Y'}\n";            # current time
 print "Date::Manip: $manip{'%m/%d/%Y','last Tuesday'}\n";

 # These can also be used as standalone functions:
 use Time::Format qw(time_format time_strftime time_manip);
 
 print "Today is ", time_format('yyyy/mm/dd', $some_time), "\n";
 print "POSIXish: ", time_strftime('%A %B %d, %Y',$some_time), "\n";
 print "Date::Manip: ", time_manip('%m/%d/%Y',$some_time), "\n";

=head1 DESCRIPTION

This module creates global pseudovariables which format dates and
times, according to formatting codes you pass to it in strings.

The C<%time> formatting codes are designed to be easy to remember and
use, and to take up just as many characters as the output time value
whenever possible.  For example, the four-digit year code is
"C<yyyy>", the three-letter month abbreviation is "C<Mon>".

The nice thing about having a variable-like interface instead
of function calls is that the values can be used inside of strings (as
well as outside of strings in ordinary expressions).  Dates are
frequently used within strings (log messages, output, data records,
etc.), so having the ability to interpolate them directly is handy.

Perl allows arbitrary expressions within curly braces of a hash, even
when that hash is being interpolated into a string.  This allows you
to do computations on the fly while formatting times and inserting
them into strings.  See the "yesterday" example above.

The format strings are designed with programmers in mind.  What do you
need most frequently?  4-digit year, month, day, 24-based hour,
minute, second -- usually with leading zeroes.  These six are the
easiest formats to use and remember in Time::Format: C<yyyy>, C<mm>,
C<dd>, C<hh>, C<mm>, C<ss>.  Variants on these formats follow a simple
and consistent formula.  This module is for everyone who is weary of
trying to remember I<strftime(3)>'s arcane codes, or of endlessly
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

If the companion module Time::Format_XS is also installed,
Time::Format will detect and use it.  This will result in a
significant speed increase for C<%time> and C<time_format>.


=head1 VARIABLES

=over 4

=item time

 $time{$format}
 $time{$format,$unixtime};

Formats a unix time number (seconds since the epoch) according to the
specified format.  If the time expression is omitted, the current time
is used.  The format string may contain any of the following:

    yyyy       4-digit year
    yy         2-digit year
    
    m          1- or 2-digit month, 1-12
    mm         2-digit month, 01-12
    ?m         month with leading space if < 10
    
    Month      full month name, mixed-case
    MONTH      full month name, uppercase
    month      full month name, lowercase
    Mon        3-letter month abbreviation, mixed-case
    MON  mon   ditto, uppercase and lowercase versions
    
    d          day number, 1-31
    dd         day number, 01-31
    ?d         day with leading space if < 10
    th         day suffix (st, nd, rd, or th)
    TH         uppercase suffix
    
    Weekday    weekday name, mixed-case
    WEEKDAY    weekday name, uppercase
    weekday    weekday name, lowercase
    Day        3-letter weekday name, mixed-case
    DAY  day   ditto, uppercase and lowercase versions
    
    h          hour, 0-23
    hh         hour, 00-23
    ?h         hour, 0-23 with leading space if < 10
    
    H          hour, 1-12
    HH         hour, 01-12
    ?H         hour, 1-12 with leading space if < 10
    
    m          minute, 0-59
    mm         minute, 00-59
    ?m         minute, 0-59 with leading space if < 10
    
    s          second, 0-59
    ss         second, 00-59
    ?s         second, 0-59 with leading space if < 10
    mmm        millisecond, 000-999
    uuuuuu     microsecond, 000000-999999
    
    am   a.m.  The string "am" or "pm" (second form with periods)
    pm   p.m.  same as "am" or "a.m."
    AM   A.M.  same as "am" or "a.m." but uppercase
    PM   P.M.  same as "AM" or "A.M."
    
    tz         time zone abbreviation

Millisecond and microsecond require Time::HiRes, otherwise they'll
always be zero.  Timezone requires POSIX, otherwise it'll be the empty
string.  The second codes (C<s>, C<ss>, C<?s>) can be 60 or 61 in rare
circumstances (leap seconds, if your system supports such).

Anything in the format string other than the above patterns is left
intact.  Any character preceded by a backslash is left alone and
not used for any part of a format code.  See the L<QUOTING> section
for more details.

For the most part, each of the above formatting codes takes up as much
space as the output string it generates.  The exceptions are the codes
whose output is variable length: C<Weekday>, C<Month>, time zone, and
the single-character codes.

The mixed-case "Month", "Mon", "Weekday", and "Day" codes return the
name of the month or weekday in the preferred case representation for
the locale currently in effect.  Thus in an English-speaking locale,
the seventh month would be "July" (uppercase first letter, lowercase
rest); while in a French-speaking locale, it would be "juillet" (all
lowercase).  See the L<QUOTING> section for ways to control the case
of month/weekday names.

Note that the "C<mm>", "C<m>", and "C<?m>" formats are ambiguous.
C<%time> tries to guess whether you meant "month" or "minute" based on
nearby characters in the format string.  Thus, a format of
"C<yyyy/mm/dd hh:mm:ss>" is correctly parsed as "year month day, hour
minute second".  If C<%time> cannot determine whether you meant
"month" or "minute", it leaves the C<mm>, C<m>, or C<?m> untranslated.
To remove the ambiguity, you can use the following codes:

    m{on}        month, 1-12
    mm{on}       month, 01-12
    ?m{on}       month, 1-12 with leading space if < 10
    
    m{in}        minute, 0-59
    mm{in}       minute, 00-59
    ?m{in}       minute, 0-59 with leading space if < 10

In other words, append "C<{on}>" or "C<{in}>" to make "C<m>", "C<mm>",
or "C<?m>" unambiguous.

Note: Previous version of Time::Format (before v0.05) used the codes
"C<2mon>", "C<1mon>", "C<?mon>", "C<2min>", "C<1min>", and "C<?min>"
to denote unambiguous months and minutes.  These codes have been
removed and are no longer supported.

=item strftime

 $strftime{$format, $sec,$min,$hour, $mday,$mon,$year, $wday,$yday,$isdst}
 $strftime{$format, $unixtime}
 $strftime{$format}

For those who prefer I<strftime(3)>'s weird % formats, or who need
POSIX compliance, or who need week numbers or other features C<%time>
does not provide.

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
Date::Manip::C<UnixDate> under the hood, but it has a very slight
advantage over calling C<UnixDate> directly, in that you can omit the
C<$when> parameter in order to get the current time.

=back

=head1 QUOTING

This section applies to the format strings used by C<%time> and
C<time_format> only.

Sometimes it is necessary to suppress expansion of some format
characters in a format string.  For example:

    $time{'Hour: hh; Minute: mm{in}; Second: ss'};

In the above expression, the "H" in "Hour" would be expanded,
as would the "d" in "Second".  The result would be something like:

    8our: 08; Minute: 10; Secon17: 30

It would not be a good solution to break the above statement out
into three calls to %time:

    "Hour: $time{hh}; Minute: $time{'mm{in}'}; Second: $time{ss}"

because the time could change from one call to the next, which would
be a problem when the numbers roll over (for example, a split second
after 7:59:59).

For this reason, you can escape individual format codes with a
backslash:

    $time{'\Hour: hh; Minute: mm{in}; Secon\d: ss'};

Note that with double-quoted (and qq//) strings, the backslash must be
doubled, because Perl first interpolates the string:

    $time{"\\Hour: hh; Minute: mm{in}; Secon\\d: ss"};

For added convenience, Time::Format simulates Perl's built-in \Q and
\E inline quoting operators.  Anything in a string between a \Q and \E
will not be interpolated as any part of any formatting code:

    $time{'\QHour:\E hh; \QMinute:\E mm{in}; \QSecond:\E ss'};

Again, within interpolated strings, the backslash must be doubled, or
else Perl will interpret and remove the \Q...\E sequence before
Time::Format gets it:

    $time{"\\QHour:\\E hh; \\QMinute:\\E mm{in}; \\QSecond\\E: ss"};

Time::Format also recognizes and simulates the \U, \L, \u, and \l
sequences.  This is really only useful for finer control of the Month,
Mon, Weekday, and Day formats.  For example, in some locales, the
month names are all-lowercase by default.  At the start of a sentence,
you may want to ensure that the first character is uppercase:

    $time{'\uMonth \Qis the finest month of all.'};

Again, be sure to use \Q, and be sure to double the backslashes in
interpolated strings, otherwise you'll get something ugly like:

    July i37 ste fine37t july of all.

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

 # Rename a file based on today's date:
 rename $file, "$file_$time{yyyymmdd}";
 
 # Rename a file based on its last-modify date:
 rename $file, "$file_$time{'yyyymmdd',(stat $file)[9]}";

 # stftime examples
 $strftime{'%A %B %d, %Y'}                 Thursday June 05, 2003
 $strftime{'%A %B %d, %Y',time+86400}      Friday June 06, 2003

 # manip examples
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

=head1 BUGS

The format string used by C<%time> must not have $; as a substring
anywhere.  $; (by default, ASCII character 28, or 1C hex) is used to
separate values passed to the tied hash, and thus Time::Format will
interpret your format string to be two or more arguments if it
contains $;.  The C<time_format> function does not have this problem.

=head1 REQUIREMENTS

 I18N::Langinfo, if you want non-English locales to work.
 POSIX, if you choose to use %strftime or want the C<tz> format to work.
 Time::HiRes, if you want the C<mmm> and C<uuuuuu> time formats to work.
 Date::Manip, if you choose to use %manip.
 Time::Local (only needed to run the 'make test' suite).
 Time::Format_XS is optional but will make C<%time> and C<time_format>
     much faster.

=head1 AUTHOR / COPYRIGHT

Eric J. Roode, roode@cpan.org

Copyright (c) 2003 by Eric J. Roode. All Rights Reserved.  This module
is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=begin gpg

-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.2.2 (GNU/Linux)

iD8DBQE/GuPGY96i4h5M0egRAlVdAKC6qSNyzMcbL9m13VvtukT9lO2XWgCg+tNs
nkaB23Rg2jZM86ELj7Avu1k=
=XMkw
-----END PGP SIGNATURE-----

=end gpg
