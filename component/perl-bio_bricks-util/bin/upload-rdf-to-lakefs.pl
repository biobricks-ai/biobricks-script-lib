#!/usr/bin/env perl

use Bio_Bricks::Common::Setup ':base';

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../perl-bio_bricks-lakefs/lib";

use Bio_Bricks::LakeFS;
use Bio_Bricks::LakeFS::Lakectl;
use Bio_Bricks::Common::Config;
use Bio_Bricks::Common::AWS::Paws;
use Bio_Bricks::Common::AWS::S3;
use Bio_Bricks::Common::Rclone;
use Bio_Bricks::Common::AWS::Rclone;
use Bio_Bricks::LakeFS::Rclone;
use Bio_Bricks::Common::Output qw(:basic);
use Text::CSV;
use Getopt::Long;
use Pod::Usage;
use Path::Tiny;

# Command line options
my %opts = (
	input => '-',           # CSV input file (default: STDIN)
	lakefs_repo => undef,   # LakeFS repository name
	branch => 'main',       # LakeFS branch
	prefix => '',           # Path prefix in LakeFS
	commit_message => 'Upload RDF files from BioBricks',
	dry_run => 0,          # Don't actually upload
	use_rclone => 1,       # Use rclone for direct S3→LakeFS transfers (preferred)
	use_lakectl => 0,      # Use lakectl for file uploads
	size_threshold => 0,   # Size threshold for method selection
	help => 0,
);

GetOptions(
	'input|i=s'     => \$opts{input},
	'repo|r=s'      => \$opts{lakefs_repo},
	'branch|b=s'    => \$opts{branch},
	'prefix|p=s'    => \$opts{prefix},
	'message|m=s'   => \$opts{commit_message},
	'dry-run|n'     => \$opts{dry_run},
	'use-rclone!'   => \$opts{use_rclone},
	'use-lakectl!'  => \$opts{use_lakectl},
	'size-threshold=i' => \$opts{size_threshold},
	'help|h'        => \$opts{help},
) or pod2usage(2);

pod2usage(1) if $opts{help};
pod2usage("--repo is required") unless $opts{lakefs_repo};

fun main() {
	# Initialize clients
	my $lakefs = Bio_Bricks::LakeFS->new();
	my $lakectl;
	my ($rclone, $s3_remote, $lakefs_remote);

	# Initialize rclone if requested (preferred method)
	if ($opts{use_rclone}) {
		try {
			$rclone = Bio_Bricks::Common::Rclone->new();
			my $aws_rclone = Bio_Bricks::Common::AWS::Rclone->new();
			my $lakefs_rclone = Bio_Bricks::LakeFS::Rclone->new();

			# Create S3 remote for BioBricks data
			$aws_rclone->create_biobricks_s3_remote($rclone, 'biobricks-s3');
			$s3_remote = 'biobricks-s3';

			# Create LakeFS remote
			$lakefs_rclone->create_lakefs_remote($rclone, 'lakefs-target');
			$lakefs_remote = 'lakefs-target';

			output_info("Using rclone for direct S3→LakeFS transfers") if $opts{verbose};
		} catch ($e) {
			output_warning("Failed to initialize rclone: $e");
			output_info("Falling back to lakectl or HTTP API");
			$opts{use_rclone} = 0;
		}
	}

	# Initialize lakectl if requested or rclone failed
	if ($opts{use_lakectl} && !$opts{use_rclone}) {
		try {
			$lakectl = Bio_Bricks::LakeFS::Lakectl->new();
		} catch ($e) {
			output_warning("Failed to initialize lakectl: $e");
			output_info("Falling back to HTTP API for all uploads");
			$opts{use_lakectl} = 0;
		}
	}

	my $config = Bio_Bricks::Common::Config->new;
	my $paws = Bio_Bricks::Common::AWS::Paws->new(region => $config->aws_region);
	my $s3_client = Bio_Bricks::Common::AWS::S3->new(
		paws => $paws,
		bucket => $config->s3_bucket
	);

	# Verify LakeFS repository exists
	unless ($opts{dry_run}) {
		try {
			$lakefs->get_repository($opts{lakefs_repo});
		} catch ($e) {
			die "LakeFS repository '$opts{lakefs_repo}' not found: $e\n";
		}
		output_info("Using LakeFS repository: $opts{lakefs_repo}");
	}

	# Open CSV input
	my $fh;
	if ($opts{input} eq '-') {
		$fh = \*STDIN;
	} else {
		open $fh, '<', $opts{input} or die "Cannot open $opts{input}: $!";
	}

	my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });

	# Read and verify header
	my $header = $csv->getline($fh);
	unless ($header && @$header >= 5 &&
			$header->[0] eq 'repo' && $header->[1] eq 'stage' &&
			$header->[2] eq 'path' && $header->[3] eq 's3' && $header->[4] eq 'rev') {
		die "Invalid CSV header. Expected: repo,stage,path,s3,rev\n";
	}

	my $upload_count = 0;
	my $error_count = 0;

	# Process each row
	while (my $row = $csv->getline($fh)) {
		my ($repo, $stage, $path, $s3_uri, $rev) = @$row;

		try {
			upload_file($lakefs, $lakectl, $rclone, $s3_remote, $lakefs_remote, $s3_client, $repo, $stage, $path, $s3_uri, $rev);
			$upload_count++;
		} catch ($e) {
			output_error("Error uploading $path from $repo: $e");
			$error_count++;
		}
	}

	close $fh unless $fh == \*STDIN;

	# Commit changes if not dry run and we uploaded files
	if (!$opts{dry_run} && $upload_count > 0) {
		output_info("Committing $upload_count files to LakeFS...");
		try {
			$lakefs->commit(
				$opts{lakefs_repo},
				$opts{branch},
				$opts{commit_message} . " ($upload_count files)"
			);
			output_success("Successfully committed changes to $opts{lakefs_repo}/$opts{branch}");
		} catch ($e) {
			output_error("Error committing to LakeFS: $e");
		}
	}

	output_info("Summary: $upload_count uploaded, $error_count errors");
}

