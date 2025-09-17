package Bio_Bricks::Common::Rclone;
# ABSTRACT: Rclone configuration manager and command runner

use Bio_Bricks::Common::Setup;
use IPC::Run3;
use File::HomeDir;
use File::Which qw(which);
use Bio_Bricks::Common::Rclone::Config;
use Bio_Bricks::Common::Rclone::Runner;

has config => (
	is => 'ro',
	isa => InstanceOf['Bio_Bricks::Common::Rclone::Config'],
	lazy => 1,
	builder => '_build_config',
);

has runner => (
	is => 'ro',
	isa => InstanceOf['Bio_Bricks::Common::Rclone::Runner'],
	lazy => 1,
	builder => '_build_runner',
);

has _temp_dir => (
	is => 'ro',
	lazy => 1,
	builder => '_build_temp_dir',
);

has config_dir => (
	is => 'ro',
	isa => Str,
	lazy => 1,
	builder => '_build_config_dir',
);

has rclone_path => (
	is => 'ro',
	isa => Str,
	lazy => 1,
	builder => '_find_rclone',
);

has verbose => (
	is => 'ro',
	isa => Bool,
	default => 0,
);

method _build_temp_dir () {
	# Create and keep reference to temporary directory
	return Path::Tiny->tempdir('biobricks-rclone-XXXXXX');
}

method _build_config_dir () {
	# Return stringified path while keeping temp_dir object alive
	return $self->_temp_dir->stringify;
}

method _find_rclone () {
	# Check if rclone is in PATH
	my $path = which('rclone');
	return $path if defined $path;

	# Check common installation locations
	my @common_paths = (
		'/usr/local/bin/rclone',
		'/usr/bin/rclone',
		'/opt/rclone/rclone',
		path($ENV{HOME}, '.local', 'bin', 'rclone')->stringify,
	);

	for my $path (@common_paths) {
		return $path if -x $path;
	}

	croak "rclone not found in PATH or common locations. Please install rclone.";
}

method _build_config () {
	return Bio_Bricks::Common::Rclone::Config->new(
		config_dir => $self->config_dir,
		verbose => $self->verbose,
	);
}

method _build_runner () {
	return Bio_Bricks::Common::Rclone::Runner->new(
		rclone_path => $self->rclone_path,
		config_dir => $self->config_dir,
		verbose => $self->verbose,
	);
}

# Convenience methods that delegate to runner
method sync ($source, $destination, %options) {
	return $self->runner->sync($source, $destination, %options);
}

method copy ($source, $destination, %options) {
	return $self->runner->copy($source, $destination, %options);
}

method copyto ($source, $destination, %options) {
	return $self->runner->copyto($source, $destination, %options);
}

method move ($source, $destination, %options) {
	return $self->runner->move($source, $destination, %options);
}

method moveto ($source, $destination, %options) {
	return $self->runner->moveto($source, $destination, %options);
}

method list ($remote, %options) {
	return $self->runner->list($remote, %options);
}

method size ($remote, %options) {
	return $self->runner->size($remote, %options);
}

method check ($source, $destination, %options) {
	return $self->runner->check($source, $destination, %options);
}

# Convenience methods that delegate to config
method add_remote ($name, $config) {
	return $self->config->add_remote($name, $config);
}

method remove_remote ($name) {
	return $self->config->remove_remote($name);
}

method list_remotes () {
	return $self->config->list_remotes();
}

method get_remote ($name) {
	return $self->config->get_remote($name);
}

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::Common::Rclone;

	# Create rclone manager
	my $rclone = Bio_Bricks::Common::Rclone->new();

	# Add remotes
	$rclone->add_remote('s3source', {
		type => 's3',
		provider => 'AWS',
		access_key_id => 'AKIA...',
		secret_access_key => 'secret...',
		region => 'us-east-1',
	});

	$rclone->add_remote('lakefs', {
		type => 's3',
		provider => 'Other',
		endpoint => 'https://lakefs.example.com',
		access_key_id => 'AKIA...',
		secret_access_key => 'secret...',
		no_check_bucket => 'true',
	});

	# Direct S3 to LakeFS transfer
	$rclone->sync(
		's3source:bucket/path/file.hdt',
		'lakefs:repo/branch/path/file.hdt'
	);

	# List remotes
	my @remotes = $rclone->list_remotes();
	print "Available remotes: " . join(', ', @remotes) . "\n";

=head1 DESCRIPTION

This module provides a high-level interface to rclone for managing cloud storage
transfers. It handles configuration file management and command execution,
making it easy to set up and use rclone remotes programmatically.

The module is designed to work with the BioBricks authentication system,
allowing automatic configuration of S3 and LakeFS remotes using existing
credential providers.

=head1 ARCHITECTURE

The module is split into several components:

=over 4

=item * L<Bio_Bricks::Common::Rclone::Config> - Configuration file management

=item * L<Bio_Bricks::Common::Rclone::Runner> - Command execution wrapper

=item * L<Bio_Bricks::Common::AWS::Rclone> - S3 remote configuration generator

=item * L<Bio_Bricks::LakeFS::Rclone> - LakeFS remote configuration generator

=back

=cut
