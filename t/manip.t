#!/perl -I..

use strict;
use Test::More tests => 6;

BEGIN { use_ok 'Time::Format', qw(%manip) }
my $manip_bad = 0;
BEGIN { eval 'use Date::Manip'; $manip_bad = 1 if $@; delete $INC{'Date/Manip.pm'}; }

my $t = 'first thursday in june 2003';

SKIP:
{
    skip 5, 'Date::Manip is not available' if $manip_bad;
    is $manip{'%Y',$t},      '2003'      => 'year';
    is $manip{'%d',$t},      '05'        => 'day of month';
    is $manip{'%D',$t},      '06/05/03'  => '%D';
    is $manip{'%e',$t},      ' 5'        => 'spaced day';
    is $manip{'%H',$t},      '00'        => 'hour';
}
