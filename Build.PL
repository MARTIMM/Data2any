#!/usr/bin/perl
#
use 5.014003;
require Modern::Perl;
require Module::Build;
#require Module::Build::ConfigData;

my $build = Module::Build->new
( module_name           => 'Data2any'
, license               => 'perl'
, create_licence        => 1
, dist_author           => 'Marcel Timmerman <mt1957@gmail.com>'
, release_status        => 'stable'
, script_files          => 'script'

, tap_harness_args      => { timer => 1
                           , failures => 1
                           , show_count => 1
                           }

, requires              => { 'perl'                     => 'v5.14.3'
                           , 'Modern::Perl'             => '1.20121103'
                           , 'DateTime'                 => 0
                           , 'Parse::RecDescent'        => '1.967.9'
                           }

, configure_requires    => { 'Modern::Perl'             => '1.20121103'
                           , 'Module::Build'            => '0.4005'
                           , 'Software::License'        => 1
                           }
);


$build->create_build_script();
