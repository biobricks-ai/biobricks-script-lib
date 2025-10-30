package Bio_Bricks::Store::Neptune::S3Staging;
# ABSTRACT: S3 staging wrapper for Neptune bulk loading

use Bio_Bricks::Common::Setup;
use Types::Common::String qw(NonEmptyStr);
use MooX::Log::Any;
use URI::s3;

with qw(MooX::Log::Any);

=head1 NAME

Bio_Bricks::Store::Neptune::S3Staging - S3 staging wrapper for Neptune bulk loading

=head1 SYNOPSIS

	use Bio_Bricks::Store::Neptune::S3Staging;

	my $staging = Bio_Bricks::Store::Neptune::S3Staging->new(
		bulk_loader      => $loader,
		staging_s3_prefix => 's3://my-bucket/neptune-staging',
		region           => 'us-east-1',
	);

	# Load a file, automatically staging if needed
	my $load_id = $staging->load_file(
		source_uri => 's3://dvc-bucket/files/md5/85/bcebf542d4397c04d7fbeb0a5683a1',
		file_path  => 'mesh.nt.gz',
		format     => 'ntriples',
		graph_uri  => 'http://example.org/graph',
	);

=head1 DESCRIPTION

This module wraps Bio_Bricks::Store::Neptune::BulkLoader and handles S3 staging
for files that need it. Neptune requires S3 URIs to have proper file extensions
(e.g., .gz, .nt) to detect compression and format. Content-addressable storage
systems like DVC use hash-based URIs that don't preserve extensions.

This class:
- Detects when a file needs staging (compressed file without proper extension)
- Copies files to a staging bucket preserving the path structure + extension
- Submits loads using the staged URI
- Tracks staged files to avoid duplicate copies

Example staging transformation (with staging_s3_prefix='s3://my-bucket/neptune-staging'):
  Source: s3://dvc-bucket/files/md5/e7/c81c75253235cd9ca39a0192c0b58f
  Staged: s3://my-bucket/neptune-staging/files/md5/e7/c81c75253235cd9ca39a0192c0b58f.nt.gz

=cut

# BulkLoader instance
ro bulk_loader => (
	isa => InstanceOf['Bio_Bricks::Store::Neptune::BulkLoader'],
	required => 1,
	handles => ['neptune', 'region'],
);

# S3 staging prefix (optional) - can be s3://bucket/prefix or just bucket/prefix
ro staging_s3_prefix => (
	isa => NonEmptyStr,
	required => 0,
	predicate => 1,
);

# AWS profile for S3 operations
ro aws_profile => (
	isa => NonEmptyStr,
	required => 0,
	predicate => 1,
);

# Track staged files to avoid duplicate copies
lazy staged_files => sub {
	{};
};

=head1 METHODS

=method needs_staging

Check if a file needs to be staged due to extension mismatch.

	my $needs_staging = $staging->needs_staging(
		source_uri => 's3://bucket/path/without/extension',
		file_path  => 'mesh.nt.gz',
	);

Returns true if:
- File is compressed (.gz, .bz2) but S3 URI doesn't end with compression extension
- Staging S3 prefix is configured

=cut

method needs_staging(Str :$source_uri, Str :$file_path) {
	# Can't stage without a staging S3 prefix
	return 0 unless $self->staging_s3_prefix;

	# Check if file is compressed
	return 0 unless $file_path =~ /\.(gz|bz2)$/i;

	my $compression_ext = $1;

	# Parse the S3 URI and check if key already has the compression extension
	my $source = URI::s3->new($source_uri);
	return 0 unless $source->bucket;  # Invalid URI, can't stage

	my $source_key = $source->key;
	return 0 if $source_key =~ /\.\Q$compression_ext\E$/i;

	# URI doesn't have proper extension - needs staging
	return 1;
}

=method build_staging_uri

Build the staging S3 URI by preserving the source path and adding extension.

	my $staged_uri = $staging->build_staging_uri(
		source_uri => 's3://dvc-bucket/files/md5/85/bcebf542d4397c04d7fbeb0a5683a1',
		file_path  => 'mesh.nt.gz',
	);

With staging_s3_prefix='s3://my-bucket/neptune-staging':
Returns: s3://my-bucket/neptune-staging/files/md5/85/bcebf542d4397c04d7fbeb0a5683a1.nt.gz

=cut

