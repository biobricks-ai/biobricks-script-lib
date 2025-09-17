package Bio_Bricks::Common::AWS::Paws;
# ABSTRACT: Paws wrapper with automatic AWS authentication handling

use Bio_Bricks::Common::Setup;
use Paws;

ro region => isa => Maybe[Str], default => sub {
	$ENV{AWS_REGION} || $ENV{AWS_DEFAULT_REGION} || 'us-east-1'
};
ro config => isa => HashRef, default => sub { {} };

lazy _paws => method () {
	# Workaround for Paws issue #431 - copy AWS_PROFILE to AWS_DEFAULT_PROFILE
	# <https://github.com/pplu/aws-sdk-perl/issues/431>
	if ($ENV{AWS_PROFILE} && !$ENV{AWS_DEFAULT_PROFILE}) {
		$ENV{AWS_DEFAULT_PROFILE} = $ENV{AWS_PROFILE};
	}

	my %config = (
		region => $self->region,
		%{$self->config}
	);

	return Paws->new(config => \%config);
};

method service ($service_name, %args) {
	return $self->_paws->service($service_name, %args);
}

method s3 (%args) {
	return $self->service('S3', %args);
}

method sts (%args) {
	return $self->service('STS', %args);
}

method get_caller_identity () {
	eval {
		my $sts = $self->sts;
		return $sts->GetCallerIdentity;
	};
	return undef if $@;
}

method auth_method () {
	if ($ENV{AWS_ACCESS_KEY_ID} && $ENV{AWS_SECRET_ACCESS_KEY}) {
		if ($ENV{AWS_SESSION_TOKEN}) {
			return "temporary credentials (STS/assumed role)";
		} else {
			return "static credentials";
		}
	} elsif ($ENV{AWS_PROFILE} || $ENV{AWS_DEFAULT_PROFILE}) {
		return "AWS profile: @{[ $ENV{AWS_PROFILE} || $ENV{AWS_DEFAULT_PROFILE} ]}";
	} else {
		# Try to get caller identity to check if we have valid auth
		if ($self->get_caller_identity) {
			return "AWS SSO, instance profile, or credential file";
		} else {
			return "none";
		}
	}
}

method check_authentication () {
	my $method = $self->auth_method;
	return $method ne "none";
}

method validate_authentication () {
	unless ($self->check_authentication) {
		die <<~'ERROR';
		No AWS authentication configured. Use one of:
		  - `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables
		  - `AWS_PROFILE` with configured profile
		  - `aws sso login` for SSO authentication
		  - Valid AWS credential file (`~/.aws/credentials`)
		  - IAM instance profile (when running on EC2/Lambda)
		ERROR
	}

	return $self->auth_method;
}

1;
