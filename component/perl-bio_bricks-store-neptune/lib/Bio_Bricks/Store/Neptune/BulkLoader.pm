package Bio_Bricks::Store::Neptune::BulkLoader;
# ABSTRACT: Neptune bulk loading interface

use Bio_Bricks::Common::Setup;
use Types::Common::String qw(NonEmptyStr);
use Bio_Bricks::Common::Config;
use MooX::Log::Any;

with qw(MooX::Log::Any);

=head1 NAME

Bio_Bricks::Store::Neptune::BulkLoader - Neptune bulk loading interface

=head1 SYNOPSIS

	use Bio_Bricks::Store::Neptune::BulkLoader;

	my $loader = Bio_Bricks::Store::Neptune::BulkLoader->new(
		neptune     => $neptune_instance,
		iam_role    => 'arn:aws:iam::123456789012:role/NeptuneLoadFromS3',
		region      => 'us-east-1',
	);

	my $load_id = $loader->start_load(
		source_uri => 's3://my-bucket/data.nt',
		format     => 'ntriples',
		graph_uri  => 'http://example.org/graph',
	);

=head1 DESCRIPTION

This module handles Neptune bulk loading operations, including format
detection, load job submission, and status monitoring.

=cut

# Neptune client instance - can be injected for testing
ro neptune => (
	isa => InstanceOf['Bio_Bricks::Store::Neptune'],
	required => 1,
);

# Configuration - can be injected for testing
ro config => (
	isa => InstanceOf['Bio_Bricks::Common::Config'],
	default => sub { Bio_Bricks::Common::Config->new },
);

# IAM role ARN for Neptune bulk loader
ro iam_role => (
	isa => NonEmptyStr,
	required => 1,
);

# AWS region
lazy region => sub {
	shift->config->aws_region;
};

# Fail bulk load on any error
ro fail_on_error => (
	isa => Bool,
	default => 1,
);

# Parallelism level
ro parallelism => (
	isa => Str,
	default => 'MEDIUM',
);

# Update single cardinality properties
ro update_single_cardinality => (
	isa => Bool,
	default => 0,
);

# Queue load request if another is running (allows up to 64 jobs queued)
# Default: FALSE (matches AWS default - will fail if another load is running)
ro queue_request => (
	isa => Bool,
	default => 0,
);

# Load mode: AUTO, NEW, or RESUME
# RESUME mode will skip files that were successfully loaded in a previous attempt
ro mode => (
	isa => Str,
	default => 'AUTO',
);

# Valid parallelism levels
my %VALID_PARALLELISM = map { $_ => 1 } qw(LOW MEDIUM HIGH OVERSUBSCRIBE);

# Valid load modes
my %VALID_MODES = map { $_ => 1 } qw(AUTO NEW RESUME);

# Valid RDF formats for Neptune
my %VALID_FORMATS = map { $_ => 1 } qw(ntriples nquads turtle rdfxml);

method BUILD() {
	# Validate parallelism
	unless ($VALID_PARALLELISM{$self->parallelism}) {
		croak "Invalid parallelism: " . $self->parallelism .
			  ". Must be one of: " . join(', ', keys %VALID_PARALLELISM);
	}

	# Validate mode
	unless ($VALID_MODES{$self->mode}) {
		croak "Invalid mode: " . $self->mode .
			  ". Must be one of: " . join(', ', keys %VALID_MODES);
	}
}

=head1 METHODS

=method detect_format

Detect RDF format from file path.

	my $format = $loader->detect_format('data.nt');  # 'ntriples'

=cut

method detect_format((NonEmptyStr) $path) {
	# Supported compression
	my $compression_re = qr/\.(?:gz|bz2)/;

	# Map file extensions to Neptune-supported RDF formats
	return 'ntriples' if $path =~ m{ \.    nt           (?:$compression_re)? $ }ix;
	return 'nquads'   if $path =~ m{ \.    nq           (?:$compression_re)? $ }ix;
	return 'turtle'   if $path =~ m{ \.    ttl          (?:$compression_re)? $ }ix;
	return 'rdfxml'   if $path =~ m{ \. (?:rdf|xml|owl) (?:$compression_re)? $ }ix;

	# Default to unsupported
	return 'unsupported';
}

=method validate_format

Check if a format is supported by Neptune.

=cut

method validate_format(Str $format) {
	return $VALID_FORMATS{$format} // 0;
}

=method build_load_request

Build a bulk load request payload.

=cut