method build_staging_uri(Str :$source_uri, Str :$file_path) {
	croak "staging_s3_prefix not configured" unless $self->has_staging_s3_prefix;

	# Parse source URI
	my $source = URI::s3->new($source_uri);
	croak "Invalid S3 URI: $source_uri" unless $source->bucket;

	# Parse or construct staging prefix URI
	my $prefix_str = $self->staging_s3_prefix;
	$prefix_str = "s3://$prefix_str" unless $prefix_str =~ m{^s3://};
	my $staging_base = URI::s3->new($prefix_str);
	croak "Invalid staging S3 prefix: " . $self->staging_s3_prefix unless $staging_base->bucket;

	# Get source path segments (everything after bucket)
	# Filter out empty segments (path_segments includes leading empty string)
	my @source_segments = grep { defined $_ && $_ ne '' } $source->path_segments;

	# Extract extension from file_path (e.g., .nt.gz, .ttl.bz2)
	my ($ext) = $file_path =~ /(\.[^.]+(?:\.[^.]+)?)$/;
	$ext //= '';

	# Clone staging base and add source segments + extension
	my $staged_uri = $staging_base->clone;
	my @base_segments = $staged_uri->path_segments;

	# Append source segments to base segments
	# Last segment needs extension appended
	my @new_segments = (@base_segments, @source_segments);
	if (@new_segments && $ext) {
		$new_segments[-1] .= $ext;
	}

	$staged_uri->path_segments(@new_segments);

	return $staged_uri->as_string;
}

=method stage_file

Copy a file to the staging bucket with proper extension.

	my $staged_uri = $staging->stage_file(
		source_uri => 's3://bucket/hash/path',
		file_path  => 'mesh.nt.gz',
	);

Returns the staged S3 URI.

=cut

method stage_file(Str :$source_uri, Str :$file_path) {
	croak "staging_s3_prefix not configured" unless $self->has_staging_s3_prefix;
	croak "aws_profile not configured" unless $self->has_aws_profile;

	# Check if already staged
	my $cache_key = "$source_uri|$file_path";
	if (my $cached = $self->staged_files->{$cache_key}) {
		$self->log->debug("Using cached staged file", { staged_uri => $cached });
		return $cached;
	}

	# Build staging URI
	my $staged_uri = $self->build_staging_uri(
		source_uri => $source_uri,
		file_path  => $file_path,
	);

	$self->log->info("Staging file to S3", {
		source => $source_uri,
		staged => $staged_uri,
	});

	# Build AWS CLI command for S3 copy (server-side)
	# Use --metadata-directive COPY to copy metadata but skip tags (no GetObjectTagging needed)
	my @cmd = ('aws', 's3', 'cp', $source_uri, $staged_uri, '--metadata-directive', 'COPY');
	push @cmd, '--profile', $self->aws_profile;
	push @cmd, '--region', $self->region if $self->region;

	# Execute copy
	my $result = system(@cmd);
	if ($result != 0) {
		croak "Failed to stage file: aws s3 cp returned $result";
	}

	$self->log->info("File staged successfully", { staged_uri => $staged_uri });

	# Cache the staged URI
	$self->staged_files->{$cache_key} = $staged_uri;

	return $staged_uri;
}

=method load_file

Load a file into Neptune, automatically staging if needed.

	my $load_id = $staging->load_file(
		source_uri => 's3://bucket/hash/path',
		file_path  => 'mesh.nt.gz',
		format     => 'ntriples',
		graph_uri  => 'http://example.org/graph',
	);

Returns the Neptune load ID, or undef on failure.

=cut

method load_file(
	Str :$source_uri,
	Str :$file_path,
	Str :$format,
	Maybe[Str] :$graph_uri = undef,
) {
	my $load_uri = $source_uri;

	# Check if we need to stage this file
	if ($self->needs_staging(source_uri => $source_uri, file_path => $file_path)) {
		$self->log->info("File needs staging", {
			source_uri => $source_uri,
			file_path  => $file_path,
			reason     => "Compressed file without proper extension in S3 URI",
		});

		$load_uri = $self->stage_file(
			source_uri => $source_uri,
			file_path  => $file_path,
		);
	}

	# Use the bulk loader to start the load
	return $self->bulk_loader->start_load(
		source_uri => $load_uri,
		format     => $format,
		graph_uri  => $graph_uri,
	);
}

1;

__END__

=head1 SEE ALSO

L<Bio_Bricks::Store::Neptune::BulkLoader>
L<Bio_Bricks::Store::Neptune>

=cut
