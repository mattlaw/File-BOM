package Test::Framework;

#
# Common resources for tests
#

use File::Spec;
use File::Temp qw( tmpnam );
use POSIX qw( mkfifo );

use base qw( Exporter );

our(%file2path, %file2enc, %filecontent, @test_files, $fifo_supported);

@EXPORT = qw( %file2path %file2enc %filecontent @test_files write_fifo $fifo_supported );

%file2enc = (
      'utf-32le.txt' => 'UTF-32LE',
      'utf-32be.txt' => 'UTF-32BE',
      'utf-16le.txt' => 'UTF-16LE',
      'utf-16be.txt' => 'UTF-16BE',
      'utf-8.txt'    => 'UTF-8',
      'no_bom.txt'   => '',
    );
%filecontent = (
      'utf-32le.txt' => 'some text',
      'utf-32be.txt' => 'some text',
      'utf-16le.txt' => 'some text',
      'utf-16be.txt' => 'some text',
      'utf-8.txt'    => 'some text',
      'no_bom.txt'   => 'some text',
    );
@test_files = keys %file2enc;

$file2path{$_} = File::Spec->catfile(qw(t data), $_) for @test_files;

eval {
  my $tmp = tmpnam;

  if (mkfifo($tmp, 0700)) { unlink $tmp }
  else			  { die $! }
};

if ($@ =~ /^POSIX::mkfifo not implemented on this architecture/) {
  $fifo_supported = 0;
}
else {
  $fifo_supported = 1;
}

sub write_fifo ($) {
  my $bytes = shift;

  my $fifo = tmpnam();

  mkfifo($fifo, 0700) or die "Couldn't create fifo at '$fifo': $!";

  if (my $pid = fork()) {
    return ($pid, $fifo);
  }
  else {
    if (open my $writer, '>', $fifo) {
      print $writer $bytes;
      close $writer;
    }
    else {
      unlink $fifo or die "Couldn't write or unlink fifo at '$fifo': $!";
      die "Couldn't write to fifo at '$fifo': $!";
    }

    exit 0;
  }
}

1;
