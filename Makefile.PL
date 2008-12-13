use strict;
use warnings;
use inc::Module::Install;

name 'FormValidator-LazyWay';
author 'Tomohiro Teranishi <tomohiro.teranishi@gmail.com>';
requires 'YAML::Syck'               => 0;
requires 'Test::Base'               => 0;
requires 'Test::Exception'          => 0;
requires 'Perl6::Junction'          => 0;
requires 'UNIVERSAL::require'       => 0;
requires 'Email::Valid'             => 0;
requires 'Email::Valid::Loose'      => 0;
requires 'Moose'                    => 0;
requires 'Data::Validate::URI'      => 0;
all_from 'lib/FormValidator/LazyWay.pm';

auto_install;
WriteAll;