method build_load_request(Str :$source_uri, Str :$format, Maybe[Str] :$graph_uri = undef) {
	croak "source_uri required" unless defined $source_uri;
	croak "format required" unless defined $format;

	# Validate format
	unless ($self->validate_format($format)) {
		croak "Unsupported format: $format";
	}

	my $request = {
		source => $source_uri,
		format => $format,
		iamRoleArn => $self->iam_role,
		region => $self->region,
		failOnError => $self->fail_on_error ? 'TRUE' : 'FALSE',
		parallelism => $self->parallelism,
		queueRequest => $self->queue_request ? 'TRUE' : 'FALSE',
		mode => $self->mode,
	};

	# Add single cardinality update if enabled
	if ($self->update_single_cardinality) {
		$request->{updateSingleCardinalityProperties} = 'TRUE';
	}

	# Add named graph if specified
	if (defined $graph_uri) {
		$request->{parserConfiguration} = {
			namedGraphUri => $graph_uri
		};
	}

	return $request;
}

=method start_load

Start a bulk load job.

	my $load_id = $loader->start_load(
		source_uri => 's3://bucket/file.nt',
		format     => 'ntriples',
		graph_uri  => 'http://example.org/graph',  # optional
	);

=cut

method start_load(Str :$source_uri, Str :$format, Maybe[Str] :$graph_uri = undef) {
	croak "source_uri required" unless defined $source_uri;
	croak "format required" unless defined $format;
	my $request = $self->build_load_request(
		source_uri => $source_uri,
		format => $format,
		graph_uri => $graph_uri,
	);

	$self->log->info("Starting Neptune bulk load", {
		source => $source_uri,
		format => $format,
		graph  => $graph_uri // 'default',
	});

	my $url = $self->neptune->loader_url();
	my $json = encode_json($request);

	my $response = $self->neptune->ua->post(
		$url,
		'Content-Type' => 'application/json',
		'Content' => $json,
	);

	unless ($response->is_success) {
		my $error = "Failed to start bulk load: " . $response->status_line;
		$self->log->error($error, { response => $response->content });
		croak $error;
	}

	my $result = do {
		try {
			decode_json($response->content);
		} catch ($e) {
			my $error = "Failed to parse load response: $e";
			$self->log->error($error);
			croak $error;
		}
	};

	my $load_id = $result->{payload}{loadId};
	unless ($load_id) {
		my $error = "No load ID in response";
		$self->log->error($error, { response => $result });
		croak $error;
	}

	$self->log->info("Bulk load started", { load_id => $load_id });

	return $load_id;
}

=method start_load_with_auto_format

Start a bulk load with automatic format detection.

	my $load_id = $loader->start_load_with_auto_format(
		source_uri => 's3://bucket/data.ttl',
		graph_uri  => 'http://example.org/graph',
	);

=cut

method start_load_with_auto_format(Str :$source_uri, Maybe[Str] :$graph_uri = undef) {
	croak "source_uri required" unless defined $source_uri;
	# Extract filename from URI for format detection
	my $filename = $source_uri;
	$filename =~ s{^.*/([^/]+)$}{$1};

	my $format = $self->detect_format($filename);

	if ($format eq 'unsupported') {
		croak "Unsupported file format: $filename";
	}

	return $self->start_load(
		source_uri => $source_uri,
		format => $format,
		graph_uri => $graph_uri,
	);
}

=method wait_for_load

Wait for a load job to complete.

	my $final_status = $loader->wait_for_load(
		load_id  => $load_id,
		interval => 30,     # seconds between checks
		timeout  => 3600,   # max wait time
	);

=cut

method wait_for_load(Str :$load_id, Int :$interval = 30, Int :$timeout = 3600) {
	croak "load_id required" unless defined $load_id;
	my $start_time = time();

	$self->log->info("Waiting for load to complete", {
		load_id => $load_id,
		timeout => $timeout,
	});

	while (1) {
		my $status = $self->neptune->get_load_job_status($load_id);

		unless ($status) {
			$self->log->error("Failed to get load status", { load_id => $load_id });
			last;
		}

		my $neptune_status = $status->{status};

		if ($neptune_status eq 'LOAD_COMPLETED') {
			$self->log->info("Load completed successfully", { load_id => $load_id });
			return $status;
		}

		if ($neptune_status eq 'LOAD_FAILED') {
			$self->log->error("Load failed", {
				load_id => $load_id,
				error   => $status->{error_details},
			});
			return $status;
		}

		if (time() - $start_time > $timeout) {
			$self->log->warn("Load wait timeout", { load_id => $load_id });
			return $status;
		}

		$self->log->debug("Load in progress", {
			load_id => $load_id,
			status  => $neptune_status,
			records => $status->{loaded_records} // 0,
		});

		sleep $interval;
	}

	return undef;
}

=method cancel_load

Cancel a running load job.

=cut

method cancel_load(Str $load_id) {
	my $url = $self->neptune->loader_url($load_id);

	my $response = $self->neptune->ua->delete($url);

	unless ($response->is_success) {
		my $error = "Failed to cancel load: " . $response->status_line;
		$self->log->error($error);
		croak $error;
	}

	$self->log->info("Load cancelled", { load_id => $load_id });

	return 1;
}

1;

__END__

=head1 SEE ALSO

L<Bio_Bricks::Store::Neptune>
L<Bio_Bricks::Store::Neptune::LoadJob>

=cut
