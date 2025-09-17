package Bio_Bricks::Common::AWS::Auth;
# ABSTRACT: AWS authentication status using an existing Paws instance

use Bio_Bricks::Common::Setup;

has paws => (
	is => 'ro',
	isa => InstanceOf['Bio_Bricks::Common::AWS::Paws'],
	required => 1,
);

has _cached_caller_identity => (
	is => 'rw',
	isa => Maybe[HashRef],
	clearer => '_clear_cached_caller_identity',
);

method auth_method () {
	return $self->paws->auth_method;
}

method check_authentication () {
	return $self->paws->check_authentication;
}

method validate_authentication () {
	return $self->paws->validate_authentication;
}

method get_caller_identity () {
	return $self->_cached_caller_identity if $self->_cached_caller_identity;

	my $identity = $self->paws->get_caller_identity;
	$self->_cached_caller_identity($identity) if $identity;

	return $identity;
}

method get_account_id () {
	my $identity = $self->get_caller_identity;
	return $identity ? $identity->Account : undef;
}

method get_user_id () {
	my $identity = $self->get_caller_identity;
	return $identity ? $identity->UserId : undef;
}

method get_arn () {
	my $identity = $self->get_caller_identity;
	return $identity ? $identity->Arn : undef;
}

method check_auth_status () {
	my $identity = $self->get_caller_identity;
	my $has_identity = defined $identity;

	return {
		has_credentials => $self->check_authentication,
		credentials_source => $self->auth_method,
		has_caller_identity => $has_identity,
		account_id => $has_identity ? $identity->Account : undef,
		user_id => $has_identity ? $identity->UserId : undef,
		arn => $has_identity ? $identity->Arn : undef,
		region => $self->paws->region,
		env_vars_set => [
			grep { defined $ENV{$_} } qw(
				AWS_ACCESS_KEY_ID
				AWS_SECRET_ACCESS_KEY
				AWS_SESSION_TOKEN
				AWS_PROFILE
				AWS_DEFAULT_PROFILE
				AWS_REGION
				AWS_DEFAULT_REGION
			)
		],
	};
}

method clear_cache () {
	$self->_clear_cached_caller_identity;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::Common::AWS::Paws;
	use Bio_Bricks::Common::AWS::Auth;

	# Create Paws instance
	my $paws = Bio_Bricks::Common::AWS::Paws->new(region => 'us-west-2');

	# Create Auth object using the Paws instance
	my $auth = Bio_Bricks::Common::AWS::Auth->new(paws => $paws);

	# Check authentication status
	my $status = $auth->check_auth_status;
	print "Has credentials: ", $status->{has_credentials} ? 'yes' : 'no', "\n";
	print "Auth method: ", $status->{credentials_source}, "\n";
	print "Account ID: ", $status->{account_id} // 'unknown', "\n";

	# Get specific identity information
	my $account_id = $auth->get_account_id;
	my $user_id = $auth->get_user_id;
	my $arn = $auth->get_arn;

=head1 DESCRIPTION

This module provides AWS authentication status information using an existing
C<Bio_Bricks::Common::AWS::Paws> instance. It acts as a higher-level interface
for checking authentication details and obtaining caller identity information.

Unlike standalone authentication modules, this class operates on an already
configured Paws instance, allowing you to check authentication status and
get identity details after AWS services have been set up.

=head1 ATTRIBUTES

=attr paws

Required C<Bio_Bricks::Common::AWS::Paws> instance that provides the underlying
AWS authentication and service access.

=head1 METHODS

=method auth_method

	my $method = $auth->auth_method();

Returns a string describing the authentication method being used (delegated to the Paws instance).

=method check_authentication

	my $has_auth = $auth->check_authentication();

Returns true if valid credentials are available (delegated to the Paws instance).

=method validate_authentication

	my $method = $auth->validate_authentication();

Validates that credentials are available, dies with helpful error message if not
(delegated to the Paws instance).

=method get_caller_identity

	my $identity = $auth->get_caller_identity();

Returns the result of STS GetCallerIdentity API call, cached for efficiency.
Returns undef if the call fails.

=method get_account_id

	my $account_id = $auth->get_account_id();

Returns the AWS account ID from the caller identity, or undef if unavailable.

=method get_user_id

	my $user_id = $auth->get_user_id();

Returns the user ID from the caller identity, or undef if unavailable.

=method get_arn

	my $arn = $auth->get_arn();

Returns the ARN from the caller identity, or undef if unavailable.

=method check_auth_status

	my $status = $auth->check_auth_status();

Returns a comprehensive hash reference with authentication status information:

	{
		has_credentials => 1,
		credentials_source => "AWS profile: default",
		has_caller_identity => 1,
		account_id => "123456789012",
		user_id => "AIDACKCEVSQ6C2EXAMPLE",
		arn => "arn:aws:iam::123456789012:user/username",
		region => "us-east-1",
		env_vars_set => ["AWS_PROFILE", "AWS_REGION"],
	}

=method clear_cache

	$auth->clear_cache();

Clears cached caller identity information, forcing refresh on next access.

=cut
