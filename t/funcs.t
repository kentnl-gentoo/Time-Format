#!/perl -I..

use strict;
use Test::More tests => 14;

BEGIN { use_ok 'Time::Format', qw(time_format time_strftime time_manip) }
my $tl_notok;
BEGIN { eval 'use Time::Local'; $tl_notok = $@? 1 : 0 }
my $posix_bad;
BEGIN { eval 'use POSIX'; $posix_bad = $@? 1 : 0; delete $INC{'POSIX.pm'}; }
my $manip_bad;
BEGIN { eval 'use Date::Manip'; $manip_bad = $@? 1 : 0; delete $INC{'Date/Manip.pm'}; }

# Get day/month names in current locale
my ($Thursday, $Thu, $June, $Jun);
eval
{
    require I18N::Langinfo;
    I18N::Langinfo->import qw(langinfo DAY_3 MON_12 DAY_5 ABDAY_5 MON_6 ABMON_6);
    ($Thursday, $Thu, $June, $Jun) = map langinfo($_), (DAY_5(), ABDAY_5(), MON_6(), ABMON_6());
};
if ($@)
{
    ($Thursday, $Thu, $June, $Jun) = qw(Thursday Thu June Jun);
}

SKIP:
{
    skip 'Time::Local not available', 13  if $tl_notok;
    my $t = timelocal(9, 58, 13, 5, 5, 103);    # June 5, 2003 at 1:58:09 pm
    $t .= '.987654321';

    # time_format tests (4)
    is time_format('yyyymmdd',$t),  '20030605'  => 'month: mm';
    is time_format('hhmmss',$t),    '135809'    => 'm minute: 1';
    is time_format('MONTH',$t),    uc $June      => 'uc month name';
    is time_format('weekday',$t),  lc $Thursday  => 'lc weekday';

    # time_strftime tests (4)
    SKIP:
    {
        skip 'POSIX not available', 4  if $posix_bad;
        is time_strftime('%d',$t),      '05'        => 'day of month';
        is time_strftime('%D',$t),      '06/05/03'  => '%D';
        is time_strftime('%e',$t),      ' 5'        => 'spaced day';
        is time_strftime('%H',$t),      '13'        => 'hour';
    }

    # time_manip tests (5)
    SKIP:
    {
        skip 'Date::Manip not available', 5 if $manip_bad;
        my $m = 'first thursday in june 2003';
        is time_manip('%Y',$m),      '2003'      => 'year';
        is time_manip('%d',$m),      '05'        => 'day of month';
        is time_manip('%D',$m),      '06/05/03'  => '%D';
        is time_manip('%e',$m),      ' 5'        => 'spaced day';
        is time_manip('%H',$m),      '00'        => 'hour';
    }
}
