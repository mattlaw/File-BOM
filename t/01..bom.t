#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use File::Spec;
use Encode;
use Fcntl qw( :seek );

my %file2path;
my %file2enc = (
      'utf-16le.txt' => 'UTF-16LE',
      'utf-16be.txt' => 'UTF-16BE',
      'utf-8.txt'    => 'UTF-8'
    );
my @files = keys %file2enc;

$file2path{$_} = File::Spec->catfile(qw(t data), $_) for @files;

plan tests => 1 + ( @files * 9);

use_ok("File::BOM", ':all');

for my $file (@files) {
  ok(*FH = open_bom($file2path{$file}), "$file: open_bom returned filehandle");

  my $line = <FH>;
  chomp $line;

  is($line, 'some text', "$file: test content returned OK");

  close FH;

  open FH, '<:raw', $file2path{$file};
  my $first_line = <FH>;
  $first_line =~ s/\r?\n?$//;
  # chomp $first_line;

  seek(FH, 0, SEEK_SET);

  is(get_encoding_from_filehandle(*FH), $file2enc{$file}, "$file: get_encoding_from_filehandle returned correct encoding");

  my($enc, $offset) = get_encoding_from_bom($first_line);
  is($enc, $file2enc{$file}, "$file: get_encoding_from_bom also worked");

  is(decode($enc, substr($first_line, $offset)), 'some text', "$file: .. and offset worked with substr()");

  is(decode_from_bom($first_line), 'some text', "$file: decode_from_bom()");

  seek(FH, 0, SEEK_SET);

  ($enc, my $spill) = get_encoding_from_stream(*FH);

  $line = <FH>; chomp $line;

  is($enc, $file2enc{$file}, "$file: get_encoding_from_stream()");
  is($spill, '',	     "$file: no spillage");
  is(decode($enc, $line), 'some text', "$file: read OK after get_encoding_from_stream");

  close FH;
}

__END__

vim: ft=perl
