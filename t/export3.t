#!/perl -I..

use Test::More tests => 7;

BEGIN { use_ok 'Time::Format', qw(%manip time_format time_manip) }

# hashes exported properly?
is ref tied %time,     ''            => '%time exported by :all';
is ref tied %strftime, ''            => '%strftime exported by :all';
is ref tied %manip,    Time::Format  => '%manip exported by :all';

# functions exported properly?
ok  defined &time_format              => 'time_format exported by :all';
ok !defined &time_strftime            => 'time_strftime exported by :all';
ok  defined &time_manip               => 'time_manip exported by :all';
