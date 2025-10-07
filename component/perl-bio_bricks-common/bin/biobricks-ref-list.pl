#!/usr/bin/env perl

use Bio_Bricks::Common::Setup ':base';

use FindBin;
use lib "$FindBin::Bin/../lib";

use Bio_Bricks::Common::GitHub::Pithub;
use Bio_Bricks::Common::DVC::LockParser;
use Bio_Bricks::Common::DVC::Iterator;
use Bio_Bricks::Common::DVC::Storage::S3;
use Bio_Bricks::Common::Config;
use Bio_Bricks::Common::FileType qw(detect_file_type);
use MIME::Base64;
use Text::CSV;
use JSON::PP;
use Getopt::Long;
use Pod::Usage;

# Parse command line options
my $format = 'text';
my $output_file;
my $help;

GetOptions(
	'format=s' => \$format,
	'output=s' => \$output_file,
	'help'     => \$help,
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage("No biobricks reference URL provided") unless @ARGV;

my $biobricks_ref = $ARGV[0];

# Parse the biobricks reference URL
# Format: https://github.com/biobricks-ai/REPO#SHA
my ($org, $repo, $rev);
if ($biobricks_ref =~ m{https://github\.com/([^/]+)/([^#]+)(?:#(.+))?}) {
	$org = $1;
	$repo = $2;
	$rev = $3 || 'main';
} else {
	die "Invalid biobricks reference URL format. Expected: https://github.com/ORG/REPO#SHA\n";
}

say STDERR "Processing: $org/$repo at revision $rev" if $format eq 'text';

# Initialize components
my $pithub = Bio_Bricks::Common::GitHub::Pithub->new;
my $config = Bio_Bricks::Common::Config->new;
my $dvc_storage = Bio_Bricks::Common::DVC::Storage::S3->new(
	base_uri => $config->s3_uri
);

# Fetch dvc.lock at specific revision using correct Pithub API
my $content_result = $pithub->repos->contents->get(
	user => $org,
	repo => $repo,
	path => 'dvc.lock',
	params => { ref => $rev },  # Correct parameter format
);

unless ($content_result->success) {
	die "Failed to fetch dvc.lock from $repo at revision $rev: " .
		$content_result->response->status_line . "\n";
}

my $file_data = $content_result->content;
my $decoded_content = decode_base64($file_data->{content});

# Debug: dump the dvc.lock content (commented out)
# say STDERR "=== DVC.LOCK CONTENT ===";
# say STDERR $decoded_content;
# say STDERR "=== END DVC.LOCK ===";

# Parse DVC lock file
my $dvc_lock;
try {
	$dvc_lock = Bio_Bricks::Common::DVC::LockParser->parse_string($decoded_content);
} catch ($e) {
	die "Failed to parse dvc.lock: $e\n";
}

# Prepare output
my $fh;
if ($output_file) {
	open $fh, '>', $output_file or die "Cannot open $output_file: $!";
} else {
	$fh = \*STDOUT;
}

# CSV writer for CSV format
my $csv;
if ($format eq 'csv') {
	$csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
	$csv->say($fh, [qw(stage path type hash size s3_uri biobricks_ref)]);
}

# Header for text format
if ($format eq 'text') {
	printf $fh "%-20s %-50s %-12s %-32s %10s\n",
		"Stage", "Path", "Type", "Hash (MD5)", "Size";
	say $fh "="x130;
}

# Process each stage
my $total_files = 0;
my $total_size = 0;

for my $stage_name (@{$dvc_lock->STAGE_NAMES}) {
	my $stage = $dvc_lock->get_stage($stage_name);

	for my $output (@{$stage->outs}) {
		# Check if this is a single file or directory
		my $is_directory = $output->IS_DIRECTORY;

		if (!$is_directory) {
			# Single file - get size from S3, fallback to output metadata
			my $file_path = $output->path;
			my $file_hash = $output->EFFECTIVE_HASH;
			my $file_size = get_file_size_from_s3($file_hash, $dvc_storage) // $output->size // 0;

			# Build S3 URI
			my $s3_uri = sprintf("s3://%s/%s/files/md5/%s/%s",
				$config->s3_bucket,
				$config->s3_prefix || 'insdvc',
				substr($file_hash, 0, 2),
				substr($file_hash, 2)
			);

			# Determine file type
			my $file_type = detect_file_type($file_path);

			$total_files++;
			$total_size += $file_size;

			# Output based on format
			output_file_info($fh, $format, $csv, {
				stage_name => $stage_name,
				file_path => $file_path,
				file_type => $file_type,
				file_hash => $file_hash,
				file_size => $file_size,
				s3_uri => $s3_uri,
				biobricks_ref => $biobricks_ref,
			});
		} else {
			# Directory - need to iterate
			my $iterator = Bio_Bricks::Common::DVC::Iterator->new(
				storage => $dvc_storage,
				output => $output,
				recurse => 1,
			);

			while (my $item = $iterator->()) {
				if ($item->is_err()) {
					warn "Error processing $stage_name/" . $output->path . ": " .
						 $item->unwrap_err() . "\n";
					next;
				}

				my $file_item = $item->unwrap();
				my $file_path = $file_item->path;
				my $file_hash = $file_item->hash;

				# Always try to get file size from S3 using ContentLength
				my $file_size = get_file_size_from_s3($file_hash, $dvc_storage);

				# Fallback for single-file directories if S3 lookup fails
				if (!defined($file_size) && $output->nfiles && $output->nfiles == 1) {
					$file_size = $output->size;
				}

				my $s3_uri = $file_item->uri->as_string;
				my $file_type = detect_file_type($file_path);

				$total_files++;
				$total_size += $file_size // 0;

				# Output based on format
				output_file_info($fh, $format, $csv, {
					stage_name => $stage_name,
					file_path => $file_path,
					file_type => $file_type,
					file_hash => $file_hash,
					file_size => $file_size,
					s3_uri => $s3_uri,
					biobricks_ref => $biobricks_ref,
				});
			}
		}
	}
}

# Print summary for text format
if ($format eq 'text') {
	say $fh "\n" . "="x80;
	say $fh "Summary for $biobricks_ref:";
	say $fh "  Total files: $total_files";
	say $fh "  Total size: " . format_size($total_size);
	say $fh "  Stages: " . scalar(@{$dvc_lock->STAGE_NAMES});
	say $fh "";
	say $fh "Note: File sizes retrieved from S3 object metadata when available.";
	say $fh "      Sizes shown as 'N/A' when S3 lookup fails.";
}

close $fh if $output_file;

# Helper to output file information in different formats
fun output_file_info($fh, $format, $csv, $info) {

	if ($format eq 'text') {
		printf $fh "%-20s %-50s %-12s %-32s %10s\n",
			$info->{stage_name},
			length($info->{file_path}) > 50 ?
				substr($info->{file_path}, 0, 47) . '...' :
				$info->{file_path},
			$info->{file_type},
			substr($info->{file_hash}, 0, 32),
			defined($info->{file_size}) ? format_size($info->{file_size}) : 'N/A';
	} elsif ($format eq 'csv') {
		$csv->say($fh, [
			$info->{stage_name},
			$info->{file_path},
			$info->{file_type},
			$info->{file_hash},
			$info->{file_size} // '',
			$info->{s3_uri},
			$info->{biobricks_ref}
		]);
	} elsif ($format eq 'json') {
		say $fh JSON::PP->new->utf8->encode($info);
	}
}

# Helper to get file size from S3 using MD5 hash
fun get_file_size_from_s3($md5_hash, $dvc_storage) {

	# Use the DVC storage to resolve the URI for this hash
	# Create a temporary output object with just the hash
	my $temp_output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'temp',
		md5 => $md5_hash,
	);

	my $uri = $dvc_storage->resolve($temp_output);
	return undef unless $uri;

	# Use the storage's head_object method to get S3 metadata
	my $content_length;
	try {
		my $head_result = $dvc_storage->head_object($uri);
		if ($head_result && defined($head_result->ContentLength)) {
			$content_length = $head_result->ContentLength;
		}
	} catch ($e) {
		# Silently ignore S3 errors
	}

	return $content_length;
}

# Helper to format file sizes
fun format_size($size) {
	my @units = qw(B KB MB GB TB);
	my $unit = 0;

	while ($size > 1024 && $unit < @units - 1) {
		$size /= 1024;
		$unit++;
	}

	return sprintf("%.1f %s", $size, $units[$unit]);
}

__END__

=head1 NAME

biobricks-ref-list.pl - List files in a BioBricks repository at a specific revision

=head1 SYNOPSIS

biobricks-ref-list.pl [options] BIOBRICKS_REF

  BIOBRICKS_REF format: https://github.com/biobricks-ai/REPO#SHA

  Options:
	--format=FORMAT    Output format: text (default), csv, json
	--output=FILE      Output file (default: stdout)
	--help             Show this help message

=head1 EXAMPLES

  # List files in text format
  biobricks-ref-list.pl https://github.com/biobricks-ai/mesh-kg#63c3f82383121b3bf99a5ede5a4ccad3334e7cb5

  # Output as CSV
  biobricks-ref-list.pl --format=csv --output=files.csv \
	https://github.com/biobricks-ai/spoke-rdf#a80718cf9ec0727ebecf326e4ad97255b44807ca

  # Output as JSON (one object per line)
  biobricks-ref-list.pl --format=json \
	https://github.com/biobricks-ai/biobricks-okg

=head1 DESCRIPTION

This script lists all files in a BioBricks repository at a specific Git revision
by fetching and parsing the dvc.lock file. It can output in multiple formats
for different use cases.

=cut
