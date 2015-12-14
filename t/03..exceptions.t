#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';
use Test::Framework;

use File::BOM qw(
    open_bom
    decode_from_bom
    get_encoding_from_filehandle
  );

use File::Temp qw( tmpnam );

use Test::Exception ( tests => 7 );
use Test::More;

my $absent = tmpnam();
throws_ok { open_bom($absent) }
	  qr/^Couldn't read/,
	  "open_bom on non-existant file fails";

throws_ok { decode_from_bom(undef) }
	  qr/^No string/,
	  "decode_from_bom with no string fails";

throws_ok { get_encoding_from_filehandle(\*STDIN) }
	  qr/^Unseekable handle/,
	  "get_encoding_from_filehandle on unseekable handle fails";

{
  # The following tests are known to produce warnings
  local $SIG{__WARN__} = sub {};

  throws_ok { File::BOM::_get_encoding_seekable(\*STDOUT) }
	  qr/^Couldn't read from handle/,
	  "_get_encoding_seekable on unreadable handle fails";

  throws_ok { File::BOM::_get_encoding_unseekable(\*STDOUT) }
	    qr/^Couldn't read byte/,
	    "_get_encoding_unseekable() on unreadable handle fails";

SKIP:
  {
    skip "mkfifo not supported on this platform", 1
	unless $fifo_supported;

    my($pid, $fifo) = write_fifo('');
    if (open(STREAM, '<:bytes', $fifo)) {
      throws_ok { File::BOM::_get_encoding_seekable(\*STREAM) }
		qr/^Couldn't reset read position/,
		"_get_encoding_seekable on unseekable handle fails";
    }
    else {
      fail("Couldn't open $fifo for reading: $!");
    }
    close STREAM;
    waitpid($pid, 0); unlink $fifo;
  }

  throws_ok { open_bom('t/data/no_bom.txt', 'invalid') }
	    qr/^Couldn't set binmode of handle opened on/,
	    "open_bom with invalid default encoding fails";
}

__END__

vim:ft=perl
