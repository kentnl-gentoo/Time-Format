#!/perl -I..

use strict;
use Test::More tests => 6;

BEGIN { use_ok 'Time::Format', qw(%strftime) }
my $posix_bad = 0;
BEGIN { eval 'use POSIX'; $posix_bad = 1 if $@; delete $INC{'POSIX.pm'}; }

my $t = '1054835889.987654321';    # June 5, 2003 at 1:58:09 pm

SKIP:
{
    skip 5, 'POSIX is not available' if $posix_bad;
    is $strftime{'%C',$t},      '20'        => 'century';
    is $strftime{'%d',$t},      '05'        => 'day of month';
    is $strftime{'%D',$t},      '06/05/03'  => '%D';
    is $strftime{'%e',$t},      ' 5'        => 'spaced day';
    is $strftime{'%H',$t},      '13'        => 'hour';
}
