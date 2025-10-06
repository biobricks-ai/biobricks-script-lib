package Bio_Bricks::Store::Neptune::State;
# ABSTRACT: Persistent state management for Neptune load jobs

use Bio_Bricks::Common::Setup;
use Types::Standard qw(InstanceOf ArrayRef);
use Types::Path::Tiny qw(Path);
use Path::Tiny;
use Bio_Bricks::Common::Config;
use MooX::Log::Any;

with qw(MooX::Log::Any);

=head1 NAME

Bio_Bricks::Store::Neptune::State - Persistent state management for Neptune load jobs

=head1 SYNOPSIS

	use Bio_Bricks::Store::Neptune::State;

	my $state = Bio_Bricks::Store::Neptune::State->new(
		file_path => 'neptune-jobs.json',
		neptune   => $neptune_instance,
	);

	# Add a job
	$state->add_job($load_job);

	# Save state
	$state->save();

	# Get completed jobs
	my @completed = $state->get_completed_jobs();

=head1 DESCRIPTION

This module manages persistent state for Neptune bulk load jobs,
including tracking job status and preventing duplicate loads.

=cut

# Configuration - can be injected for testing
ro config => (
	isa => InstanceOf['Bio_Bricks::Common::Config'],
	default => sub { Bio_Bricks::Common::Config->new },
);

# State file path
ro file_path => (
	isa => Path,
	coerce => 1,
	default => 'neptune-load-state.json',
);

# Neptune client - can be injected for testing
ro neptune => (
	isa => InstanceOf['Bio_Bricks::Store::Neptune'],
	required => 0,
);

# Internal job storage
rw _jobs => (
	isa => HashRef,
	default => sub { {} },
);

# Auto-save changes
ro auto_save => (
	isa => Bool,
	default => 1,
);

method BUILD() {
	$self->load() if $self->file_path->exists;
}

=head1 METHODS

=method load

Load state from file.

=cut

