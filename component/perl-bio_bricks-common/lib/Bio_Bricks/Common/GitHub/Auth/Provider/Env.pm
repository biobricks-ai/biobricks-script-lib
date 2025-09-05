package Bio_Bricks::Common::GitHub::Auth::Provider::Env;
# ABSTRACT: Environment variable provider for GitHub authentication

use Bio_Bricks::Common::Setup;

with 'Bio_Bricks::Common::GitHub::Auth::Provider';

has '+source_type' => (
	default => 'environment',
);

has env_var => (
	is => 'ro',
	isa => Str,
	required => 1,
);

has '+name' => (
	lazy => 1,
	default => method () { 'environment:' . $self->env_var },
);

method valid () {
	return defined $ENV{$self->env_var};
}

method get_token () {
	return $ENV{$self->env_var};
}

1;
