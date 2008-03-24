use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Time::Format',
    'VERSION_FROM'	=> 'Format.pm', # finds $VERSION
    'PREREQ_PM'		=> {'Test::Simple' => '0.40'},
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Format.pm', # retrieve abstract from module
       AUTHOR     => 'Eric Roode <roode@cpan.org>') : ()),
    (MM->can('signature_target')? (SIGN => 1) : ()),
);
