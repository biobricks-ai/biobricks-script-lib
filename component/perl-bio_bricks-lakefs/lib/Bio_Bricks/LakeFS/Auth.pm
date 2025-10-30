package Bio_Bricks::LakeFS::Auth;
# ABSTRACT: LakeFS authentication management

use Bio_Bricks::Common::Setup;
use List::Util qw(first);
use Bio_Bricks::LakeFS::Auth::Provider::LakectlEnv;
use Bio_Bricks::LakeFS::Auth::Provider::Lakectl;
use Bio_Bricks::LakeFS::Auth::Provider::Env;
use Bio_Bricks::LakeFS::Auth::Provider::Config;

lazy providers => sub {
	[
		Bio_Bricks::LakeFS::Auth::Provider::LakectlEnv->new,
		Bio_Bricks::LakeFS::Auth::Provider::Lakectl->new,
		Bio_Bricks::LakeFS::Auth::Provider::Env->new,
		Bio_Bricks::LakeFS::Auth::Provider::Config->new,
	];
}, isa => ArrayRef[ConsumerOf['Bio_Bricks::LakeFS::Auth::Provider']];

rw _cached_credentials => (
	isa     => Maybe[ArrayRef],
	clearer => '_clear_cached_credentials',
	required => 0,
);

rw _cached_provider => (
	isa     => Maybe[ConsumerOf['Bio_Bricks::LakeFS::Auth::Provider']],
	clearer => '_clear_cached_provider',
	required => 0,
);

method get_credentials (%options) {
	# Return cached credentials if available and not forcing refresh
	return @{$self->_cached_credentials} if $self->_cached_credentials && !$options{refresh};

	my @providers = @{$self->providers};

	# Filter providers based on options
	if ($options{skip_lakectl}) {
		@providers = grep {
			!$_->isa('Bio_Bricks::LakeFS::Auth::Provider::LakectlEnv') &&
			!$_->isa('Bio_Bricks::LakeFS::Auth::Provider::Lakectl')
		} @providers;
	}
	if ($options{skip_env}) {
		@providers = grep { !$_->isa('Bio_Bricks::LakeFS::Auth::Provider::Env') } @providers;
	}
	if ($options{skip_config}) {
		@providers = grep { !$_->isa('Bio_Bricks::LakeFS::Auth::Provider::Config') } @providers;
	}

	# Find first valid provider
	my $provider = first { $_->valid } @providers;

	if ($provider) {
		my ($endpoint, $access_key_id, $secret_access_key) = $provider->get_credentials;
		if ($endpoint && $access_key_id && $secret_access_key) {
			$self->_cached_credentials([$endpoint, $access_key_id, $secret_access_key]);
			$self->_cached_provider($provider);
			return ($endpoint, $access_key_id, $secret_access_key);
		}
	}

	return;
}

method get_endpoint (%options) {
	my ($endpoint, undef, undef) = $self->get_credentials(%options);
	return $endpoint;
}

method get_access_key_id (%options) {
	my (undef, $access_key_id, undef) = $self->get_credentials(%options);
	return $access_key_id;
}

method get_secret_access_key (%options) {
	my (undef, undef, $secret_access_key) = $self->get_credentials(%options);
	return $secret_access_key;
}

method check_auth_status () {
	my ($endpoint, $access_key_id, $secret_access_key) = $self->get_credentials;
	my $provider = $self->_cached_provider;

	return {
		has_credentials => defined($endpoint) && defined($access_key_id) && defined($secret_access_key),
		credentials_source => $provider ? $provider->source_type : 'none',
		endpoint => $endpoint,
		env_vars_set => [
			grep { defined $ENV{$_} } qw(
				LAKECTL_SERVER_ENDPOINT_URL
				LAKECTL_CREDENTIALS_ACCESS_KEY_ID
				LAKECTL_CREDENTIALS_SECRET_ACCESS_KEY
				LAKEFS_ENDPOINT
				LAKEFS_ACCESS_KEY_ID
				LAKEFS_SECRET_ACCESS_KEY
			)
		],
	};
}

method clear_cache () {
	$self->_clear_cached_credentials;
	$self->_clear_cached_provider;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::LakeFS::Auth;

	my $auth = Bio_Bricks::LakeFS::Auth->new;

	# Get LakeFS credentials from environment or config
	my ($endpoint, $access_key_id, $secret_access_key) = $auth->get_credentials;

	# Get individual components
	my $endpoint = $auth->get_endpoint;
	my $access_key_id = $auth->get_access_key_id;
	my $secret_access_key = $auth->get_secret_access_key;

	# Force refresh from sources
	my @fresh_creds = $auth->get_credentials(refresh => 1);

	# Skip specific sources
	my @lakectl_only = $auth->get_credentials(skip_env => 1, skip_config => 1);
	my @env_only = $auth->get_credentials(skip_lakectl => 1, skip_config => 1);
	my @config_only = $auth->get_credentials(skip_lakectl => 1, skip_env => 1);

	# Check authentication status
	my $status = $auth->check_auth_status;
	print "Has credentials: ", $status->{has_credentials} ? 'yes' : 'no', "\n";
	print "Credentials source: ", $status->{credentials_source}, "\n";

=head1 DESCRIPTION

This module provides LakeFS authentication credential detection and management
using a pluggable provider system. It can obtain LakeFS credentials from multiple
sources in order of preference:

1. Lakectl environment variables (C<LAKECTL_SERVER_ENDPOINT_URL>, C<LAKECTL_CREDENTIALS_ACCESS_KEY_ID>, C<LAKECTL_CREDENTIALS_SECRET_ACCESS_KEY>)
2. Lakectl configuration file (~/.lakectl.yaml)
3. LakeFS environment variables (C<LAKEFS_ENDPOINT>, C<LAKEFS_ACCESS_KEY_ID>, C<LAKEFS_SECRET_ACCESS_KEY>)
4. LakeFS configuration file (~/.lakefs/config)

The module caches credentials to avoid repeated system calls and provides
methods to check authentication status and clear the cache. It prioritizes
lakectl-compatible configuration for seamless integration with existing lakectl setups.

=cut
