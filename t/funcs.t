#!/perl -I..

use strict;
use Test::More tests => 15;

BEGIN { $Time::Format::NOXS = 1 }
BEGIN { use_ok 'Time::Format', qw(time_format time_strftime time_manip) }
my $tl_notok;
BEGIN { eval 'use Time::Local'; $tl_notok = $@? 1 : 0 }
my $posix_bad;
BEGIN {
    eval 'use POSIX ()';
    $posix_bad = $@? 1 : 0;
    delete $INC{'POSIX.pm'};
    %POSIX:: = ();
}
my $manip_bad;
my $manip_notz;
BEGIN {
    eval 'use Date::Manip ()';
    $manip_bad = $@? 1 : 0;
    unless ($manip_bad)
    {
        # If Date::Manip can't determine the time zone, it'll bomb out of the tests.
        eval 'Date::Manip::Date_TimeZone ()';
        $manip_notz = $@? 1 : 0;
    }
    delete $INC{'Date/Manip.pm'};
    %Date::Manip:: = ();
}

# Get day/month names in current locale
my ($Thursday, $Thu, $June, $Jun);
eval
{
    require I18N::Langinfo;
    I18N::Langinfo->import(qw(langinfo DAY_3 MON_12 DAY_5 ABDAY_5 MON_6 ABMON_6));
    ($Thursday, $Thu, $June, $Jun) = map ucfirst lc langinfo($_), (DAY_5(), ABDAY_5(), MON_6(), ABMON_6());
};
if ($@)
{
    ($Thursday, $Thu, $June, $Jun) = qw(Thursday Thu June Jun);
}

SKIP:
{
    skip 'Time::Local not available', 14  if $tl_notok;
    my $t = timelocal(9, 58, 13, 5, 5, 103);    # June 5, 2003 at 1:58:09 pm
    $t .= '.987654321';

    # time_format tests (4)
    is time_format('yyyymmdd',$t),  '20030605'  => 'month: mm';
    is time_format('hhmmss',$t),    '135809'    => 'm minute: 1';
    is time_format('MONTH',$t),    uc $June      => 'uc month name';
    is time_format('weekday',$t),  lc $Thursday  => 'lc weekday';

    # time_strftime tests (5)
    SKIP:
    {
        skip 'POSIX not available', 5  if $posix_bad;

        # Be sure to use ONLY ansi standard strftime codes here,
        # otherwise the tests will fail on somebody's system somewhere.

        is time_strftime('%d',$t),      '05'        => 'day of month';
        is time_strftime('%m',$t),      '06'        => 'Month number';
        is time_strftime('%M',$t),      '58'        => 'minute';
        is time_strftime('%H',$t),      '13'        => 'hour';
        is time_strftime('%Y',$t),      '2003'      => 'year';
    }

    # time_manip tests (5)
    SKIP:
    {
        skip 'Date::Manip not available',             5 if $manip_bad;
        skip 'Date::Manip cannot determine timezone', 5 if $manip_notz;
        my $m = 'first thursday in june 2003';
        is time_manip('%Y',$m),      '2003'      => 'year';
        is time_manip('%d',$m),      '05'        => 'day of month';
        is time_manip('%D',$m),      '06/05/03'  => '%D';
        is time_manip('%e',$m),      ' 5'        => 'spaced day';
        is time_manip('%H',$m),      '00'        => 'hour';
    }
}
