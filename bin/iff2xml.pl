#!/usr/bin/perl -w

use constant IFFTYPES => qw( RIFX XFIR );
use constant IFFTYPES2 => qw( MV93 39VM MC95 );
use constant { INT_SIZE => 4 };
use Getopt::Std;

my $outfile = '-'; # default to stdout
my $columns = 40;  # set default
my ($use_filename_base, $ascii, $ascii_columns);

%options=();
getopts('ho:Orw:', \%options);
defined $options{'h'} && usage() && exit;

$outfile           = $options{'o'} if defined $options{'o'};
$use_filename_base = $options{'O'} if defined $options{'O'};
$columns           = $options{'w'} if defined $options{'w'};
$ascii             = $options{'r'} if defined $options{'r'}; # include readable ascii data for testing
$ascii_columns     = $columns if defined $ascii;
$columns <<= 1; # we have 2 chars for each byte, so double columns for wrapping hexdata

if ($#ARGV > -1) {
	while ($#ARGV > -1) { # process every file (probably only makes sense when using the -O option)
		print_xml($ARGV[0]);
		shift;
	}
} else {
	usage();
}

sub usage {
	print <<'EOT';
Usage: iff2xml.pl [-h | -o outputfile | -O ] file
	Read iff files and print as xml.
	Anything that is not a regular file is ignored.
Options:
	-h             print this message
	-o outputfile  write to file outputfile (default is stdout)
	-O             use the input filename base to make the xml output filename
	-r             Include a human <readable> element in each chunk that contains all ascii characters
	               with non printable characters replaced by periods (including '"<> to stay well formed).
	-w columns     Wrap the data if specified. The default is 40. Zero means do not wrap.
EOT
}

sub print_xml{
	my ($path) = @_;
	(! -f $path) && print STDERR "Not a file: $path ... skipping\n" && return;      # tell user this is not a file
	(! -r $path) && print STDERR "Can't read file: $path ... skipping\n" && return; # tell user this is not readable

	my $filename = $path;
	$filename =~ s/.*\///; # save the original filename in the xml document
	my ($ifftype, $filesize, $ifftype2, $type, $hexdata, $len_buf, $buf, $len, $format_str, $endian);

	open(FILE, '<', $path) or die "Can't open $path: $!";
	binmode(FILE);
	read FILE, $ifftype, INT_SIZE;
	(! grep(/$ifftype/, IFFTYPES)) && print STDERR "Does not appear to be an IFF file: $path ... skipping\n" && return;

	if ($ifftype eq 'RIFX') {
		$format_str = 'N'; # read big-endian 32 bit unsigned integers
		$endian = 'big';
	} else {
		$format_str = 'V'; # read little-endian 32 bit unsigned integers
		$endian = 'small';
	}
	read FILE, $len_buf, INT_SIZE;
	$filesize = unpack($format_str, $len_buf);

	read FILE, $ifftype2, INT_SIZE;

	# one more sanity check: see if we recognize the second type string
	(! grep(/$ifftype2/, IFFTYPES2)) && print STDERR "Unfamiliar IFF internal type: $path ... skipping\n" && return;

	if (defined $use_filename_base) {
		$outfile = $path;
		$outfile .= '.xml'; # append the .xml extension to avoid file name space collision
	}
	open OUT, "> $outfile" or die "can't open $outfile for writing: $!";
	print OUT <<EOT;
<?xml version="1.0"?>
<iff>
<info>
	<endian>$endian</endian>
	<ifftype>$ifftype</ifftype>
	<ifftype2>$ifftype2</ifftype2>
	<filesize>$filesize</filesize>
	<filename>$filename</filename>
	<data_storage>hexdump</data_storage>
</info>
<chunks>
EOT
	while (!eof(FILE)) {
		read FILE, $type, INT_SIZE;
		read FILE, $len_buf, INT_SIZE;
		$len = unpack($format_str, $len_buf);
		read FILE, $buf, $len;
		($len % 2) && seek FILE, 1, 1; # skip the pad byte if odd length
		$hexdata = unpack('H*', $buf); # convert the binary data to ascii hex
		if ($columns) {                # wrap the hexdata if $columns is greater than zero
			$hexdata =~ s/(.{1,$columns})/\t\t\t$1\n/g;
		} else {
			$hexdata .= "\n";          # if not wrapping, just append a newline
		}
		print OUT <<EOT;
	<chunk>
		<type>$type</type>
		<size>$len</size>
EOT
		if ($len eq '0') {
			print OUT "\t\t<data />\n";
			print OUT "\t\t<readable />\n" if defined $ascii;
		} else {
			print OUT "\t\t<data>\n$hexdata\t\t</data>\n"; # write the ascii hex data element
			if (defined $ascii) {                          # print readable ascii if using the -r option
				$hexdata = $buf;
				$hexdata =~ s/[^[:print:]]|[&'"<>]/./g;    # replace non printable characters and xml special characters with periods
				if ($columns) {                            # positive number so wrap to it
					$hexdata =~ s/(.{1,$ascii_columns})/\t\t\t$1\n/g;
				} else {                                   # otherwise just append a newline
					$hexdata .= "\n";
				}                                          # write the human readable version of the data
				print OUT "\t\t<readable>\n$hexdata\t\t</readable>\n";
			}
		}
		print OUT <<EOT;
	</chunk>
EOT
	}
	print OUT <<EOT;
</chunks>
</iff>
EOT
	close OUT;
}
