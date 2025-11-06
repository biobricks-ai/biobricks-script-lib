package Bio_Bricks::Store::Neptune;
# ABSTRACT: AWS Neptune graph database interface

use Bio_Bricks::Common::Setup;
use LWP::UserAgent;
use URI;
use Bio_Bricks::Common::Config;
use MooX::Log::Any;
use IO::Socket::SSL qw(SSL_VERIFY_NONE);
use Types::Standard qw(Enum);
use Types::Common::Numeric qw(PositiveInt);

# Define types for Neptune API parameters with coercion
use kura NeptuneBoolParam => (Enum[qw(true false)])->plus_coercions(
	Bool, sub { $_ ? 'true' : 'false' },
);

with qw(MooX::Log::Any);

=head1 NAME

Bio_Bricks::Store::Neptune - AWS Neptune graph database interface

=head1 SYNOPSIS

	use Bio_Bricks::Store::Neptune;

	# Direct connection to Neptune
	my $neptune = Bio_Bricks::Store::Neptune->new(
		endpoint => 'my-neptune-cluster.amazonaws.com',
		port     => 8182,
		region   => 'us-east-1',
	);

	# Connection through localhost tunnel (SSM/SSH port forwarding)
	my $neptune = Bio_Bricks::Store::Neptune->new(
		endpoint   => 'localhost',
		port       => 8182,
		ssl_verify => 0,  # Disable SSL verification
	);

	# Check cluster status
	my $status = $neptune->get_status();

	# Get loader status
	my $loader = $neptune->get_loader_status();

=head1 DESCRIPTION

This module provides an interface to AWS Neptune graph database,
including bulk loading and status monitoring capabilities.

=cut

# Configuration - can be injected for testing
ro config => (
	isa => InstanceOf['Bio_Bricks::Common::Config'],
	default => sub { Bio_Bricks::Common::Config->new },
);

# Neptune cluster endpoint
lazy endpoint => method() {
	return $self->config->neptune_endpoint
		|| croak "Neptune endpoint not configured. Set NEPTUNE_ENDPOINT environment variable.";
};

# Neptune port
ro port => (
	isa => Int,
	default => 8182,
);

# AWS region
lazy region => method() {
	$self->config->aws_region;
};

# Use HTTPS
ro use_https => (
	isa => Bool,
	default => 1,
);

# Verify SSL certificates and hostname (default: true)
# Set to false to disable all SSL verification when using localhost tunnels
# (e.g., SSH/SSM port forwarding)
ro ssl_verify => (
	isa => Bool,
	default => 1,
);

=attr base_url

Returns the base URL for Neptune API requests as a URI object.

=cut

lazy base_url => method() {
	my $protocol = $self->use_https ? 'https' : 'http';
	return URI->new("$protocol://" . $self->endpoint . ":" . $self->port);
}, isa => InstanceOf['URI'];

=attr sparql_url

Returns the URL for the Neptune SPARQL endpoint as a URI object.

=cut

lazy sparql_url => method() {
	my $uri = $self->base_url->clone;
	$uri->path('/sparql');
	return $uri;
}, isa => InstanceOf['URI'];

# HTTP timeout in seconds
ro timeout => (
	isa => Int,
	default => 30,
);

# HTTP user agent - can be injected for testing
lazy ua => '_build_ua';

