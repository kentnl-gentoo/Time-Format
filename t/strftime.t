#!/perl -I..

use strict;
use Test::More tests => 5;

BEGIN { use_ok 'Time::Format', qw(%strftime) }
my $posix_bad;
BEGIN { eval 'use POSIX'; $posix_bad = $@? 1 : 0; delete $INC{'POSIX.pm'}; }
my $tl_bad;
BEGIN { eval 'use Time::Local'; $tl_bad = $@? 1 : 0 }

SKIP:
{
    skip 'POSIX is not available', 4       if $posix_bad;
    skip 'Time::Local is not available', 4 if $tl_bad;

    my $t = timelocal(9, 58, 13, 5, 5, 103);    # June 5, 2003 at 1:58:09 pm
    $t .= '.987654321';

    is $strftime{'%d',$t},      '05'        => 'day of month';
    is $strftime{'%D',$t},      '06/05/03'  => '%D';
    is $strftime{'%e',$t},      ' 5'        => 'spaced day';
    is $strftime{'%H',$t},      '13'        => 'hour';
}
