#!/perl -I..

# Test examples in the docs, so we know we're not misleading anyone.

use strict;
use Test::More tests => 23;

BEGIN { use_ok 'Time::Format', qw(:all) }

my $t = '1054835889.987654321';    # June 5, 2003 at 1:58:09 pm

# Were all variables imported? (3)
is ref tied %time,     'Time::Format'   =>  '%time imported';
is ref tied %strftime, 'Time::Format'   =>  '%strftime imported';
is ref tied %manip,    'Time::Format'   =>  '%manip imported';

# Synopsis tests (7)
is "Today is $time{'yyyy/mm/dd',$t}", 'Today is 2003/06/05'   => 'Today';
is "Yesterday was $time{'yyyy/mm/dd', $t-24*60*60}", 'Yesterday was 2003/06/04'  => 'Yesterday';
is "The time is $time{'hh:mm:ss',$t}", 'The time is 13:58:09'    => 'time';
is "Another time is $time{'H:mm am', $t}", 'Another time is 1:58 pm'             => 'Another time';
is "Timestamp: $time{'yyyymmdd.hhmmss.mmm',$t}", 'Timestamp: 20030605.135809.988'   => 'Timestamp';

is "POSIXish: $strftime{'%A, %B %d, %Y', 0,0,0,12,11,95,2}", 'POSIXish: Tuesday, December 12, 1995'   => 'POSIX 1';
is "POSIXish: $strftime{'%A, %B %d, %Y', 1054866251}",       'POSIXish: Thursday, June 05, 2003'   => 'POSIX 1';

# Examples section (11)
is $time{'Weekday Month d, yyyy',$t}, 'Thursday June 5, 2003'   => 'Example 1';
is $time{'Day Mon d, yyyy',$t},       'Thu Jun 5, 2003'         => 'Example 2';
is $time{'dd/mm/yyyy',$t},            '05/06/2003'              => 'Example 3';
is $time{'yymmdd',$t},                '030605'                  => 'Example 4';

is $time{'H:mm:ss am',$t},            '1:58:09 pm'              => 'Example 5';
is $time{'hh:mm:ss.uuuuuu',$t},       '13:58:09.987654'         => 'Example 6';

is $time{'yyyy/2mon/dd hh:2min:ss.mmm',$t},   '2003/06/05 13:58:09.988'         => 'Example 7';
is $time{'yyyy/mm/dd hh:mm:ss.mmm',$t},       '2003/06/05 13:58:09.988'         => 'Example 8';

is $strftime{'%A %B %e, %Y',$t},        'Thursday June  5, 2003'         => 'Example 9';

is $manip{'%m/%d/%Y',"epoch $t"},               '06/05/2003'         => 'Example 9';
is $manip{'%m/%d/%Y','first monday in November 2000'},  '11/06/2000'         => 'Example 10';

# manip tests (1)
is qq[$time{'yyyymmdd',$manip{'%s',"epoch $t"}}], '20030605',     'Example 11';