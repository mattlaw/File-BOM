#!/usr/bin/perl

=head1 NAME

Build.PL - Build script generator for File::BOM

=head1 SYNOPSIS

 perl Build.PL
 ./Build test
 ./Build install

=cut

use lib 'lib';

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new
  (
   module_name        => 'File::BOM',
   dist_version_from  => 'lib/File/BOM.pm',
   create_readme      => 1,
   create_makefile_pl => 'passthrough',
   license            => 'perl',
   requires	      => {
			   perl => '5.8.0',
			 },
   build_requires     => {
			   'Test::More'    => '0.01',
			   'Module::Build' => '0.20',
		         },
  );

$build->create_build_script;

__END__

=head1 SEE ALSO

L<Module::Build>

=head1 AUTHOR

Matt Lawrence <mattlaw@cpan.org>

=cut

