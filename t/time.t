#!/perl -I..

use strict;
use Test::More tests => 70;

BEGIN { use_ok 'Time::Format', qw(%time) }
my $tl_notok;
BEGIN { eval 'use Time::Local'; $tl_notok = $@? 1 : 0 }

SKIP:
{
    skip 69, 'Time::Local not available'  if $tl_notok;
    my $t = timelocal 9, 58, 13, 5, 5, 103;    # June 5, 2003 at 1:58:09 pm
    $t .= '.987654321';

    # Basic tests (40)
    is $time{'yyyy',$t},      '2003'      => '4-digit year';
    is $time{'yy',$t},        '03'        => '2-digit year';
    is $time{'yyyymmdd',$t},  '20030605'  => 'month: mm';
    is $time{'yyyymdd',$t},   '2003605'   => 'month: m';
    is $time{'yyyy?mdd',$t},  '2003 605'  => 'month: ?m';
    is $time{'Month',$t},     'June'      => 'month name';
    is $time{'MONTH',$t},     'JUNE'      => 'uc month name';
    is $time{'month',$t},     'june'      => 'lc month name';
    is $time{'Mon',$t},       'Jun'       => 'abbr month name';
    is $time{'MON',$t},       'JUN'       => 'uc abbr month name';
    is $time{'mon',$t},       'jun'       => 'lc abbr month name';
    is $time{'dd',$t},        '05'        => '2-digit day';
    is $time{'d',$t},         '5'         => '1-digit day';
    is $time{'?d',$t},        ' 5'        => 'spaced day';
    is $time{'Weekday',$t},   'Thursday'  => 'weekday';
    is $time{'WEEKDAY',$t},   'THURSDAY'  => 'uc weekday';
    is $time{'weekday',$t},   'thursday'  => 'lc weekday';
    is $time{'Day',$t},       'Thu'       => 'weekday abbr';
    is $time{'DAY',$t},       'THU'       => 'uc weekday abbr';
    is $time{'day',$t},       'thu'       => 'lc weekday abbr';
    is $time{'hh',$t},        '13'        => '2-digit 24-hour';
    is $time{'h',$t},         '13'        => '1-digit 24-hour';
    is $time{'?h',$t},        '13'        => 'spaced 24-hour';
    is $time{'HH',$t},        '01'        => '2-digit 12-hour';
    is $time{'H',$t},         '1'         => '1-digit 12-hour';
    is $time{'?H',$t},        ' 1'        => 'spaced 12-hour';
    is $time{'hhmmss',$t},    '135809'    => 'm minute: 1';
    is $time{'hh?mss',$t},    '135809'    => 'm minute: 2';
    is $time{'hhmss',$t},     '135809'    => 'm minute: 3';
    is $time{'ss',$t},        '09'        => '2-digit second';
    is $time{'s',$t},         '9'         => '1-digit second';
    is $time{'?s',$t},        ' 9'        => 'spaced second';
    is $time{'mmm',$t},       '988'       => 'millisecond';
    is $time{'uuuuuu',$t},    '987654'    => 'microsecond';
    is $time{'am',$t},        'pm'        => 'am';
    is $time{'AM',$t},        'PM'        => 'AM';
    is $time{'pm',$t},        'pm'        => 'pm';
    is $time{'PM',$t},        'PM'        => 'PM';
    is $time{'a.m.',$t},      'p.m.'      => 'a.m.';
    is $time{'A.M.',$t},      'P.M.'      => 'A.M.';
    is $time{'p.m.',$t},      'p.m.'      => 'p.m.';
    is $time{'P.M.',$t},      'P.M.'      => 'P.M.';


    # Make sure 'm' guessing works reasonably well (17)
    is $time{'yyyymm',$t},    '200306'    => 'm test: year';
    is $time{'yymm',$t},      '0306'      => 'm test: year2';
    is $time{'mmdd',$t},      '0605'      => 'm test: day';
    is $time{'yyyy/m',$t},    '2003/6'    => 'm test: year/';
    is $time{'yy/m',$t},      '03/6'      => 'm test: year2/';
    is $time{'m/d',$t},       '6/5'       => 'm test: /day';
    is $time{'m/dd',$t},      '6/05'      => 'm test: /Day';
    is $time{'?d/mm',$t},     ' 5/06'     => 'm test: d/m';
    is $time{'?m/yyyy',$t},   ' 6/2003'   => 'm test: m/y';
    is $time{'m/yy',$t},      '6/03'      => 'm test: m/y2';

    is $time{'hhmm',$t},      '1358'      => 'm test: hour';
    is $time{'mmss',$t},      '5809'      => 'm test: sec';
    is $time{'hh:mm',$t},     '13:58'     => 'm test: hour:';
    is $time{'?m:ss',$t},     '58:09'     => 'm test: :sec';
    is $time{'H:mm',$t},      '1:58'      => 'm test: Hour:';
    is $time{'HH:mm',$t},     '01:58'     => 'm test: hour12:';
    is $time{'?H:m',$t},      ' 1:58'     => 'm test: Hour12:';

    # cases 'm' guessing can't handle (3)
    is $time{'mm',$t},        'mm'        => '2-digit month/minute';
    is $time{'m',$t},         'm'         => '1-digit month/minute';
    is $time{'?m',$t},        '?m'        => 'spaced month/minute';

    # unambiguous month/minute (6)
    is $time{'2mon',$t},      '06'        => '2-digit u-month';
    is $time{'1mon',$t},      '6'         => '1-digit u-month';
    is $time{'?mon',$t},      ' 6'        => 'spaced u-month';
    is $time{'2min',$t},      '58'        => '2-digit u-minute';
    is $time{'1min',$t},      '58'        => '1-digit u-minute';
    is $time{'?min',$t},      '58'        => 'spaced u-minute';

    # Current time value (1)
    is $time{'Day Mon ?d hh:mm:ss yyyy'}, scalar(localtime)  => 'current time';
}