method _build_ua() {
	my $ua = LWP::UserAgent->new(
		timeout => $self->timeout,
		agent => 'Bio_Bricks::Store::Neptune/' . ($Bio_Bricks::Store::Neptune::VERSION // 'dev'),
	);

	# Disable SSL certificate and hostname verification if requested (for localhost tunnels)
	unless ($self->ssl_verify) {
		$ua->ssl_opts(
			verify_hostname => 0,              # Disable hostname verification
			SSL_verify_mode => SSL_VERIFY_NONE, # Disable certificate verification
		);
		$self->log->warn("SSL certificate and hostname verification disabled - only use with localhost tunnels!");
	}

	$self->log->debug("Created HTTP client with timeout: " . $self->timeout);
	return $ua;
}

=head1 METHODS

=method loader_url

Returns the URL for the Neptune bulk loader endpoint as a URI object.
Optionally takes a load_id parameter to query a specific load job.

=cut

method loader_url(Maybe[Str] $load_id = undef) {
	my $uri = $self->base_url->clone;
	$uri->path('/loader');
	$uri->query_form(loadId => $load_id) if defined $load_id;
	return $uri;
}

=method get_loader_status

Get the status of the bulk loader or a specific load job.

	my $status = $neptune->get_loader_status();        # Overall status
	my $status = $neptune->get_loader_status($load_id); # Specific job
	my $status = $neptune->get_loader_status($load_id, {
		details => 1,
		errors => 1,
		errorsPerPage => 100,
	});

Optional parameters:
- details: Include extended information (boolean)
- errors: Include list of errors (boolean)
- page: Error result page number (integer)
- errorsPerPage: Number of errors per page (integer, default 10)

=cut

method get_loader_status(Maybe[Str] $load_id = undef, Maybe[HashRef] $params = undef) {
	my $url = $self->loader_url($load_id);

	# Add additional query parameters if provided
	if ($params && %$params) {
		my $uri = URI->new($url);
		my %existing_params = $uri->query_form;

		# Define parameter types for Neptune loader API
		my %param_types = (
			details       => NeptuneBoolParam,
			errors        => NeptuneBoolParam,
			page          => PositiveInt,
			errorsPerPage => PositiveInt,
		);

		# Filter out undefined values and coerce to appropriate types
		my %query_params;
		for my $key (keys %$params) {
			next unless defined $params->{$key};
			my $value = $params->{$key};

			# Apply type coercion if parameter has a defined type
			if (exists $param_types{$key} && $param_types{$key}->has_coercion) {
				my $type = $param_types{$key};
				$query_params{$key} = $type->coerce($value);
			} else {
				# Pass through unknown parameters as-is (integers, strings, etc.)
				$query_params{$key} = $value;
			}
		}

		$uri->query_form(%existing_params, %query_params) if %query_params;
		$url = $uri->as_string;
	}

	$self->log->debug("Getting loader status from: $url");

	my $response = $self->ua->get($url);

	unless ($response->is_success) {
		my $error = "Failed to get loader status: " . $response->status_line;
		$self->log->error($error);
		croak $error;
	}

	my $data = do {
		try {
			decode_json($response->content);
		} catch ($e) {
			my $error = "Failed to parse loader response: $e";
			$self->log->error($error);
			croak $error;
		}
	};

	return $data;
}

=method get_queue_status

Get the current queue status including running and queued jobs.

=cut

method get_queue_status() {
	my $status = $self->get_loader_status();

	if ($status->{payload}{overallStatus}) {
		my $overall = $status->{payload}{overallStatus};

		return {
			total_jobs     => $overall->{fullQueueSize} // 0,
			running_jobs   => $overall->{runningJobs} // 0,
			queued_jobs    => $overall->{queuedJobs} // 0,
			succeeded_jobs => $overall->{succeededJobs} // 0,
			failed_jobs    => $overall->{failedJobs} // 0,
		};
	}

	# Fallback to load IDs list
	if ($status->{payload}{loadIds}) {
		return {
			recent_loads => $status->{payload}{loadIds} // [],
		};
	}

	return {};
}

=method get_load_job_status

Get the detailed status of a specific load job.

=cut

method get_load_job_status ($load_id) {
	croak "Load ID required" unless $load_id;

	my $status = $self->get_loader_status($load_id);

	if ($status->{payload}{overallStatus}) {
		my $overall = $status->{payload}{overallStatus};

		return {
			load_id        => $load_id,
			status         => $overall->{status},
			start_time     => $overall->{startTime},
			total_records  => $overall->{totalRecords},
			loaded_records => $overall->{loadedRecords},
			error_details  => $overall->{errorDetails},
			errors         => $overall->{errors},
		};
	}

	return undef;
}

=method is_queue_full

Check if the Neptune loader queue is full or nearly full.

=cut

method is_queue_full(Int $threshold = 60) {
	# Neptune typically has a ~64 job limit
	my $queue_status = $self->get_queue_status();
	my $queued = $queue_status->{queued_jobs} // 0;

	return $queued >= $threshold;
}

=method wait_for_capacity

Wait until there is capacity in the queue.

=cut

method wait_for_capacity(Int :$threshold = 30, Int :$interval = 30, Int :$max_wait = 3600) {
	# Wait until queue < threshold, check every interval seconds, max max_wait seconds
	my $start_time = time();

	while (1) {
		my $queue_status = $self->get_queue_status();
		my $queued = $queue_status->{queued_jobs} // 0;

		if ($queued < $threshold) {
			$self->log->info("Queue has capacity (queued: $queued < threshold: $threshold)");
			return 1;
		}

		if (time() - $start_time > $max_wait) {
			$self->log->warn("Timeout waiting for queue capacity");
			return 0;
		}

		$self->log->info("Queue full (queued: $queued), waiting ${interval}s...");
		sleep $interval;
	}
}

=method execute_sparql

Execute a SPARQL query against Neptune.

=cut

method execute_sparql(Str $query, Str :$format = 'application/sparql-results+json') {
	my $url = $self->sparql_url;

	# Use URI module's query_form method for proper escaping
	my $uri = URI->new;
	$uri->query_form(query => $query);
	my $content = $uri->query;

	my $response = $self->ua->post(
		$url,
		'Content-Type' => 'application/x-www-form-urlencoded',
		'Accept' => $format,
		'Content' => $content,
	);

	unless ($response->is_success) {
		my $error = "SPARQL query failed: " . $response->status_line;
		$self->log->error($error);
		croak $error;
	}

	if ($format =~ /json/) {
		my $data = do {
			try {
				decode_json($response->content);
			} catch ($e) {
				my $error = "Failed to parse SPARQL response: $e";
				$self->log->error($error);
				croak $error;
			}
		};
		return $data;
	}

	return $response->content;
}

1;

__END__

=head1 SEE ALSO

L<Bio_Bricks::Store::Neptune::BulkLoader>
L<Bio_Bricks::Store::Neptune::LoadJob>
L<Bio_Bricks::Store::Neptune::State>

=cut
