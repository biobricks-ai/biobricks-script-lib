package Bio_Bricks::Common::GitHub::Auth;
# ABSTRACT: GitHub authentication token detection and management

use Bio_Bricks::Common::Setup;

use Types::Standard qw(Str Maybe);
use Carp qw(croak);
use List::Util qw(first);
use IPC::Run3;

has _cached_token => (
	is      => 'rw',
	isa     => Maybe[Str],
	clearer => '_clear_cached_token',
);

method get_token (%options) {
	# Return cached token if available and not forcing refresh
	return $self->_cached_token if $self->_cached_token && !$options{refresh};

	my $token;

	# Try methods in order of preference
	if (!$options{skip_env}) {
		$token = $self->_get_token_from_env();
	}

	if (!$token && !$options{skip_gh_cli}) {
		$token = $self->_get_token_from_gh_cli();
	}

	# Cache the token if found
	$self->_cached_token($token) if $token;

	return $token;
}

method _get_token_from_env () {
	# Check common environment variable names
	return $ENV{GITHUB_TOKEN} || $ENV{GH_TOKEN} || $ENV{GITHUB_ACCESS_TOKEN};
}

method _get_token_from_gh_cli () {
	# Check if gh CLI is available
	return unless $self->_has_gh_cli();

	# Try to get token from gh auth token
	my ($stdout, $stderr, $exit_code);

	try {
		IPC::Run3::run3(['gh', 'auth', 'token'], \undef, \$stdout, \$stderr);
		$exit_code = $? >> 8;
	}
	catch ($e) {
		# gh CLI failed, might not be authenticated
		return;
	}

	return if $exit_code && $exit_code != 0;

	# Clean up the token (remove whitespace)
	if ($stdout) {
		chomp $stdout;
		$stdout =~ s/^\s+|\s+$//g;
		return $stdout if $stdout && $stdout =~ /^[a-zA-Z0-9_]+$/;
	}

	return;
}

method _has_gh_cli () {
	# Check if gh command is available
	my ($stdout, $stderr, $exit_code);

	try {
		IPC::Run3::run3(['which', 'gh'], \undef, \$stdout, \$stderr);
		$exit_code = $? >> 8;
	}
	catch ($e) {
		return 0;
	}

	return $exit_code == 0;
}

method check_auth_status () {
	my $token = $self->get_token();

	return {
		has_token => defined $token,
		token_source => $self->_get_token_source(),
		has_gh_cli => $self->_has_gh_cli(),
		env_vars_set => [
			grep { defined $ENV{$_} } qw(GITHUB_TOKEN GH_TOKEN GITHUB_ACCESS_TOKEN)
		],
	};
}

method _get_token_source () {
	if ($self->_get_token_from_env()) {
		return 'environment';
	} elsif ($self->_get_token_from_gh_cli()) {
		return 'gh_cli';
	} else {
		return 'none';
	}
}

method clear_cache () {
	$self->_clear_cached_token();
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::Common::GitHub::Auth;

	my $auth = Bio_Bricks::Common::GitHub::Auth->new();

	# Get GitHub token from environment or gh CLI
	my $token = $auth->get_token();

	# Force refresh from sources
	my $fresh_token = $auth->get_token(refresh => 1);

	# Skip specific sources
	my $env_only = $auth->get_token(skip_gh_cli => 1);
	my $cli_only = $auth->get_token(skip_env => 1);

	# Check authentication status
	my $status = $auth->check_auth_status();
	print "Has token: ", $status->{has_token} ? 'yes' : 'no', "\n";
	print "Token source: ", $status->{token_source}, "\n";

=head1 DESCRIPTION

This module provides GitHub authentication token detection and management.
It can obtain GitHub tokens from multiple sources in order of preference:

1. Environment variables (GITHUB_TOKEN, GH_TOKEN, GITHUB_ACCESS_TOKEN)
2. GitHub CLI (`gh auth token`)

The module caches tokens to avoid repeated system calls and provides
methods to check authentication status and clear the cache.

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

	my $status = $auth->check_auth_status();

Returns a hash reference with authentication status information:
- C<has_token>: Boolean indicating if a token is available
- C<token_source>: Source of the token ('environment', 'gh_cli', or 'none')
- C<has_gh_cli>: Boolean indicating if GitHub CLI is available
- C<env_vars_set>: Array of environment variables that are set

=method clear_cache

	$auth->clear_cache();

Clears the cached token, forcing the next call to C<get_token> to
refresh from sources.

=cut
