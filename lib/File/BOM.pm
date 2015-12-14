package File::BOM;

=head1 NAME

File::BOM - Utilities for reading Byte Order Marks

=head1 SYNOPSIS

  use File::BOM qw( :all )

=head2 high-level functions

  # read a file with encoding from the BOM:
  *FH = open_bom($file)
  *FH = open_bom($file, ':utf8') # the same but with a default encoding

  # get encoding too
  (*FH, $encoding) = open_bom($file, ':utf8');

  # open a potentially unseekable file:
  (*FH, $encoding, $spillage) = open_bom($file, ':utf8', 1);

  # slurp an encoded file
  my $text = eval {
    local $/ = undef;
    my $whole_file = <STDIN>;
    decode_from_bom($whole_file, 'UTF-8', 1);
  }

=head2 PerlIO::via interface

  # Read the Right Thing from a unicode file with BOM:
  open(HANDLE, '<:via(File::BOM)', $filename)

  # Writing little-endian UTF-16 file with BOM:
  open(HANDLE, '>:encoding(UTF-16LE):via(File::BOM)', $filename)


=head2 lower-level functions

  # read BOM encoding from filehandle:
  open FH, '<:bytes', $some_file;
  $encoding = get_encoding_from_filehandle(*FH)

  # get encoding and BOM length from BOM at start of string:
  ($encoding, $offset) = get_encoding_from_bom($string);

=head2 variables

  # print a BOM for a known encoding
  print FH $enc2bom{$encoding};

  # get an encoding from a known BOM
  $enc = $bom2enc{$bom}
  
=cut

use 5.008;

use strict;
use warnings;

use base qw( Exporter );

use Symbol qw( gensym );
use Fcntl  qw( :seek );
use Carp   qw( croak );

use Encode;

my @subs = qw(
      open_bom
      get_encoding_from_bom
      get_encoding_from_filehandle
      get_encoding_from_stream
      decode_from_bom
    );

my @vars = qw( %bom2enc %enc2bom );

our $VERSION = '0.06';

our @EXPORT = ();
our @EXPORT_OK = ( @subs, @vars );
our %EXPORT_TAGS = (
      all  => \@EXPORT_OK,
      subs => \@subs,
      vars => \@vars
    );

=head1 EXPORTS

Nothing by default.

=over 4

=item * open_bom()

=item * decode_from_bom()

=item * get_encoding_from_filehandle()

=item * get_encoding_from_stream()

=item * get_encoding_from_bom()

=item * %bom2enc

=item * %enc2bom

=item * :all

All of the above

=item * :subs

subroutines only

=item * :vars

just %bom2enc and %enc2bom

=back

=cut

=head1 VARIABLES

=head2 %bom2enc

Maps Byte Order marks to their encodings.

See L<http://www.unicode.org/unicode/faq/utf_bom.html#BOM> for details

The keys of this hash are strings which represent the BOMs, the values are their
encodings, in a format which is understood by L<Encode>

The encodings represented in this hash are: UTF-8, UTF-16BE, UTF-16LE,
UTF-32BE and UTF-32LE

=head2 %enc2bom

A reverse-lookup hash for bom2enc, with a few aliases used in L<Encode>, namely utf8, iso-10646-1 and UCS-2.

Note that UTF-16, UTF-32 and UCS-4 are not included in this hash. Mainly
because Encode::encode automatically puts BOMs on output. See L<Encode::Unicode>

=cut

our(%bom2enc, %enc2bom, $MAX_BOM_LENGTH);

$MAX_BOM_LENGTH = 4;
%bom2enc = map { encode($_, "\x{feff}") => $_ } qw(
      UTF-8
      UTF-16BE
      UTF-16LE
      UTF-32BE
      UTF-32LE
    );

%enc2bom = (reverse(%bom2enc), map { $_ => encode($_, "\x{feff}") } qw(
      UCS-2
      iso-10646-1
      utf8
    ));

# verify $MAX_BOM_LENGTH -- better safe than sorry 
for my $enc (keys %enc2bom) {
  use bytes;

  my $bom = $enc2bom{$enc};
  my $len = length $bom || 0;

  $MAX_BOM_LENGTH = $len if $len > $MAX_BOM_LENGTH;
}

=head1 FUNCTIONS

=head2 open_bom

  *FH = open_bom($name, $default_mode, $try_unseekable)

  (*FH, $encoding, $spill) = open_bom($name, $default_mode, $try_unseekable)

opens $name for reading, setting the mode to the appropriate encoding for the
BOM stored in the file.

