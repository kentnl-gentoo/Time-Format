use strict;
use warnings;

eval {require Module::Build};
if ($@)
{
    warn "Module::Build is required for Build.PL\n";
    exit 0;
}


my $builder = Module::Build->new(
    module_name         => 'Time::Format',
    license             => 'unrestricted',
    dist_author         => 'Eric J. Roode <roode@cpan.org>',
    dist_version_from   => 'lib/Time/Format.pm',
    build_requires => {
                       'Test::Simple' => '0.40',
                      },
    requires =>
    {
        'Time::Local'    => '1.07',
    },
    sign => 1,
    add_to_cleanup      => [ 'Time-Format-*' ],
);

$builder->create_build_script();
