package Bio_Bricks::LakeFS::Auth::Provider::Lakectl;
# ABSTRACT: LakeFS authentication provider from lakectl configuration

use Bio_Bricks::Common::Setup;
use YAML::XS;
use File::HomeDir;

with 'Bio_Bricks::LakeFS::Auth::Provider';

ro '+name' => (
	default => 'Lakectl Configuration',
);

ro '+source_type' => (
	default => 'lakectl',
);

lazy config_path => method () {
	my $home = File::HomeDir->my_home;
	return path($home, '.lakectl.yaml')->stringify;
}, isa => Str;

lazy _config => method () {
	my $config_file = path($self->config_path);
	return unless $config_file->exists;

	try {
		my $config = YAML::XS::LoadFile($config_file->stringify);

		# lakectl config structure:
		# credentials:
		#   access_key_id: AKIA...
		#   secret_access_key: secret...
		# server:
		#   endpoint_url: https://lakefs.example.com

		my $credentials = $config->{credentials} || {};
		my $server = $config->{server} || {};

		if ($credentials->{access_key_id} &&
			$credentials->{secret_access_key} &&
			$server->{endpoint_url}) {

			return [
				$server->{endpoint_url},
				$credentials->{access_key_id},
				$credentials->{secret_access_key}
			];
		}
	} catch ($e) {
		# Silently fail - config file might be malformed
		return;
	}

	return;
}, isa => Maybe[ArrayRef];

method valid () {
	return defined $self->_config;
}

method get_credentials () {
	return unless $self->valid;
	return @{$self->_config};
}

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::LakeFS::Auth::Provider::Lakectl;

	my $provider = Bio_Bricks::LakeFS::Auth::Provider::Lakectl->new;

	# Or with custom config path
	my $provider = Bio_Bricks::LakeFS::Auth::Provider::Lakectl->new(
		config_path => '/path/to/lakectl.yaml'
	);

	if ($provider->valid) {
		my ($endpoint, $access_key_id, $secret_access_key) = $provider->get_credentials;
	}

=head1 DESCRIPTION

This provider retrieves LakeFS authentication credentials from a lakectl
configuration file. By default, it looks for C<~/.lakectl.yaml>.

The configuration file should be in YAML format following lakectl's structure:

	credentials:
	  access_key_id: AKIA...
	  secret_access_key: secret...
	server:
	  endpoint_url: https://lakefs.example.com

This provider is designed to work with lakectl's native configuration format,
making it compatible with existing lakectl setups.

=cut
