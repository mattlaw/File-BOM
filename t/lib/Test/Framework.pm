package Test::Framework;

#
# Common resources for tests
#

use File::Spec;

use base qw( Exporter );

our(%file2path, %file2enc, @test_files);

@EXPORT = qw( %file2path %file2enc @test_files );

%file2enc = (
      'utf-32le.txt' => 'UTF-32LE',
      'utf-32be.txt' => 'UTF-32BE',
      'utf-16le.txt' => 'UTF-16LE',
      'utf-16be.txt' => 'UTF-16BE',
      'utf-8.txt'    => 'UTF-8',
      'no_bom.txt'   => ''
    );
@test_files = keys %file2enc;

$file2path{$_} = File::Spec->catfile(qw(t data), $_) for @test_files;

1
