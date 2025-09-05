package Bio_Bricks::Common::GitHub::Auth::Provider;
# ABSTRACT: Base role for GitHub authentication providers

use Bio_Bricks::Common::Setup ':role';

requires 'valid';
requires 'get_token';

has name => (
	is => 'ro',
	isa => Str,
	required => 1,
);

has source_type => (
	is => 'ro',
	isa => Str,
	required => 1,
);

1;
