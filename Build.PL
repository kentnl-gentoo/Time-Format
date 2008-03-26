use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Time::Format',
    license             => 'unrestricted',
    dist_author         => 'Eric J. Roode <roode@cpan.org>',
    dist_version_from   => 'lib/Time/Format.pm',
    build_requires => {
                       'Test::More'      => '0.10',
                       'Time::Local'     => '1.07',
                      },
    sign => 1,
    add_to_cleanup      => [ 'Time-Format-*' ],
);

$builder->create_build_script();