fun upload_file($lakefs, $lakectl, $rclone, $s3_remote, $lakefs_remote, $s3_client, $repo, $stage, $path, $s3_uri, $rev) {

	# Parse S3 URI to get bucket and key
	my ($s3_bucket, $s3_key);
	if ($s3_uri =~ m{^s3://([^/]+)/(.+)$}) {
		($s3_bucket, $s3_key) = ($1, $2);
	} else {
		die "Invalid S3 URI format: $s3_uri";
	}

	# Construct LakeFS path with revision information
	my $lakefs_path = $opts{prefix};
	$lakefs_path .= '/' if $lakefs_path && $lakefs_path !~ m{/$};
	$lakefs_path .= "$repo/$stage/$path";

	# Truncate revision to first 8 characters for path readability
	my $short_rev = substr($rev || 'unknown', 0, 8);

	if ($opts{dry_run}) {
		output_info("DRY RUN: Would upload s3://$s3_bucket/$s3_key -> lakefs://$opts{lakefs_repo}/$opts{branch}/$lakefs_path (rev: $short_rev)");
		return;
	}

	output_info("Uploading $lakefs_path...");

	# Method 1: Direct S3→LakeFS with rclone (preferred - no local storage)
	if ($opts{use_rclone} && $rclone && $s3_remote && $lakefs_remote) {
		output_info("  Using rclone for direct S3→LakeFS transfer...");

		# Construct rclone URLs
		my $source_url = "$s3_remote:$s3_bucket/$s3_key";
		my $dest_url = "$lakefs_remote:$opts{lakefs_repo}/$opts{branch}/$lakefs_path";

		try {
			$rclone->copy($source_url, $dest_url,
				progress => $opts{verbose},
				checksum => 1
			);
		} catch ($e) {
			die "Failed to copy with rclone: $e";
		}

		output_success("  Uploaded $lakefs_path (rev: $short_rev) via rclone");
		return;
	}

	# Method 2: lakectl with temporary file (for large files)
	my $use_lakectl_for_file = 0;
	my $file_size = 0;

	if ($opts{use_lakectl} && $lakectl) {
		# Get object metadata to check size
		try {
			my $head_response = $s3_client->head_object($s3_key);
			$file_size = $head_response->ContentLength || 0;
			$use_lakectl_for_file = $file_size >= $opts{size_threshold};
		} catch ($e) {
			output_warning("Could not get file size, using HTTP API: $e");
		}
	}

	if ($use_lakectl_for_file) {
		# Use lakectl for large file
		output_info("  Using lakectl for large file (" . _format_bytes($file_size) . ")...");

		# Download to temporary file
		my $temp_file = Path::Tiny->tempfile(SUFFIX => '.rdf');
		try {
			my $response = $s3_client->get_object($s3_key);
			$temp_file->spew_raw($response->Body);
		} catch ($e) {
			die "Failed to download from S3 to temp file: $e";
		}

		# Upload using lakectl
		my $lakefs_uri = "lakefs://$opts{lakefs_repo}/$opts{branch}/$lakefs_path";
		try {
			$lakectl->upload($temp_file->stringify, $lakefs_uri);
		} catch ($e) {
			die "Failed to upload to LakeFS with lakectl: $e";
		}

		output_success("  Uploaded $lakefs_path (" . _format_bytes($file_size) . ", rev: $short_rev) via lakectl");
	} else {
		# Method 3: HTTP API for small files (loads into memory)
		my $content;
		try {
			my $response = $s3_client->get_object($s3_key);
			$content = $response->Body;
		} catch ($e) {
			die "Failed to download from S3: $e";
		}

		# Upload to LakeFS
		try {
			$lakefs->upload_object($opts{lakefs_repo}, $opts{branch}, $lakefs_path, $content);
		} catch ($e) {
			die "Failed to upload to LakeFS: $e";
		}

		output_success("  Uploaded $lakefs_path (" . _format_bytes(length($content)) . ", rev: $short_rev) via HTTP");
	}
}

fun _format_bytes($bytes) {
	my @units = ('B', 'KB', 'MB', 'GB', 'TB');
	my $unit = 0;
	my $size = $bytes;

	while ($size >= 1024 && $unit < $#units) {
		$size /= 1024;
		$unit++;
	}

	return sprintf("%.1f %s", $size, $units[$unit]);
}

# Validate environment
try {
	my $config = Bio_Bricks::Common::Config->new;
	my $paws = Bio_Bricks::Common::AWS::Paws->new(region => $config->aws_region);
	$paws->validate_authentication;
	$config->validate_s3_config;
} catch ($e) {
	die "AWS configuration error: $e\n" .
		"Please set up AWS credentials and BIOBRICKS_S3_URI environment variable.\n";
}

# Check LakeFS environment
unless ($ENV{LAKEFS_ENDPOINT}) {
	die "LAKEFS_ENDPOINT environment variable not set\n";
}
unless ($ENV{LAKEFS_ACCESS_KEY_ID} && $ENV{LAKEFS_SECRET_ACCESS_KEY}) {
	die "LAKEFS_ACCESS_KEY_ID and LAKEFS_SECRET_ACCESS_KEY environment variables not set\n";
}

main();

__END__

=head1 NAME

upload-rdf-to-lakefs.pl - Upload RDF files from S3 to LakeFS

=head1 SYNOPSIS

	upload-rdf-to-lakefs.pl [options]

	Options:
		-i, --input FILE        Input CSV file (default: STDIN)
		-r, --repo REPO         LakeFS repository name (required)
		-b, --branch BRANCH     LakeFS branch (default: main)
		-p, --prefix PREFIX     Path prefix in LakeFS (default: none)
		-m, --message MSG       Commit message (default: "Upload RDF files from BioBricks")
		-n, --dry-run          Don't actually upload files
		--use-rclone           Use rclone for direct S3→LakeFS transfers (default: true)
		--no-use-rclone        Disable rclone transfers
		--use-lakectl          Use lakectl for uploads (fallback)
		--no-use-lakectl       Disable lakectl uploads
		--size-threshold BYTES Size threshold for lakectl vs HTTP (default: 0)
		-h, --help             Show this help

=head1 DESCRIPTION

This script reads a CSV file containing RDF file locations (as generated by
scan-biobricks-rdf.pl) and uploads them from S3 to a LakeFS repository.

The CSV format expected is:
	repo,stage,path,s3,rev

Files are uploaded to LakeFS with the path structure:
	[prefix/]repo/stage/path

The script supports three upload methods in order of preference:

1. **rclone** (default): Direct S3→LakeFS transfers with no local storage required
2. **lakectl**: Downloads to temp files then uploads (good for large files)
3. **HTTP API**: Loads files into memory (suitable for small files only)

The script automatically falls back through methods if tools are unavailable.

=head1 EXAMPLES

	# Upload all RDF files to LakeFS repository 'rdf-data'
	./scan-biobricks-rdf.pl | ./upload-rdf-to-lakefs.pl --repo rdf-data

	# Dry run with custom prefix
	./upload-rdf-to-lakefs.pl --repo rdf-data --prefix biobricks --dry-run < rdf_files.csv

	# Upload to specific branch
	./upload-rdf-to-lakefs.pl --repo rdf-data --branch feature-branch < rdf_files.csv

=head1 ENVIRONMENT VARIABLES

=over 4

=item AWS Configuration

BIOBRICKS_S3_URI, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_PROFILE

=item LakeFS Configuration

LAKEFS_ENDPOINT, LAKEFS_ACCESS_KEY_ID, LAKEFS_SECRET_ACCESS_KEY

=back

=cut
