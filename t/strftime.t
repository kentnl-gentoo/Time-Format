#!/perl -I..

use strict;
use Test::More tests => 6;

BEGIN { use_ok 'Time::Format', qw(%strftime) }
my $posix_bad;
BEGIN {
    eval 'use POSIX ()';
    $posix_bad = $@? 1 : 0;
    delete $INC{'POSIX.pm'};
    %POSIX:: = ();
}
my $tl_bad;
BEGIN { eval 'use Time::Local'; $tl_bad = $@? 1 : 0 }

SKIP:
{
    skip 'POSIX is not available', 5       if $posix_bad;
    skip 'Time::Local is not available', 5 if $tl_bad;

    my $t = timelocal(9, 58, 13, 5, 5, 103);    # June 5, 2003 at 1:58:09 pm
    $t .= '.987654321';

    # Be sure to use ONLY ansi standard strftime codes here,
    # otherwise the tests will fail on somebody's system somewhere.

    is $strftime{'%d',$t},      '05'        => 'day of month';
    is $strftime{'%m',$t},      '06'        => 'Month number';
    is $strftime{'%M',$t},      '58'        => 'minute';
    is $strftime{'%H',$t},      '13'        => 'hour';
    is $strftime{'%Y',$t},      '2003'      => 'year';
}
