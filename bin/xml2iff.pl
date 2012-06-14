#!/usr/bin/perl -w

use XML::Twig;
use Getopt::Std;

my $outfile;

%options=();
getopts('ho:O',\%options);
$outfile = $options{'o'} if defined $options{'o'};
my $use_internal_filename = $options{'O'} if defined $options{'O'};
defined $options{'h'} && usage() && exit;

if ($#ARGV > -1) {
	while ($#ARGV > -1) { # Process every file.
		print_iff($ARGV[0]);
		shift;
	}
} else {
	print_iff(); # Calling this with no parameters will cause XML::Twig to parse xml from stdin.
}

sub usage {
	print <<'EOT';
Usage: xml2iff.pl [ -h | -o outputfile | -O ] xmlfile
	Read an xml file and output an iff file.
	Anything that is not a regular file is ignored.
	If no input file is given, xml is read from stdin.
Options:
	-h             print this message
	-o outputfile  write to file outputfile (use - for  stdout)
	-O             write to file filename found in element: /iff/info/filename
EOT
}

sub print_iff {
	my ($path) = @_;
	if (defined $path) {
		# If we're parsing a file, then make sure it's ok to read.
		(! -f $path) && return; # silently skip anything that's not a regular file...
		(! -r $path) && print STDERR "Can't read file: $path ... skipping\n" && return; # ...but make some noise if it's not readable
	}
	# Lets get started!
	my ($ifftype, $format_str, $filename, $type, $size, $data, $storage_type);
	$pad = ''; # the chunk pad byte

	# Initialize the xml parser with a hash of xpath expressions and handlers for node processing.
	my $twig = new XML::Twig( TwigHandlers => {
		'/iff/info/endian'       => \&endian,
		'/iff/info/ifftype'      => \&ifftype,
		'/iff/info/ifftype2'     => \&type,
		'/iff/info/filesize'     => \&size,
		'/iff/info/filename'     => \&filename,
		'/iff/chunks/chunk/type' => \&type,
		'/iff/chunks/chunk/size' => \&size,
		'/iff/chunks/chunk/data' => \&data,
		'/iff/chunks/chunk'      => \&chunk,
		'/iff/info/storage_type' => \&storage_type,
		'/iff/info'              => \&info
	});

	# Parse our xml file, handling nodes on the way.
	if (defined $path) {
		$twig->parsefile( $path );
	} else {
		# if no path parse stdin
		$twig->parse( \*STDIN );
	}
	close OUT; # Note: this file was opened in the info handler
}

sub endian {
	my ($tree, $elem) = @_;
	my $endian = $elem->text;
	if ($endian eq 'big') {
		$format_str = 'N'; # write big-endian 32 bit unsigned integers
	} else {
		$format_str = 'V'; # write little-endian 32 bit unsigned integers
	}
}

sub ifftype {
	my ($tree, $elem) = @_;
	$ifftype = $elem->text;
}

sub type {
	my ($tree, $elem) = @_;
	$type = $elem->text;
}

sub size {
	my ($tree, $elem) = @_;
	$size = pack($format_str, $elem->text);
}

sub filename {
	my ($tree, $elem) = @_;
	$filename = $elem->text;
}

sub storage_type { # only "hexdump" suppported so far, maybe add gzip/base64 later
	my ($tree, $elem) = @_;
	$storage_type = $elem->text;
}

sub info {
	# When we get here, we know that all the info child elements have been
	# processed so we've got everything we need to start writing our iff file.

	# If -O option then use the filename embeded in the xml document (if it exists).
	$outfile = $filename if defined $use_internal_filename && $filename;

	# Bail if there's no file to write to at this point. I don't want
	# people spewing binary data into their terminal by accident.
	# To write to stdout, use - as the output filename.
	! defined $outfile and print "Please select an output file.\n" and usage and exit;

	open OUT, "> $outfile" or die "can't open $outfile for writing: $!";
	print OUT "$ifftype$size$type";        # write the header
	$ifftype = ''; $size = ''; $type = ''; # done with these
}

sub data {
	my ($tree, $elem) = @_;
	$data = $elem->text;
	$data =~ s/<!--.*?-->//g;  # delete any comments
	$data =~ s/\s//g;          # delete all white space
	$data = pack('H*', $data); # convert the ascii hex data back to binary
}

sub chunk {
	print OUT "$pad$type$size$data";        # write the chunk
	$pad = (length($data) % 2) ? "\0" : ''; # if chunk length is odd, remember to pad it when the next chunk is written 
	$type = ''; $size = ''; $data = '';     # clear our buffers
}
