use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Pastedance',
    AUTHOR              => q{Danijel Tašov},
    VERSION_FROM        => 'lib/Pastedance.pm',
    ABSTRACT            => 'Pastebin write with Dancer',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'     => 0,
        'YAML'           => 0,
        'Dancer'         => 1.1902,
        'Inline::Python' => 0,
        'Data::Uniqid'   => 0,
        'DateTime'       => 0,
        'Dancer::Plugin::Mongo' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Pastedance-*' },
);
