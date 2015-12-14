#!/usr/bin/perl

use strict;
use warnings;

use lib qw( t/lib );

use Test::More;
use Test::Framework;

use Encode;
use Fcntl qw( :seek );

plan tests => 1 + ( @test_files * 8);

use_ok("File::BOM", ':all');

for my $file (@test_files) {
  ok(*FH = open_bom($file2path{$file}), "$file: open_bom returned filehandle");

  my $line = <FH>;
  chomp $line;

  is($line, 'some text', "$file: test content returned OK");

  close FH;

  open FH, '<:raw', $file2path{$file};
  my $first_line = <FH>;
  # $first_line =~ s/\r?\n?$//;
  chomp $first_line;

  seek(FH, 0, SEEK_SET);

  is(get_encoding_from_filehandle(*FH), $file2enc{$file}, "$file: get_encoding_from_filehandle returned correct encoding");

  my($enc, $offset) = get_encoding_from_bom($first_line);
  is($enc, $file2enc{$file}, "$file: get_encoding_from_bom also worked");

  $first_line = decode($enc, substr($first_line, $offset)) if $enc;
  is($first_line, 'some text', "$file: .. and offset worked with substr()");

  is(decode_from_bom($first_line), 'some text', "$file: decode_from_bom()");

  seek(FH, 0, SEEK_SET);

  ($enc, my $spill) = get_encoding_from_stream(*FH);

  $line = <FH>; chomp $line;

  is($enc, $file2enc{$file}, "$file: get_encoding_from_stream()");

  # diag("enc: '$enc'\nspill: '$spill'");

  $line = $spill . $line;

  # diag("BEFORE: ". join(' ', map {sprintf("%02X", $_)} unpack("C*", $line)));
  
  $line = decode($enc, $line) if $enc;

  # diag("AFTER:  ". join(' ', map {sprintf("%02X", $_)} unpack("C*", $line)));
  
  # diag("after decode:  '$line'");

  is($line, 'some text', "$file: read OK after get_encoding_from_stream");

  close FH;
}

__END__

vim: ft=perl
