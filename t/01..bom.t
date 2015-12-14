#!/usr/bin/perl

use strict;
use warnings;

use lib qw( t/lib );

use Test::More;
use Test::Framework;

use Encode;
use Fcntl qw( :seek );

our @encodings;
BEGIN {
  # encodings to use in unseekable test
  @encodings = qw( UTF-8 UTF-16LE UTF-16BE UTF-32LE UTF-32BE );

  plan tests => 11 + (@test_files * 12) + (@encodings * 2);

  use_ok("File::BOM", ':all');
}


for my $file (@test_files) {
  ok(*FH = open_bom($file2path{$file}), "$file: open_bom returned filehandle");
  my $expect = $filecontent{$file};

  my $line = <FH>;
  chomp $line;

  is($line, $expect, "$file: test content returned OK");

  close FH;

  open FH, '<:bytes', $file2path{$file};
  my $first_line = <FH>;
  chomp $first_line;

  seek(FH, 0, SEEK_SET);

  is(get_encoding_from_filehandle(*FH), $file2enc{$file}, "$file: get_encoding_from_filehandle returned correct encoding");

  my($enc, $offset) = get_encoding_from_bom($first_line);
  is($enc, $file2enc{$file}, "$file: get_encoding_from_bom also worked");

  {
    my $decoded = $enc ? decode($enc, substr($first_line, $offset)) 
		       : $first_line;

    is($decoded, $expect, "$file: .. and offset worked with substr()");
  }

  #
  # decode_from_bom()
  #
  is(decode_from_bom($first_line, 'UTF-8', Encode::FB_CROAK), $expect, "$file: decode_from_bom() scalar context");
  {
    # with default
    my $default = 'UTF-8';
    my $expect_enc = $file2enc{$file} || $default;

    my($decoded, $got_enc) = decode_from_bom($first_line, $default, Encode::FB_CROAK);

    is($decoded, $expect,      "$file: decode_from_bom() list context");
    is($got_enc, $expect_enc, "$file: decode_from_bom() list context encoding");
  }
  {
    # without default
    my $expect_enc = $file2enc{$file};
    my($decoded, $got_enc) = decode_from_bom($first_line, undef, Encode::FB_CROAK);

    is($decoded, $expect,      "$file: decode_from_bom() list context, no default");
    is($got_enc, $expect_enc, "$file: decode_from_bom() list context encoding, no default");
  }

  seek(FH, 0, SEEK_SET);

  ($enc, my $spill) = get_encoding_from_stream(*FH);

  $line = <FH>; chomp $line;

  is($enc, $file2enc{$file}, "$file: get_encoding_from_stream()");

  $line = $spill . $line;

  $line = decode($enc, $line) if $enc;

  is($line, $expect, "$file: read OK after get_encoding_from_stream");

  close FH;
}

# Test unseekable
SKIP: {
  skip "mkfifo not supported on this platform", (2 * @encodings)
      unless $fifo_supported;

  for my $encoding (@encodings) {
    my $expected = my $test = "Testing \x{2170}, \x{2171}, \x{2172}\n";
    my $bytes = join('', $enc2bom{$encoding}, encode($encoding, $test, Encode::FB_CROAK));

    my($pid, $fifo) = write_fifo($bytes);

    my($fh, $enc, $spill) = open_bom($fifo, undef, 1);
    my $result = $spill . <$fh>;

    close $fh;
    waitpid($pid, 0);
    unlink $fifo;

    is($enc, $encoding,	 "Read BOM correctly in unseekable $encoding file");
    is($result, $expected, "Read $encoding data from unseekable source");
  }
}

# Test broken BOM
{
  my $broken_content = "\xff\xffThis file has a broken BOM";
  my $broken_file = 't/data/broken_bom.txt';
  my($fh, $enc, $spill) = open_bom($broken_file);
  is($enc, '', "open_bom on file with broken BOM has no encoding");
  {
    my $line = <$fh>;
    chomp $line;
    is($line, $broken_content, "handle with broken BOM returns as expected");
  }

SKIP: {
    skip "mkfifo not supported on this platform", 3
	unless $fifo_supported;
    my($pid, $fifo) = write_fifo($broken_content);
    if (open my $fh, '<', $fifo) {
      my($enc, $spill) = get_encoding_from_filehandle($fh);
      is($enc, '', "get_encoding_from_filehandle() on unseekable file broken bom");
      ok($spill, ".. spillage was produced");
      is($spill . <$fh>, $broken_content, "spillage + content as expected");
      close $fh;
    }
    else {
      fail(3);
    }

    waitpid($pid, 0);
    unlink $fifo;
  }
}

# Test internals

is(File::BOM::_get_char_length('UTF-8', 0xe5), 3, '_get_char_length() on UTF-8 start byte (3)');
is(File::BOM::_get_char_length('UTF-8', 0xd5), 2, '_get_char_length() on UTF-8 start byte (2)');
is(File::BOM::_get_char_length('UTF-8', 0x7f), 1, '_get_char_langth() on UTF-8 single byte char');
is(File::BOM::_get_char_length('', ''), undef,    '_get_char_length() on undef');
is(File::BOM::_get_char_length('UTF-32BE', ''), 4,  '_get_char_length() on UTF-32');

__END__

vim: ft=perl
