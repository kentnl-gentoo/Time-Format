
# Test cases for bug reported by Will "Coke" Coleda

use strict;
use Test::More;
use DateTime::Format::ISO8601;
use Time::Format;

# Input string, output string
my @tuples = (
              ['2009-04-15T01:58:17.010760Z', 'April 15, 2009 @ 1:58'],
              ['2009-04-15T13:58:17.010760Z', 'April 15, 2009 @ 1:58'],
             );

# The above array contains all of the tests this unit will run.
plan tests => 2 * scalar(@tuples);

my $time_format = 'Month d, yyyy @ H:mm';

my $index = 0;
foreach my $pair (@tuples)
{
    my ($input, $expected) = @$pair;
    my $dt = DateTime::Format::ISO8601->parse_datetime($input);

    is $time{$time_format,       $dt}, $expected, "Test case $index (hash)";
    is time_format($time_format, $dt), $expected, "Test case $index (func)";
    ++$index;
}
