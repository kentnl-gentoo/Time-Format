#!/perl -I..

use strict;
use Test::More tests => 21;

# time-as-string tests

BEGIN { $Time::Format::NOXS = 1 }
BEGIN { use_ok 'Time::Format', qw(time_format %time) }

# Get day/month names in current locale
my ($Thursday, $Thu, $June, $Jun);
eval
{
    require I18N::Langinfo;
    I18N::Langinfo->import qw(langinfo DAY_3 MON_12 DAY_5 ABDAY_5 MON_6 ABMON_6);
    ($Thursday, $Thu, $June, $Jun) = map ucfirst lc langinfo($_), (DAY_5(), ABDAY_5(), MON_6(), ABMON_6());
};
if ($@)
{
    ($Thursday, $Thu, $June, $Jun) = qw(Thursday Thu June Jun);
}

# June 5, 2003 at 1:58:09 pm
my $d  = '2003-06-05';
my $t  =   '13:58:09';
my $d_t = "$d $t";
my $dt  = "$d$t";
my $dtx;
($dtx = $dt) =~ tr/-://d;   # no separators at all
my $out;
my $err;

# time_format tests (10 * 2)
is time_format('yyyymmdd', $d),  '20030605'    => 'ymd d only';
is time_format('yyyymmdd', $t),  '19691231'    => 'ymd t only';
is time_format('yyyymmdd', $d_t),'20030605'    => 'ymd d&t';
is time_format('yyyymmdd', $dt), '20030605'    => 'ymd dt';
is time_format('yyyymmdd', $dtx),'20030605'    => 'ymd dt-nosep';

is time_format('hhmmss',   $d),  '000000'      => 'hms d only';
is time_format('hhmmss',   $t),  '135809'      => 'hms t only';
is time_format('hhmmss',   $d_t),'135809'      => 'hms d&t';
is time_format('hhmmss',   $dt), '135809'      => 'hms dt';
is time_format('hhmmss',   $dtx),'135809'      => 'hms dt-nosep';

is $time{'yyyymmdd', $d},  '20030605'    => 'ymd d only';
is $time{'yyyymmdd', $t},  '19691231'    => 'ymd t only';
is $time{'yyyymmdd', $d_t},'20030605'    => 'ymd d&t';
is $time{'yyyymmdd', $dt}, '20030605'    => 'ymd dt';
is $time{'yyyymmdd', $dtx},'20030605'    => 'ymd dt-nosep';

is $time{'hhmmss',   $d},  '000000'      => 'hms d only';
is $time{'hhmmss',   $t},  '135809'      => 'hms t only';
is $time{'hhmmss',   $d_t},'135809'      => 'hms d&t';
is $time{'hhmmss',   $dt}, '135809'      => 'hms dt';
is $time{'hhmmss',   $dtx},'135809'      => 'hms dt-nosep';
