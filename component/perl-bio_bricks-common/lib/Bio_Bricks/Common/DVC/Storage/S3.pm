package Bio_Bricks::Common::DVC::Storage::S3;

use Bio_Bricks::Common::Setup;
use Bio_Bricks::Common::DVC::Error;
use URI::s3;
use Bio_Bricks::Common::AWS::Paws;
use Bio_Bricks::Common::DVC::DirectoryParser;

with qw(MooX::Log::Any);

extends 'Bio_Bricks::Common::DVC::Storage';

# Override base_uri type for S3
has '+base_uri' => (isa => InstanceOf['URI::s3']);

# S3 client for fetching directory metadata (can be injected for testing/DI)
has s3_client => (
	is => 'ro',
	required => 0,
	lazy => 1,
	builder => '_build_s3_client'
);

method _build_s3_client () {
	my $paws = Bio_Bricks::Common::AWS::Paws->new(region => 'us-east-1'); # Default region
	return $paws->s3;
}

method resolve ($output_obj) {
	return unless $output_obj && $output_obj->EFFECTIVE_HASH;

	my $hash = $output_obj->EFFECTIVE_HASH;
	my ($prefix, $suffix) = $self->hash_path($hash);

	my $uri = $self->base_uri->clone;
	my @segments = $uri->path_segments;
	$uri->path_segments(@segments, 'files', 'md5', $prefix, $suffix);

	$self->log->tracef("Resolved S3 URI for %s: %s", $output_obj->path, $uri->as_string);

	return $uri;
}

# Keep file_uri for backward compatibility
method file_uri ($output_obj) {
	return $self->resolve($output_obj);
}

# Fetch and parse directory metadata from S3
method fetch_directory ($dir_output) {

	my $dir_uri = $self->resolve($dir_output);
	unless ($dir_uri) {
		$self->log->warnf("Could not resolve URI for directory: %s", $dir_output->path);
		return;
	}

	$self->log->infof("Fetching directory from S3: bucket=%s, key=%s", $dir_uri->bucket, $dir_uri->key);

	my $directory;
	try {
		my $get_result = $self->s3_client->GetObject(
			Bucket => $dir_uri->bucket,
			Key    => $dir_uri->key
		);

		if ($get_result->Body) {
			my $json_content = $get_result->Body;
			$self->log->infof("Successfully fetched .dir file for %s, size: %d bytes", $dir_output->path, length($json_content));
			$self->log->tracef("JSON content for %s: %s", $dir_output->path, $json_content);

			$directory = Bio_Bricks::Common::DVC::DirectoryParser->parse_string($json_content);
			if ($directory) {
				$self->log->infof("Successfully parsed directory metadata for %s", $dir_output->path);
			} else {
				$self->log->warnf("Failed to parse directory JSON for %s", $dir_output->path);
			}
		} else {
			$self->log->warnf("Empty body returned for directory: %s", $dir_output->path);
		}
	} catch ($e) {
		Bio_Bricks::Common::DVC::Error::storage::fetch->throw({
			msg => "Storage error fetching directory " . $dir_output->path,
			payload => {
				backend => 'S3',
				bucket => $dir_uri->bucket,
				key => $dir_uri->key,
				path => $dir_output->path,
				error => $e,
			}
		});
	}

	return $directory;
}

# URI-based storage operations
method head_object ($uri) {

	try {
		return $self->s3_client->HeadObject(
			Bucket => $uri->bucket,
			Key => $uri->key
		);
	} catch ($e) {
		$self->log->errorf("S3 head_object error for %s: %s", $uri->as_string, $e);
		die "S3 head_object error: $e";
	}
}

method get_object ($uri) {

	try {
		return $self->s3_client->GetObject(
			Bucket => $uri->bucket,
			Key => $uri->key
		);
	} catch ($e) {
		$self->log->errorf("S3 get_object error for %s: %s", $uri->as_string, $e);
		die "S3 get_object error: $e";
	}
}

method object_exists ($uri) {

	try {
		$self->head_object($uri);
		return 1;
	} catch ($e) {
		# HeadObject throws NoSuchKey if object doesn't exist
		return 0 if $e =~ /NoSuchKey/i;
		# Re-throw other errors
		die $e;
	}
}

1;