If the file doesn't contain a BOM, $default_mode is used instead. Hence:

  open_bom('my_file.txt', ':utf8')

Opens my_file.txt for reading in an appropriate encoding found from the BOM in
that file, or as a UTF-8 file if none is found.

If no default mode is specified and no BOM is found, the filehandle is opened
using :bytes

croaks on errors, returns the filehandle in scalar context or the filehandle
and the encoding in list context.

The filehandle will be cued up to read after the BOM. Unseekable files (e.g.
sockets) will cause croaking, unless $try_unseekable is set in which case any
spillage is returned after the encoding (in scalar context the spillage is
lost!)

  e.g.

  # croak if my_socket is unseekable
  *FH = open_bom('my_socket')

  # keep spillage if my_socket is unseekable
  (*FH, $encoding, $spillage) = open_bom('my_socket', undef, 1);

  # discard spillage if my_socket is unseekable - not recommended
  *FH = open_bom('my_socket', undef, 1);

=cut

sub open_bom ($;$) {
  my($filename, $mode, $try) = @_;

  my $fh = gensym();
  my $spill = '';
  my $enc;

  open($fh, '<:bytes', $filename)
      or croak "Couldn't read '$filename': $!";

  if ($try) {
    ($enc, $spill) = get_encoding_from_filehandle($fh);
  }
  else {
    $enc = get_encoding_from_filehandle($fh);
  }

  if ($enc) {
    $mode = ":encoding($enc)";
  }

  if ($mode) {
    binmode($fh, $mode) or croak(
      "Can't set binmode of handle opened on '$filename' to '$mode': $!"
    );
  }

  return wantarray ? ($fh, $enc, $spill) : $fh;
}

=head2 decode_from_bom

  $unicode_string = decode_from_bom($string, $default, $check)

  ($unicode_string, $encoding) = decode_from_bom($string, $default, $check)

Reads a BOM from the beginning of $string, decodes $string (minus the BOM) and
returns it to you as a perl unicode string.

if $string doesn't have a BOM, $default is used instead.

$check, if supplied, is passed to Encode::decode

If there's no BOM and no default, the original string is returned and encoding
is ''.

See L<Encode>

=cut

sub decode_from_bom {
  my($string, $default, $check) = @_;

  croak "No string" unless defined $string;

  my($enc, $off) = get_encoding_from_bom($string);
  $enc ||= $default;

  my $out;
  if (defined $enc) { $out = decode($enc, substr($string, $off), $check); }
  else		    { $out = $string; $enc = '' }

  return wantarray ? ($out, $enc) : $out;
}

=head2 get_encoding_from_filehandle

  $encoding = get_encoding_from_filehandle(HANDLE)

  ($encoding, $spillage) = get_encoding_from_filehandle(HANDLE)

Returns the encoding found in the given filehandle.

The handle should be opened in a non-unicode way (e.g. mode '<:bytes') so that
the BOM can be read in its natural state.

After calling, the handle will be set to read at a point after the BOM (or at
the beginning of the file if no BOM was found)

If called in scalar context, unseekable handles cause a croak().

If called in list context, unseekable handles will be read byte-by-byte and any
spillage will be returned. See L<get_encoding_from_stream>

=cut

sub get_encoding_from_filehandle (*) {
  my $fh = shift;

  if (seek($fh, 0, SEEK_SET)) {
    return _get_encoding_seekable($fh);
  }
  elsif (wantarray) {
    return _get_encoding_unseekable($fh);
  }
  else {
    croak $!;
  }
}

=head2 get_encoding_from_stream

  ($encoding, $spillage) = get_encoding_from_stream(*FH);

Read a BOM from an unrewindable source. This means reading the stream one byte
at a time until either a BOM is found or every possible BOM is ruled out. Any
non-BOM characters read from the handle will be returned in $spillage.

This function is less efficient than get_encoding_from_filehandle, but should
work just as well on a seekable handle as on an unseekable one.

=cut

# currently just a wrapper for _get_encoding_unseekable
# TODO: Try and ungetc() spillage?

sub get_encoding_from_stream (*) { _get_encoding_unseekable($_[0]) }

# internal: 
#
# Return encoding and seek to position after BOM
sub _get_encoding_seekable (*) {
  my $fh = shift;

  read($fh, my $bom, $MAX_BOM_LENGTH) or croak $!;

  my($enc, $off) = get_encoding_from_bom($bom);

  seek($fh, $off, SEEK_SET) or croak $!;

  return $enc;
}

