#!/perl -I..

# Test locale changing

use strict;
use Test::More tests => 5;

BEGIN { use_ok 'Time::Format', '%time' }

my $posix_bad = 0;
BEGIN { eval 'use POSIX ()'; $posix_bad=1 if $@; delete $INC{'POSIX.pm'}; }
my $tl_notok;
BEGIN { eval 'use Time::Local'; $tl_notok = $@? 1 : 0 }

SKIP:
{
    skip 4, 'POSIX not available'        if $posix_bad;
    skip 4, 'Time::Local not available'  if $tl_notok;

    my $t = timelocal 9, 58, 13, 5, 5, 103;    # June 5, 2003 at 1:58:09 pm

    POSIX::setlocale(POSIX::LC_TIME(), 'en_US');

    is $time{'Mon',$t},     'Jun'         => 'English month';
    is $time{'Day',$t},     'Thu'         => 'English day';

    POSIX::setlocale(POSIX::LC_TIME(), 'fr_FR');

    is $time{'month',$t},   'juin'      => 'Mois Francais';
    is $time{'weekday',$t}, 'jeudi'     => 'Jour de semaine Francais';
}