package Bio_Bricks::Common::AWS::Rclone;
# ABSTRACT: AWS S3 rclone configuration generator

use Bio_Bricks::Common::Setup;
use Bio_Bricks::Common::AWS::Paws;
use Bio_Bricks::Common::AWS::Auth;
use Bio_Bricks::Common::Config;

has aws_paws => (
	is => 'ro',
	isa => InstanceOf['Bio_Bricks::Common::AWS::Paws'],
	lazy => 1,
	builder => '_build_aws_paws',
);

has aws_auth => (
	is => 'ro',
	isa => InstanceOf['Bio_Bricks::Common::AWS::Auth'],
	lazy => 1,
	builder => '_build_aws_auth',
);

has config => (
	is => 'ro',
	isa => InstanceOf['Bio_Bricks::Common::Config'],
	lazy => 1,
	builder => '_build_config',
);

has region => (
	is => 'ro',
	isa => Maybe[Str],
	lazy => 1,
	builder => '_build_region',
);

has provider => (
	is => 'ro',
	isa => Str,
	default => 'AWS',
);

method _build_aws_paws () {
	return Bio_Bricks::Common::AWS::Paws->new(
		region => $self->region
	);
}

method _build_aws_auth () {
	return Bio_Bricks::Common::AWS::Auth->new(
		paws => $self->aws_paws
	);
}

method _build_config () {
	return Bio_Bricks::Common::Config->new;
}

method _build_region () {
	return $self->config->aws_region;
}

method generate_config ($remote_name, %options) {
	# Validate authentication first
	unless ($self->aws_auth->check_authentication) {
		croak "No AWS credentials available. Please configure AWS credentials.";
	}

	my %rclone_config = (
		type => 's3',
		provider => $self->provider,
		region => $self->region,
	);

	# For rclone S3, we can rely on AWS credential chain detection
	# Rclone will automatically pick up credentials from:
	# - Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN)
	# - AWS credentials file (~/.aws/credentials)
	# - IAM roles (EC2 instance profiles, ECS task roles, etc.)
	#
	# This is safer than extracting credentials and passing them explicitly,
	# as it preserves the credential chain and supports all AWS auth methods

	# Only add explicit credentials for non-standard auth methods if needed
	# Most cases should work with rclone's built-in AWS credential detection

	# Add additional S3 options
	if ($options{endpoint}) {
		$rclone_config{endpoint} = $options{endpoint};
		$rclone_config{provider} = 'Other';
	}

	if ($options{force_path_style}) {
		$rclone_config{force_path_style} = 'true';
	}

	if ($options{no_check_bucket}) {
		$rclone_config{no_check_bucket} = 'true';
	}

	# Server-side encryption options
	if ($options{server_side_encryption}) {
		$rclone_config{server_side_encryption} = $options{server_side_encryption};
	}

	if ($options{sse_kms_key_id}) {
		$rclone_config{sse_kms_key_id} = $options{sse_kms_key_id};
	}

	# Storage class
	if ($options{storage_class}) {
		$rclone_config{storage_class} = $options{storage_class};
	}

	# Custom options
	if ($options{extra_config}) {
		%rclone_config = (%rclone_config, %{$options{extra_config}});
	}

	return \%rclone_config;
}

method create_s3_remote ($rclone, $remote_name, %options) {
	my $config = $self->generate_config($remote_name, %options);
	return $rclone->add_remote($remote_name, $config);
}

method create_biobricks_s3_remote ($rclone, $remote_name = 'biobricks-s3') {
	# Use BioBricks S3 configuration
	my $s3_uri = $self->config->s3_uri;
	my $bucket = $self->config->s3_bucket;

	unless ($s3_uri || $bucket) {
		croak "BioBricks S3 configuration not found. Please set BIOBRICKS_S3_URI.";
	}

	my %options = (
		no_check_bucket => 1,  # Don't validate bucket on startup
	);

	# Parse S3 URI for custom endpoint if needed
	if ($s3_uri && $s3_uri =~ m{^s3://([^/]+)(.*)$}) {
		my $host = $1;
		# If it's not standard S3, it might be a custom endpoint
		if ($host !~ /^[^.]+\.s3[.-]/) {
			$options{endpoint} = "https://$host";
			$options{force_path_style} = 1;
		}
	}

	return $self->create_s3_remote($rclone, $remote_name, %options);
}

method validate_credentials () {
	return $self->aws_auth->check_authentication;
}

method get_auth_status () {
	return $self->aws_auth->check_auth_status;
}

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::Common::Rclone;
	use Bio_Bricks::Common::AWS::Rclone;

	my $rclone = Bio_Bricks::Common::Rclone->new();
	my $aws_rclone = Bio_Bricks::Common::AWS::Rclone->new();

	# Create standard AWS S3 remote
	$aws_rclone->create_s3_remote($rclone, 'aws-s3');

	# Create BioBricks S3 remote (uses BIOBRICKS_S3_URI)
	$aws_rclone->create_biobricks_s3_remote($rclone, 'biobricks-s3');

	# Create custom S3-compatible remote
	$aws_rclone->create_s3_remote($rclone, 'minio',
		endpoint => 'https://minio.example.com',
		force_path_style => 1,
		no_check_bucket => 1
	);

	# Generate config without adding to rclone
	my $config = $aws_rclone->generate_config('my-s3',
		storage_class => 'STANDARD_IA',
		server_side_encryption => 'AES256'
	);

=head1 DESCRIPTION

This module generates rclone configuration for AWS S3 and S3-compatible services
using the existing BioBricks AWS authentication infrastructure. It automatically
detects and uses available AWS credentials from environment variables, AWS profiles,
or IAM roles.

The module integrates with Bio_Bricks::Common::Config to automatically configure
BioBricks S3 access using the BIOBRICKS_S3_URI setting.

=head1 SUPPORTED OPTIONS

The generate_config and create_s3_remote methods support these options:

=over 4

=item * endpoint - Custom S3 endpoint URL

=item * force_path_style - Use path-style URLs instead of virtual-hosted style

=item * no_check_bucket - Skip bucket validation on startup

=item * server_side_encryption - Server-side encryption method (AES256, aws:kms)

=item * sse_kms_key_id - KMS key ID for server-side encryption

=item * storage_class - S3 storage class (STANDARD, STANDARD_IA, GLACIER, etc.)

=item * extra_config - Hash of additional rclone configuration options

=back

=cut