# internal:
#
# Return encoding or non-BOM overspill
sub _get_encoding_unseekable (*) {
  my $fh = shift;

  my $so_far = '';
  for my $c (1 .. $MAX_BOM_LENGTH) {
    read($fh, my $byte, 1) or croak $!;
    $so_far .= $byte;

    my @possible = grep { $so_far eq substr($_, 0, $c) } keys %bom2enc;
    if (@possible == 1 and my $enc = $bom2enc{$so_far}) {
      return ($enc, '');
    }
    elsif (@possible == 0) {
      # might need to backtrack one byte
      my $spill = chop $so_far;
      if (my $enc = $bom2enc{$so_far}) {
	return ($enc, $spill);
      }
      else {
	return ('', $so_far . $spill);
      }
    }
  }
}

=head2 get_encoding_from_bom

  ($encoding, $offset) = get_encoding_from_bom($string)

Returns the encoding and length in bytes of the BOM in $string.

If there is no BOM, an empty string is returned and $offset is zero.

To get the data from the string, the following should work: 

  use Encode;

  my($encoding, $offset) = get_encoding_from_bom($string);

  if ($encoding) {
    $string = decode($encoding, substr($string, $offset))
  }

=cut

sub get_encoding_from_bom ($) {
  my $bom = shift || $_;

  my $encoding = '';
  my $offset = 0;

  my $bombs = join('|', sort {length $b <=> length $a} keys %bom2enc);
  if (my($found) = $bom =~ /^($bombs)/) {
    use bytes; # make sure we count bytes in length()
    $encoding = $bom2enc{$found};
    $offset = length($found);
  }

  return ($encoding, $offset);
}

=head1 PerlIO::via interface

File::BOM can be used as a PerlIO::via interface.

  open(HANDLE, '<:via(File::BOM)', 'my_file.txt');

  open(HANDLE, '>:encoding(UTF-16LE):via(File::BOM):utf8', 'out_file.txt)
  print "foo\n"; # BOM is written to file here

This method is less prone to errors on non-seekable files, but doesn't give you
any information about the encoding being used, or indeed whether or not a BOM
was present.

=head2 Reading

The via(File::BOM) layer must be added before the handle is read from, otherwise
any BOM will be missed. If there is no BOM, no decoding will be done.

=head2 Writing

Add the via(File::BOM) layer on top of a unicode encoding layer to print a BOM
at the start of the output file. This needs to be done before any data is
written. The BOM is written as part of the first print command on the handle, so
if you don't print anything to the handle, you won't get a BOM.

At the time of writing there is a "Wide character in print" warning generated
when the via(File::BOM) layer doesn't receive utf8 on writing.

  # This works OK
  open(FH, '>:encoding(UTF-16LE):via(File::BOM):utf8', $filename)

  # This generates warnings
  open(FH, '>:encoding(UTF-16LE):via(File::BOM)', $filename)

This glitch may be resolved in future versions of File::BOM, or future versions
of PerlIO::via.

=cut

sub PUSHED { bless({}, $_[0]) || -1 }

sub UTF8 {
  # This doesn't seem to work as advertised, at present.

  return 0;
}

sub FILL {
  my($self, $fh) = @_;

  my $line;
  if (not defined $self->{enc}) {
    ($self->{enc}, $line) = get_encoding_from_filehandle($fh);

    if ($self->{enc} ne '') { binmode($fh, ":encoding($self->{enc})") }

    $line .= <$fh>;
  }
  else {
    $line = <$fh>;
  }

  return $line;
}

sub WRITE {
  my($self, $buf, $fh) = @_;

  if (tell $fh == 0 and not $self->{wrote_bom}) {
    print $fh "\x{feff}";
    $self->{wrote_bom} = 1;
  }

  $buf = decode_utf8($buf, 1) unless Encode::is_utf8($buf, 1);

  print $fh $buf;

  return 1;
}

sub FLUSH { 0 }

1;

__END__

=head1 SEE ALSO

=over 4

=item * L<Encode>

=item * L<Encode::Unicode>

=item * L<http://www.unicode.org/unicode/faq/utf_bom.html#BOM>

=back

=head1 ERROR HANDLING

The default behaviour on encountering an IO error of any sort is to croak $! but
this is subject to change in future versions.

=head1 BUGS

The PerlIO::via interface has a few problems with writing, see above.

=head1 AUTHOR

Matt Lawrence E<lt>mattlaw@cpan.orgE<gt>

