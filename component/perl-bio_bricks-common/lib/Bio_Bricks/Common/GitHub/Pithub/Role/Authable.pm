package Bio_Bricks::Common::GitHub::Pithub::Role::Authable;
# ABSTRACT: Role to automatically inject GitHub authentication token into Pithub

use Bio_Bricks::Common::Setup ':role';

use aliased 'Bio_Bricks::Common::GitHub::Auth' => 'Auth';

has _bb_github_auth => (
	is => 'ro',
	isa => InstanceOf[Auth],
	lazy => 1,
	default => method () {
		Auth->new;
	},
);

around BUILDARGS => fun ($orig, $class, @args) {
	my $args = $class->$orig(@args);

	if (!exists $args->{token}) {
		try {
			my $auth = Auth->new;
			my $token = $auth->get_token;
			$args->{token} = $token if defined $token;
		} catch ($e) {
			# Silently continue without token if auth fails
			warn "GitHub authentication failed: $e" if $ENV{DEBUG};
		}
	}

	return $args;
};

around _create_instance => fun ($orig, $self, $class, @args) {
	my %args = @args;

	if (!exists $args{token} && $self->has_token) {
		$args{token} = $self->token;
	}

	return $self->$orig($class, %args);
};

1;
