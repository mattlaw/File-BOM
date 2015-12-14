#!/usr/bin/perl

use strict;
use warnings;

use lib qw( t/lib );

use Test::More;

use Test::Framework;

use Carp qw( croak );

use File::BOM qw( %enc2bom );

plan tests => 2 * @test_files + 3 * keys %enc2bom;

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
  ok(
    open(BOM_OUT, ">:encoding($enc):via(File::BOM)", 'test_file.txt'),
    "Opened file for writing $enc via layer"
  ) or diag "opening test_file.txt in $enc: $!";
  ok(print(BOM_OUT "some text\n"), 'printed through layer');
  close BOM_OUT;

  # now re-read
  open(BOM_IN, '<:via(File::BOM)', 'test_file.txt');
  my $line = <BOM_IN>; chomp $line;
  is($line, 'some text', 'BOM was written successfully via layer');
  close BOM_IN;
}

unlink 'test_file.txt' or diag "Couldn't remove test_file.txt: $!";

__END__

vim: ft=perl
