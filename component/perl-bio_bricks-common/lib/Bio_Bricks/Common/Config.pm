package Bio_Bricks::Common::Config;
# ABSTRACT: Configuration management for BioBricks

use Bio_Bricks::Common::Setup;
use Env::Dot;
use URI::s3;

# Load .env file if it exists
method BUILD () {
	if (-f '.env') {
		eval { Env::Dot->import('.env') };
		warn "Failed to load .env file: $@" if $@ && $ENV{DEBUG};
	}
}

# ============================================================================
# AWS Configuration
# ============================================================================

lazy aws_region => sub {
	$ENV{AWS_REGION} || $ENV{AWS_DEFAULT_REGION} || 'us-east-1';
};

lazy aws_profile => sub {
	$ENV{AWS_PROFILE};
};

# ============================================================================
# S3 Configuration
# ============================================================================

lazy biobricks_s3_url => sub {
	$ENV{BIOBRICKS_S3_URL};
};

lazy s3_uri => method () {
	my $raw_url = $self->biobricks_s3_url;
	return unless $raw_url;

	# Add s3:// scheme if missing
	my $s3_url = $raw_url =~ s<^(?!s3://)><s3://>r;

	return URI::s3->new($s3_url);
};

lazy s3_bucket => method () {
	my $uri = $self->s3_uri;
	return $uri ? $uri->bucket : undef;
};

lazy s3_prefix => method () {
	my $uri = $self->s3_uri;
	return $uri ? $uri->key : '';
};

# ============================================================================
# GitHub Configuration
# ============================================================================

lazy github_token => sub {
	$ENV{GITHUB_TOKEN};
};

lazy github_api_url => sub {
	$ENV{GITHUB_API_URL} || 'https://api.github.com';
};

# ============================================================================
# BioBricks Configuration
# ============================================================================

lazy _biobricks_config => sub {
	my $home_config = path('~/.biobricks');
	return {} unless $home_config->exists;

	eval {
		my $json = $home_config->slurp_utf8;
		return decode_json($json);
	};

	warn "Failed to parse ~/.biobricks: $@" if $@ && $ENV{DEBUG};
	return {};
};

lazy biobricks_library_path => method () {
	$ENV{BIOBRICKS_LIBRARY_PATH} || $self->_biobricks_config->{BBLIB};
};

lazy biobricks_token => method () {
	$ENV{BIOBRICKS_TOKEN} || $self->_biobricks_config->{TOKEN};
};

lazy biobricks_email => method () {
	$ENV{BIOBRICKS_EMAIL} || $self->_biobricks_config->{EMAIL};
};

# ============================================================================
# Ontology API Keys
# ============================================================================

lazy bioportal_api_key => sub {
	$ENV{BIOPORTAL_API_KEY};
};

lazy ols_api_key => sub {
	$ENV{OLS_API_KEY};
};

# ============================================================================
# LakeFS Configuration
# ============================================================================

lazy lakefs_endpoint => sub {
	$ENV{LAKEFS_ENDPOINT};
};

lazy lakefs_access_key => sub {
	$ENV{LAKEFS_ACCESS_KEY_ID};
};

lazy lakefs_secret_key => sub {
	$ENV{LAKEFS_SECRET_ACCESS_KEY};
};

# ============================================================================
# Triple Store Configuration
# ============================================================================

lazy qendpoint_config_dir => sub {
	$ENV{QENDPOINT_CONFIG_DIR} || path('~/.qendpoint')->stringify;
};

lazy virtuoso_db_path => sub {
	$ENV{DB_VIRTUOSO_PATH};
};

lazy neptune_endpoint => sub {
	$ENV{NEPTUNE_ENDPOINT};
};

# ============================================================================
# Development/Testing
# ============================================================================

lazy debug => sub {
	$ENV{DEBUG} ? 1 : 0;
};

lazy test_mode => sub {
	$ENV{TEST_MODE} ? 1 : 0;
};

lazy cache_dir => sub {
	$ENV{CACHE_DIR} || path('~/.biobricks/cache')->stringify;
};

# ============================================================================
# Validation Methods
# ============================================================================

method validate_s3_config () {
	unless ($self->biobricks_s3_url) {
		die <<~'ERROR';
		BIOBRICKS_S3_URL environment variable not set.

		Set it to your S3 bucket name or full S3 URL:
		  export BIOBRICKS_S3_URL=my-bucket
		  export BIOBRICKS_S3_URL=s3://my-bucket/prefix
		ERROR
	}

	unless ($self->s3_uri) {
		die "Failed to parse S3 URL: " . $self->biobricks_s3_url;
	}

	return 1;
}

method validate_github_config () {
	unless ($self->github_token) {
		warn <<~'WARNING';
		GITHUB_TOKEN not set. API rate limits will be lower.

		To get a token:
		  1. Go to https://github.com/settings/tokens
		  2. Generate a new token with 'repo' or 'public_repo' scope
		  3. export GITHUB_TOKEN=ghp_your_token_here
		WARNING
	}

	return 1;
}

method validate_bioportal_config () {
	unless ($self->bioportal_api_key) {
		die <<~'ERROR';
		BIOPORTAL_API_KEY not set.

		To get an API key:
		  1. Go to https://www.bioontology.org/wiki/BioPortal_Help#Getting_an_API_key
		  2. Sign up/log in to BioPortal
		  3. export BIOPORTAL_API_KEY=your_api_key
		ERROR
	}

	return 1;
}

# ============================================================================
# Summary Method
# ============================================================================

method summary () {
	my @lines;

	push @lines, "=== BioBricks Configuration ===";
	push @lines, "";

	# AWS
	push @lines, "AWS:";
	push @lines, "  Region: " . $self->aws_region;
	push @lines, "  Profile: " . ($self->aws_profile || "(not set)");
	push @lines, "";

	# S3
	push @lines, "S3:";
	push @lines, "  URL: " . ($self->biobricks_s3_url || "(not set)");
	if ($self->s3_uri) {
		push @lines, "  Bucket: " . $self->s3_bucket;
		push @lines, "  Prefix: " . ($self->s3_prefix || "(root)");
	}
	push @lines, "";

	# GitHub
	push @lines, "GitHub:";
	push @lines, "  Token: " . ($self->github_token ? "(set)" : "(not set)");
	push @lines, "  API URL: " . $self->github_api_url;
	push @lines, "";

	# BioBricks
	push @lines, "BioBricks:";
	push @lines, "  Library: " . ($self->biobricks_library_path || "(not set)");
	push @lines, "  Token: " . ($self->biobricks_token ? "(set)" : "(not set)");
	push @lines, "  Email: " . ($self->biobricks_email || "(not set)");
	push @lines, "";

	# Development
	push @lines, "Development:";
	push @lines, "  Debug: " . ($self->debug ? "enabled" : "disabled");
	push @lines, "  Test Mode: " . ($self->test_mode ? "enabled" : "disabled");
	push @lines, "  Cache Dir: " . $self->cache_dir;

	return join("\n", @lines);
}

1;
