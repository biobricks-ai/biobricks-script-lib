package Bio_Bricks::LakeFS::Rclone;
# ABSTRACT: LakeFS rclone configuration generator

use Bio_Bricks::Common::Setup;
use Bio_Bricks::LakeFS::Auth;
use URI;
use Log::Any qw($log);

lazy auth => sub {
	Bio_Bricks::LakeFS::Auth->new;
}, isa => InstanceOf['Bio_Bricks::LakeFS::Auth'];

method generate_config ($remote_name, %options) {
	my ($endpoint, $access_key_id, $secret_access_key) = $self->auth->get_credentials;

	unless ($endpoint && $access_key_id && $secret_access_key) {
		croak "LakeFS credentials not available. Please configure LAKEFS_* environment variables or ~/.lakefs/config.";
	}

	$log->debug("Generating rclone config for remote '$remote_name'", {
		api_endpoint => $endpoint,
		has_access_key => defined($access_key_id),
		has_secret_key => defined($secret_access_key)
	});

	my %rclone_config = (
		type => 's3',
		provider => 'Other',
		endpoint => $endpoint,
		access_key_id => $access_key_id,
		secret_access_key => $secret_access_key,
	);

	# LakeFS-specific optimizations
	$rclone_config{no_check_bucket} = 'true';  # Skip bucket validation
	$rclone_config{force_path_style} = 'true'; # Use path-style URLs

	# Parse endpoint and convert API endpoint to S3 gateway endpoint
	my $uri = URI->new($endpoint);
	if ($uri && $uri->scheme) {
		# Convert API endpoint (with /api/v1) to S3 gateway endpoint (without /api/v1)
		my $s3_endpoint = $endpoint;
		$s3_endpoint =~ s{/api/v1/?$}{};  # Remove /api/v1 suffix
		$rclone_config{endpoint} = $s3_endpoint;

		$log->debug("Converted API endpoint to S3 gateway endpoint", {
			api_endpoint => $endpoint,
			s3_endpoint => $s3_endpoint
		});
	} else {
		# Assume HTTPS if no scheme provided
		$rclone_config{endpoint} = "https://$endpoint";
		$log->debug("Added HTTPS scheme to endpoint", {
			original => $endpoint,
			final => $rclone_config{endpoint}
		});
	}

	# LakeFS doesn't support all S3 features, so disable some
	$rclone_config{disable_checksum} = 'true';
	$rclone_config{no_head_object} = 'false';  # LakeFS supports HEAD

	# Performance optimizations for LakeFS
	if ($options{upload_concurrency}) {
		$rclone_config{upload_concurrency} = $options{upload_concurrency};
	} else {
		$rclone_config{upload_concurrency} = '4';  # Conservative default
	}

	if ($options{chunk_size}) {
		$rclone_config{chunk_size} = $options{chunk_size};
	} else {
		$rclone_config{chunk_size} = '5Mi';  # LakeFS default
	}

	# Custom options
	if ($options{extra_config}) {
		%rclone_config = (%rclone_config, %{$options{extra_config}});
	}

	$log->debug("Generated rclone config", {
		remote_name => $remote_name,
		endpoint => $rclone_config{endpoint},
		config_keys => [keys %rclone_config]
	});

	return \%rclone_config;
}

method create_lakefs_remote ($rclone, $remote_name, %options) {
	$log->debug("Creating LakeFS remote", { remote_name => $remote_name });
	my $config = $self->generate_config($remote_name, %options);
	my $result = $rclone->add_remote($remote_name, $config);
	$log->debug("LakeFS remote created successfully", { remote_name => $remote_name });
	return $result;
}

method create_repository_remote ($rclone, $repository, $branch = 'main', %options) {
	my $remote_name = $options{remote_name} || "lakefs-$repository";

	# Create the base LakeFS remote
	$self->create_lakefs_remote($rclone, $remote_name, %options);

	# Return the full repository/branch path for easy use
	return "$remote_name:$repository/$branch";
}

method validate_credentials () {
	try {
		my ($endpoint, $access_key_id, $secret_access_key) = $self->auth->get_credentials;
		my $is_valid = defined($endpoint) && defined($access_key_id) && defined($secret_access_key);
		$log->debug("Credential validation result", {
			is_valid => $is_valid,
			has_endpoint => defined($endpoint),
			has_access_key => defined($access_key_id),
			has_secret_key => defined($secret_access_key)
		});
		return $is_valid;
	} catch ($e) {
		$log->error("Error validating credentials", { error => $e });
		return 0;
	}
}

method get_repository_url ($remote_name, $repository, $branch, $path = '') {
	my $url = "$remote_name:$repository/$branch";
	if ($path) {
		$path =~ s{^/+}{};  # Remove leading slashes
		$url .= "/$path" if $path;
	}
	$log->debug("Generated repository URL", {
		remote_name => $remote_name,
		repository => $repository,
		branch => $branch,
		path => $path,
		final_url => $url
	});
	return $url;
}

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::Common::Rclone;
	use Bio_Bricks::LakeFS::Rclone;

	my $rclone = Bio_Bricks::Common::Rclone->new();
	my $lakefs_rclone = Bio_Bricks::LakeFS::Rclone->new();

	# Create LakeFS remote
	$lakefs_rclone->create_lakefs_remote($rclone, 'lakefs');

	# Create repository-specific remote
	my $repo_url = $lakefs_rclone->create_repository_remote(
		$rclone, 'my-repo', 'main'
	);
	# Returns: 'lakefs-my-repo:my-repo/main'

	# Use for transfers
	$rclone->copy('s3:bucket/file.hdt', "$repo_url/path/file.hdt");

	# Generate config without adding to rclone
	my $config = $lakefs_rclone->generate_config('lakefs',
		upload_concurrency => 8,
		chunk_size => '10Mi'
	);

	# Get repository URLs
	my $url = $lakefs_rclone->get_repository_url(
		'lakefs', 'my-repo', 'feature-branch', 'data/files'
	);
	# Returns: 'lakefs:my-repo/feature-branch/data/files'

=head1 DESCRIPTION

This module generates rclone configuration for LakeFS using the existing
Bio_Bricks::LakeFS::Auth infrastructure. It automatically detects and uses
available LakeFS credentials from environment variables or configuration files.

The module creates S3-compatible rclone remotes that work with LakeFS's S3 gateway,
with optimizations specific to LakeFS's capabilities and limitations.

=head1 LAKEFS OPTIMIZATIONS

The generated configuration includes several LakeFS-specific optimizations:

=over 4

=item * Force path-style URLs (LakeFS requirement)

=item * Skip bucket validation to minimize API calls

=item * Conservative upload concurrency (4 by default)

=item * Appropriate chunk size (5Mi by default)

=item * Disabled checksum validation where not supported

=back

=head1 SUPPORTED OPTIONS

The generate_config and create_lakefs_remote methods support these options:

=over 4

=item * upload_concurrency - Number of concurrent uploads (default: 4)

=item * chunk_size - Upload chunk size (default: 5Mi)

=item * extra_config - Hash of additional rclone configuration options

=back

=cut
