#!/usr/bin/perl

use strict;
use warnings;

use lib qw( t/lib );

use Test::More;
use Test::Framework;

use File::BOM qw( %enc2bom );

# Expected data for "moose" tests (below)
our %should_be = (
 'UTF-8'    => "\x{ef}\x{bb}\x{bf}m\x{c3}\x{b8}\x{c3}\x{b8}se\x{e2}\x{80}\x{a6}",
 'UTF-16BE' => "\x{fe}\x{ff}\x{0}m\x{0}\x{f8}\x{0}\x{f8}\x{0}s\x{0}e &",
 'UTF-16LE' => "\x{ff}\x{fe}m\x{0}\x{f8}\x{0}\x{f8}\x{0}s\x{0}e\x{0}& ",
 'UTF-32BE' => "\x{0}\x{0}\x{fe}\x{ff}\x{0}\x{0}\x{0}m\x{0}\x{0}\x{0}\x{f8}\x{0}\x{0}\x{0}\x{f8}\x{0}\x{0}\x{0}s\x{0}\x{0}\x{0}e\x{0}\x{0} &",
 'UTF-32LE' => "\x{ff}\x{fe}\x{0}\x{0}m\x{0}\x{0}\x{0}\x{f8}\x{0}\x{0}\x{0}\x{f8}\x{0}\x{0}\x{0}s\x{0}\x{0}\x{0}e\x{0}\x{0}\x{0}& \x{0}\x{0}",
);

plan tests => 2 * @test_files + 5 * keys(%enc2bom) + keys(%should_be) + 1;

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
    open(BOM_OUT, ">:encoding($enc):via(File::BOM):utf8", $file),
    "Opened file for writing $enc via layer"
  ) or diag "$file: $!";

  my $test = print(BOM_OUT "some text\n");
  ok($test, 'print() through layer')
    or diag("print() returned ". (defined($test)?$test:'undef'));

  $test = print(BOM_OUT "more text\n");
  ok($test, 'print() through layer again')
    or diag("print() returned ". (defined($test)?$test:'undef'));

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

# Mark Fowler's "moose" test:
{
  # This is 'moose...' (with slashes in the 'o's them, and the '...'
  # as one char).  As the '...' can't be represented in latin-1 then
  # perl will store the thing internally as a utf8 string with the
  # utf8 flag enabled.
  my $moose = "m\x{f8}\x{f8}se\x{2026}";

  for my $enc (keys %should_be) {
    my $file = "moose-$enc.txt";
    open(FH, ">:encoding($enc):via(File::BOM):utf8", $file) or die "Can't write to $file: $!\n";
    print FH $moose;
    close FH;

    open(FH, '<', $file) or die "Can't read $file: $!\n";
    local $/ = undef;
    my $value = <FH>;
    close FH;

    is(
      reasciify($value),
      reasciify($should_be{$enc}),
      "check file for $enc"
    );

    unlink $file or diag "Can't remove '$file': $!";
  }
}

# Spurkis' seek test
{
  my $file = 't/data/utf8_data.csv';
  open(my $fh, '<:via(File::BOM)', $file) or die "Can't read $file\n";

  my $orig = join("\n", <$fh>);

  seek($fh, 0, 0) or die "Couldn't seek: $!";

  my $new = join("\n", <$fh>);

  is($new, $orig, "seek() works");
}

sub reasciify {
  my $string = shift;
  $string = join "", map {
   my $ord = ord($_);
    ($ord > 127 || ($ord < 32 && $ord != 10))
     ? sprintf '\x{%x}', $ord
     : $_
  } split //, $string
}

__END__

vim: ft=perl
