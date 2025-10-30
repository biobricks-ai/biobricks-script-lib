package Bio_Bricks::LakeFS::Auth::Provider::Config;
# ABSTRACT: LakeFS authentication provider from configuration file

use Bio_Bricks::Common::Setup;
use YAML::XS;
use File::HomeDir;

with 'Bio_Bricks::LakeFS::Auth::Provider';

ro '+name' => (
	default => 'Configuration File',
);

ro '+source_type' => (
	default => 'config',
);

lazy config_path => method () {
	my $home = File::HomeDir->my_home;
	return path($home, '.lakefs', 'config')->stringify;
}, isa => Str;

lazy _config => method () {
	my $config_file = path($self->config_path);
	return unless $config_file->exists;

	try {
		my $config = YAML::XS::LoadFile($config_file->stringify);

		# Support both single config and multiple profiles
		if (exists $config->{endpoint} && exists $config->{access_key_id} && exists $config->{secret_access_key}) {
			return [$config->{endpoint}, $config->{access_key_id}, $config->{secret_access_key}];
		} elsif (exists $config->{default}) {
			my $default = $config->{default};
			if (exists $default->{endpoint} && exists $default->{access_key_id} && exists $default->{secret_access_key}) {
				return [$default->{endpoint}, $default->{access_key_id}, $default->{secret_access_key}];
			}
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

	use Bio_Bricks::LakeFS::Auth::Provider::Config;

	my $provider = Bio_Bricks::LakeFS::Auth::Provider::Config->new;

	# Or with custom config path
	my $provider = Bio_Bricks::LakeFS::Auth::Provider::Config->new(
		config_path => '/path/to/lakefs/config'
	);

	if ($provider->valid) {
		my ($endpoint, $access_key_id, $secret_access_key) = $provider->get_credentials;
	}

=head1 DESCRIPTION

This provider retrieves LakeFS authentication credentials from a configuration file.
By default, it looks for C<~/.lakefs/config>.

The configuration file should be in YAML format:

	# Simple format
	endpoint: https://lakefs.example.com
	access_key_id: AKIAIOSFODNN7EXAMPLE
	secret_access_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

	# Or with profiles
	default:
	  endpoint: https://lakefs.example.com
	  access_key_id: AKIAIOSFODNN7EXAMPLE
	  secret_access_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

=cut
