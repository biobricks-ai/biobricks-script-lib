package Bio_Bricks::Store::Neptune::LoadJob;
# ABSTRACT: Neptune load job tracking

use Bio_Bricks::Common::Setup;
use Types::Standard qw(InstanceOf);
use Types::Common::String qw(NonEmptyStr);
use MooX::Log::Any;

with qw(MooX::Log::Any);

=head1 NAME

Bio_Bricks::Store::Neptune::LoadJob - Neptune load job tracking

=head1 SYNOPSIS

	use Bio_Bricks::Store::Neptune::LoadJob;

	my $job = Bio_Bricks::Store::Neptune::LoadJob->new(
		load_id    => $load_id,
		source_uri => 's3://bucket/file.nt',
		graph_uri  => 'http://example.org/graph',
		format     => 'ntriples',
		neptune    => $neptune_instance,
	);

	$job->refresh_status();
	say "Status: " . $job->status;

=head1 DESCRIPTION

This module represents a Neptune bulk load job and provides methods
for tracking its progress and status.

=cut

# Job identification
ro load_id => (
	isa => NonEmptyStr,
	required => 1,
);

# Source data location
ro source_uri => (
	isa => NonEmptyStr,
	required => 1,
);

# Target graph URI (optional)
ro graph_uri => (
	isa => Maybe[Str],
	required => 0,
);

# RDF format
ro format => (
	isa => NonEmptyStr,
	required => 1,
);

# Source file path (for display)
ro file_path => (
	isa => Maybe[Str],
	required => 0,
);

# BioBricks repository name
ro repo => (
	isa => Maybe[Str],
	required => 0,
);

# DVC stage name
ro stage => (
	isa => Maybe[Str],
	required => 0,
);

# Neptune client - can be injected for testing
ro neptune => (
	isa => InstanceOf['Bio_Bricks::Store::Neptune'],
	required => 0,
);

# Status tracking
rw _status => (
	isa => Str,
	reader => 'status',
	default => 'submitted',
	handles_via => 'String',
	handles => {
		is_queued    => [ 'eq', 'queued' ],
		is_running   => [ 'eq', 'running' ],
		is_completed => [ 'eq', 'completed' ],
		is_failed    => [ 'eq', 'failed' ],
	},
);

# Timing information
ro submitted_at => (
	isa => Int,
	default => sub { time() },
);

rw started_at => (
	isa => Maybe[Int],
	required => 0,
);

rw completed_at => (
	isa => Maybe[Int],
	required => 0,
);

rw failed_at => (
	isa => Maybe[Int],
	required => 0,
);

# Progress tracking
rw total_records => (
	isa => Maybe[Int],
	required => 0,
);

rw loaded_records => (
	isa => Maybe[Int],
	required => 0,
);

# Error information
rw error_details => (
	isa => Maybe[Str],
	required => 0,
);

rw errors => (
	isa => Maybe[HashRef],
	required => 0,
);

=head1 METHODS

=method key

Generate a unique key for this job based on source and graph.

=cut

method key() {
	return $self->source_uri . '|' . ($self->graph_uri // 'default');
}

=method is_queued

Check if job is queued.

=method is_running

Check if job is currently running.

=method is_completed

Check if job completed successfully.

=method is_failed

Check if job failed.

=cut

=method is_finished

Check if job is in a terminal state (completed or failed).

=cut

method is_finished() {
	return $self->is_completed || $self->is_failed;
}

=method is_active

Check if job is currently active (queued or running).

=cut

method is_active() {
	return $self->is_queued || $self->is_running;
}

=method refresh_status

Refresh the job status from Neptune.

=cut

method refresh_status() {
	$self->log->debug("Refreshing status for job", { load_id => $self->load_id });

	my $status = $self->neptune->get_load_job_status($self->load_id);

	unless ($status) {
		$self->log->warn("Could not get status for job", { load_id => $self->load_id });
		return 0;
	}

	my $neptune_status = $status->{status};
	my $old_status = $self->status;

	# Update status
	if ($neptune_status eq 'LOAD_COMPLETED') {
		$self->_status('completed');
		$self->completed_at(time()) unless $self->completed_at;
	}
	elsif ($neptune_status eq 'LOAD_FAILED') {
		$self->_status('failed');
		$self->failed_at(time()) unless $self->failed_at;
		$self->error_details($status->{error_details}) if $status->{error_details};
		$self->errors($status->{errors}) if $status->{errors};
	}
	elsif ($neptune_status eq 'LOAD_IN_PROGRESS') {
		$self->_status('running');
		$self->started_at(time()) unless $self->started_at;
	}
	elsif ($neptune_status eq 'LOAD_IN_QUEUE') {
		$self->_status('queued');
	}
	else {
		$self->_status($neptune_status);
	}

	# Update record counts
	if (defined $status->{total_records}) {
		$self->total_records($status->{total_records});
	}
	if (defined $status->{loaded_records}) {
		$self->loaded_records($status->{loaded_records});
	}

	# Log status changes
	if ($old_status ne $self->status) {
		$self->log->info("Job status changed", {
			load_id    => $self->load_id,
			old_status => $old_status,
			new_status => $self->status,
		});
	}

	return 1;
}

=method progress_percent

Calculate loading progress as a percentage.

=cut

method progress_percent() {
	return 0 unless $self->total_records && $self->loaded_records;
	return 0 if $self->total_records == 0;

	return int(($self->loaded_records / $self->total_records) * 100);
}

=method duration

Get the duration of the job in seconds.

=cut

method duration() {
	my $start = $self->started_at // $self->submitted_at;
	my $end = $self->completed_at // $self->failed_at // time();

	return $end - $start;
}

=method to_hash

Convert job to a hash for serialization.

=cut

method to_hash() {
	return {
		load_id        => $self->load_id,
		source_uri     => $self->source_uri,
		graph_uri      => $self->graph_uri,
		format         => $self->format,
		file_path      => $self->file_path,
		repo           => $self->repo,
		stage          => $self->stage,
		status         => $self->status,
		submitted_at   => $self->submitted_at,
		started_at     => $self->started_at,
		completed_at   => $self->completed_at,
		failed_at      => $self->failed_at,
		total_records  => $self->total_records,
		loaded_records => $self->loaded_records,
		error_details  => $self->error_details,
		errors         => $self->errors,
	};
}

=classmethod from_hash

Create a job instance from a hash.

=cut

classmethod from_hash(HashRef $hash, (Maybe[InstanceOf['Bio_Bricks::Store::Neptune']]) $neptune) {
	return $class->new(
		%$hash,
		maybe neptune => $neptune,
	);
}

=method summary

Get a human-readable summary of the job.

=cut

method summary() {
	my @parts;

	push @parts, "Load ID: " . $self->load_id;
	push @parts, "Status: " . $self->status;

	if ($self->repo && $self->file_path) {
		push @parts, "File: " . $self->repo . "/" . $self->file_path;
	} else {
		push @parts, "Source: " . $self->source_uri;
	}

	if ($self->graph_uri) {
		push @parts, "Graph: " . $self->graph_uri;
	}

	if ($self->is_running && $self->total_records) {
		my $progress = $self->progress_percent;
		push @parts, "Progress: ${progress}%";
	}

	if ($self->is_failed && $self->error_details) {
		push @parts, "Error: " . $self->error_details;
	}

	return join(', ', @parts);
}

1;

__END__

=head1 SEE ALSO

L<Bio_Bricks::Store::Neptune>
L<Bio_Bricks::Store::Neptune::BulkLoader>
L<Bio_Bricks::Store::Neptune::State>

=cut