method load() {
	return unless $self->file_path->exists;

	$self->log->debug("Loading state from", { file => $self->file_path->stringify });

	my $content = $self->file_path->slurp_utf8;
	return unless $content;

	my $data = do {
		try {
			decode_json($content);
		} catch ($e) {
			$self->log->error("Failed to parse state file", { error => $e });
			return;
		}
	};

	$self->_jobs($data // {});

	my $job_count = scalar keys %{$self->_jobs};
	$self->log->info("Loaded state", { jobs => $job_count });

	return 1;
}

=method save

Save state to file.

=cut

method save() {
	my $json = encode_json($self->_jobs);

	$self->file_path->spew_utf8($json);

	my $job_count = scalar keys %{$self->_jobs};
	$self->log->debug("Saved state", { file => $self->file_path->stringify, jobs => $job_count });

	return 1;
}

=method add_job

Add a job to the state.

=cut

method add_job((InstanceOf['Bio_Bricks::Store::Neptune::LoadJob']) $job) {
	my $key = $job->key;
	$self->_jobs->{$key} = $job->to_hash;

	$self->log->debug("Added job to state", { load_id => $job->load_id, key => $key });

	$self->save() if $self->auto_save;

	return 1;
}

=method get_job

Get a job by key.

=cut

method get_job(Str $key) {
	my $job_data = $self->_jobs->{$key};
	return unless $job_data;

	return Bio_Bricks::Store::Neptune::LoadJob->from_hash($job_data, $self->neptune);
}

=method has_job

Check if a job exists by key.

=cut

method has_job(Str $key) {
	return exists $self->_jobs->{$key};
}

=method remove_job

Remove a job from state.

=cut

method remove_job(Str $key) {
	delete $self->_jobs->{$key};
	$self->save() if $self->auto_save;

	return 1;
}

=method get_all_jobs

Get all jobs as LoadJob objects.

=cut

method get_all_jobs() {
	my @jobs;
	for my $job_data (values %{$self->_jobs}) {
		push @jobs, Bio_Bricks::Store::Neptune::LoadJob->from_hash($job_data, $self->neptune);
	}

	return @jobs;
}

=method get_jobs_by_status

Get jobs filtered by status.

=cut

method get_jobs_by_status(Str $status) {
	my @jobs;
	for my $job_data (values %{$self->_jobs}) {
		next unless $job_data->{status} eq $status;
		push @jobs, Bio_Bricks::Store::Neptune::LoadJob->from_hash($job_data, $self->neptune);
	}

	return @jobs;
}

=method get_completed_jobs

Get all completed jobs.

=cut

method get_completed_jobs() {
	return $self->get_jobs_by_status('completed');
}

=method get_active_jobs

Get all active (queued or running) jobs.

=cut

method get_active_jobs() {
	my @jobs;
	for my $job_data (values %{$self->_jobs}) {
		my $status = $job_data->{status};
		next unless $status eq 'queued' || $status eq 'running' ||
					$status eq 'LOAD_IN_QUEUE' || $status eq 'LOAD_IN_PROGRESS';
		push @jobs, Bio_Bricks::Store::Neptune::LoadJob->from_hash($job_data, $self->neptune);
	}

	return @jobs;
}

=method get_failed_jobs

Get all failed jobs.

=cut

method get_failed_jobs() {
	return $self->get_jobs_by_status('failed');
}

=method is_already_loaded

Check if a file has already been successfully loaded.

=cut

method is_already_loaded(Str $source_uri, Maybe[Str] $graph_uri = undef) {
	my $key = $source_uri . '|' . ($graph_uri // 'default');
	my $job_data = $self->_jobs->{$key};

	return 0 unless $job_data;
	return $job_data->{status} eq 'completed';
}

=method update_job_statuses

Update status for all active jobs from Neptune.

=cut

method update_job_statuses() {
	my @active_jobs = $self->get_active_jobs();
	return 0 unless @active_jobs;

	$self->log->info("Updating status for active jobs", { count => scalar(@active_jobs) });

	my $updated = 0;
	for my $job (@active_jobs) {
		if ($job->refresh_status()) {
			# Update in our state
			my $key = $job->key;
			$self->_jobs->{$key} = $job->to_hash;
			$updated++;
		}

		# Rate limit API calls
		sleep 0.2;
	}

	$self->save() if $updated && $self->auto_save;

	$self->log->info("Updated job statuses", { updated => $updated });

	return $updated;
}

=method cleanup_old_jobs

Remove jobs older than specified age.

=cut

method cleanup_old_jobs(Int $max_age = 2592000) {  # 30 days default
	my $cutoff = time() - $max_age;
	my $removed = 0;

	for my $key (keys %{$self->_jobs}) {
		my $job_data = $self->_jobs->{$key};
		my $job_time = $job_data->{completed_at} // $job_data->{failed_at} // $job_data->{submitted_at};

		if ($job_time && $job_time < $cutoff) {
			delete $self->_jobs->{$key};
			$removed++;
		}
	}

	$self->save() if $removed && $self->auto_save;

	$self->log->info("Cleaned up old jobs", { removed => $removed }) if $removed;

	return $removed;
}

=method summary

Get a summary of all jobs by status.

=cut

method summary() {
	my %counts;
	for my $job_data (values %{$self->_jobs}) {
		$counts{$job_data->{status}}++;
	}

	return \%counts;
}

=method export_completed

Export completed jobs for analysis.

=cut

method export_completed(Str $format = 'json') {
	my @completed = $self->get_completed_jobs();

	if ($format eq 'json') {
		return encode_json([map { $_->to_hash } @completed]);
	}
	elsif ($format eq 'csv') {
		# Simple CSV export
		my @lines = ("load_id,source_uri,graph_uri,status,duration");
		for my $job (@completed) {
			push @lines, join(',',
				$job->load_id,
				$job->source_uri,
				$job->graph_uri // '',
				$job->status,
				$job->duration,
			);
		}
		return join("\n", @lines);
	}

	croak "Unsupported export format: $format";
}

1;

__END__

=head1 SEE ALSO

L<Bio_Bricks::Store::Neptune>
L<Bio_Bricks::Store::Neptune::LoadJob>

=cut
