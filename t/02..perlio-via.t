#!/usr/bin/perl

use strict;
use warnings;

use lib qw( t/lib );

use Test::More;
use Test::Framework;

use File::BOM qw( %enc2bom );

plan tests => 2 * @test_files + 4 * keys %enc2bom;

for my $test_file (@test_files) {
  ok(
    open(FH, '<:via(File::BOM)', $file2path{$test_file}),
    "$test_file: opened through layer"
  ) or diag "$test_file: $!";

  my $line = <FH>; chomp $line;
  is($line, 'some text', "$test_file: read OK through layer");
  close FH;
}

for my $enc (sort keys %enc2bom) {
  my $file = "test_file-$enc.txt";
  ok(
    open(BOM_OUT, ">:encoding($enc):via(File::BOM)", $file),
    "Opened file for writing $enc via layer"
  ) or diag "opening test_file.txt in $enc: $!";
  ok(print(BOM_OUT "some text\n"), 'printed through layer');
  print BOM_OUT "more text\n";
  close BOM_OUT;

  # now re-read
  my $line;
  open(BOM_IN, '<:via(File::BOM)', $file);

  $line = <BOM_IN>; chomp $line;
  is($line, 'some text', 'BOM was written successfully via layer');

  $line = <BOM_IN>; chomp $line;
  is($line, 'more text', 'BOM not written in second print call');
  close BOM_IN;

  unlink $file or diag "Couldn't remove $file: $!";
}

__END__

vim: ft=perl
