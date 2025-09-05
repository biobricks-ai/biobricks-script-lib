package Bio_Bricks::Common::GitHub::Auth;
# ABSTRACT: GitHub authentication token detection and management

use Bio_Bricks::Common::Setup;

use Bio_Bricks::Common::GitHub::Auth::Provider::Env;
use Bio_Bricks::Common::GitHub::Auth::Provider::GhCLI;

use Types::Standard qw(Str Maybe ArrayRef ConsumerOf);
use Carp qw(croak);
use List::Util qw(first);
use IPC::Run3;

has providers => (
	is => 'ro',
	isa => ArrayRef[ConsumerOf['Bio_Bricks::Common::GitHub::Auth::Provider']],
	lazy => 1,
	builder => '_build_providers',
);

has _cached_token => (
	is      => 'rw',
	isa     => Maybe[Str],
	clearer => '_clear_cached_token',
);

has _cached_provider => (
	is      => 'rw',
	isa     => Maybe[ConsumerOf['Bio_Bricks::Common::GitHub::Auth::Provider']],
	clearer => '_clear_cached_provider',
);

method _build_providers () {
	return [
		Bio_Bricks::Common::GitHub::Auth::Provider::Env->new(env_var => 'GITHUB_TOKEN'),
		Bio_Bricks::Common::GitHub::Auth::Provider::Env->new(env_var => 'GH_TOKEN'),
		Bio_Bricks::Common::GitHub::Auth::Provider::Env->new(env_var => 'GITHUB_ACCESS_TOKEN'),
		Bio_Bricks::Common::GitHub::Auth::Provider::GhCLI->new,
	];
}

method get_token (%options) {
	# Return cached token if available and not forcing refresh
	return $self->_cached_token if $self->_cached_token && !$options{refresh};

	my @providers = @{$self->providers};

	# Filter providers based on options
	if ($options{skip_env}) {
		@providers = grep { !$_->isa('Bio_Bricks::Common::GitHub::Auth::Provider::Env') } @providers;
	}
	if ($options{skip_gh_cli}) {
		@providers = grep { !$_->isa('Bio_Bricks::Common::GitHub::Auth::Provider::GhCLI') } @providers;
	}

	# Find first valid provider
	my $provider = first { $_->valid } @providers;

	if ($provider) {
		my $token = $provider->get_token;
		if ($token) {
			$self->_cached_token($token);
			$self->_cached_provider($provider);
			return $token;
		}
	}

	return;
}

method check_auth_status () {
	my $token = $self->get_token;
	my $provider = $self->_cached_provider;

	return {
		has_token => defined $token,
		token_source => $provider ? $provider->source_type : 'none',
		has_gh_cli => $self->_has_gh_cli,
		env_vars_set => [
			grep { defined $ENV{$_} } qw(GITHUB_TOKEN GH_TOKEN GITHUB_ACCESS_TOKEN)
		],
	};
}

method _has_gh_cli () {
	my $gh_provider = first { $_->isa('Bio_Bricks::Common::GitHub::Auth::Provider::GhCLI') } @{$self->providers};
	return $gh_provider ? $gh_provider->valid : 0;
}

method clear_cache () {
	$self->_clear_cached_token;
	$self->_clear_cached_provider;
}

# Compatibility methods for existing tests
method _get_token_from_env () {
	my @env_providers = grep { $_->isa('Bio_Bricks::Common::GitHub::Auth::Provider::Env') } @{$self->providers};
	my $provider = first { $_->valid } @env_providers;
	return $provider ? $provider->get_token : undef;
}

method _get_token_from_gh_cli () {
	my $gh_provider = first { $_->isa('Bio_Bricks::Common::GitHub::Auth::Provider::GhCLI') } @{$self->providers};
	return $gh_provider ? $gh_provider->get_token : undef;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::Common::GitHub::Auth;

	my $auth = Bio_Bricks::Common::GitHub::Auth->new;

	# Get GitHub token from environment or gh CLI
	my $token = $auth->get_token;

	# Force refresh from sources
	my $fresh_token = $auth->get_token(refresh => 1);

	# Skip specific sources
	my $env_only = $auth->get_token(skip_gh_cli => 1);
	my $cli_only = $auth->get_token(skip_env => 1);

	# Check authentication status
	my $status = $auth->check_auth_status;
	print "Has token: ", $status->{has_token} ? 'yes' : 'no', "\n";
	print "Token source: ", $status->{token_source}, "\n";

	# Use custom providers
	my $auth = Bio_Bricks::Common::GitHub::Auth->new(
		providers => [
			Bio_Bricks::Common::GitHub::Auth::Provider::Env->new(env_var => 'MY_TOKEN'),
			Bio_Bricks::Common::GitHub::Auth::Provider::GhCLI->new,
		]
	);

=head1 DESCRIPTION

This module provides GitHub authentication token detection and management
using a pluggable provider system. It can obtain GitHub tokens from multiple
sources in order of preference:

1. Environment variables (C<GITHUB_TOKEN>, C<GH_TOKEN>, C<GITHUB_ACCESS_TOKEN>)
2. GitHub CLI (C<gh auth token>)

The module caches tokens to avoid repeated system calls and provides
methods to check authentication status and clear the cache.

=attr providers

Array reference of authentication providers. By default includes environment
variable providers for C<GITHUB_TOKEN>, C<GH_TOKEN>, C<GITHUB_ACCESS_TOKEN>, and
the GitHub CLI provider.

=attr _cached_token

Internal cached token storage (private).

=method get_token

	my $token = $auth->get_token(%options);

Retrieves a GitHub authentication token from available sources.

Options:
- C<refresh>: Force refresh from sources, ignoring cache
- C<skip_env>: Skip environment variable detection
- C<skip_gh_cli>: Skip GitHub CLI detection

=method check_auth_status

	my $status = $auth->check_auth_status;

Returns a hash reference with authentication status information:
- C<has_token>: Boolean indicating if a token is available
- C<token_source>: Source of the token (provider name or 'none')
- C<has_gh_cli>: Boolean indicating if GitHub CLI is available
- C<env_vars_set>: Array of environment variables that are set

=method clear_cache

	$auth->clear_cache;

Clears the cached token and provider, forcing the next call to C<get_token>
to refresh from sources.

=cut
