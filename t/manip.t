#!/perl -I..

use strict;
use Test::More tests => 6;

BEGIN { use_ok 'Time::Format', qw(%manip) }
my $manip_bad;
BEGIN {
    eval 'use Date::Manip ()';
    $manip_bad = $@? 1 : 0;
    unless ($manip_bad)
    {
        # If Date::Manip can't determine the time zone, it'll bomb out of the tests.
        eval 'Date::Manip::Date_TimeZone()';
        $manip_bad = $@? 1 : 0;
    }
    delete $INC{'Date/Manip.pm'};
    %Date::Manip:: = ();
}

my $t = 'first thursday in june 2003';

SKIP:
{
    skip 'Date::Manip is not available', 5 if $manip_bad;
    is $manip{'%Y',$t},      '2003'      => 'year';
    is $manip{'%d',$t},      '05'        => 'day of month';
    is $manip{'%D',$t},      '06/05/03'  => '%D';
    is $manip{'%e',$t},      ' 5'        => 'spaced day';
    is $manip{'%H',$t},      '00'        => 'hour';
}
