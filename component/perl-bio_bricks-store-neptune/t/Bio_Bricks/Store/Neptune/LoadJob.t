#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::Store::Neptune::LoadJob';
use Test2::Mock;

use Bio_Bricks::Store::Neptune;

# Create a mock Neptune object factory
sub mock_neptune {
	my ($response_ref) = @_;

	my $mock = Test2::Mock->new(
		class => 'Bio_Bricks::Store::Neptune',
		track => 1,
	);

	# Mock get_load_job_status method
	$mock->override(
		get_load_job_status => sub {
			my ($self, $load_id) = @_;
			return $$response_ref;
		}
	);

	my $neptune = Bio_Bricks::Store::Neptune->new(
		endpoint => 'localhost',
		ssl_verify => 0,
	);

	return ($mock, $neptune);
}

subtest 'LoadJob creation' => sub {
	is $CLASS->new(
		load_id => 'load-123-456',
		source_uri => 's3://bucket/file.nt',
		format => 'ntriples',
	), object {
		prop blessed => 'Bio_Bricks::Store::Neptune::LoadJob';
		call load_id => 'load-123-456';
		call source_uri => 's3://bucket/file.nt';
		call format => 'ntriples';
		call status => 'submitted';
	}, 'Can create LoadJob object';
};

subtest 'Optional metadata fields' => sub {
	my $job = $CLASS->new(
		load_id => 'load-789',
		source_uri => 's3://bucket/data.ttl',
		format => 'turtle',
		graph_uri => 'http://example.org/graph',
		file_path => 'data/output.ttl',
		repo => 'my-repo',
		stage => 'processed',
	);

	is $job, object {
		call graph_uri => 'http://example.org/graph';
		call file_path => 'data/output.ttl';
		call repo => 'my-repo';
		call stage => 'processed';
	}, 'Optional metadata fields set correctly';
};

subtest 'Status check helpers' => sub {
	my $response = {
		load_id => 'load-helpers',
		status => 'LOAD_IN_QUEUE',
	};
	my ($mock, $neptune) = mock_neptune(\$response);

	my $job = $CLASS->new(
		load_id => 'load-helpers',
		source_uri => 's3://bucket/file.nt',
		format => 'ntriples',
		neptune => $neptune,
	);

	is($job->is_completed, F(), 'Not completed initially');
	is($job->is_failed, F(), 'Not failed initially');
	is($job->status, 'submitted', 'Initial status is submitted');

	# Refresh to get queued status
	$job->refresh_status();
	is($job->is_queued, T(), 'is_queued returns true');
	is($job->is_active, T(), 'is_active returns true for queued');
	is($job->is_finished, F(), 'is_finished returns false for queued');

	# Change mock to return running
	$response = {
		load_id => 'load-helpers',
		status => 'LOAD_IN_PROGRESS',
	};
	$job->refresh_status();
	is($job->is_running, T(), 'is_running returns true');
	is($job->is_active, T(), 'is_active returns true for running');

	# Change mock to return completed
	$response = {
		load_id => 'load-helpers',
		status => 'LOAD_COMPLETED',
	};
	$job->refresh_status();
	is($job->is_completed, T(), 'is_completed returns true');
	is($job->is_finished, T(), 'is_finished returns true for completed');
	is($job->is_active, F(), 'is_active returns false for completed');

	# Change mock to return failed
	$response = {
		load_id => 'load-helpers',
		status => 'LOAD_FAILED',
	};
	$job->refresh_status();
	is($job->is_failed, T(), 'is_failed returns true');
	is($job->is_finished, T(), 'is_finished returns true for failed');

	$mock->reset_all;
};

subtest 'Refresh status - LOAD_COMPLETED' => sub {
	my $response = {
		load_id => 'load-complete',
		status => 'LOAD_COMPLETED',
		total_records => 1000,
		loaded_records => 1000,
	};
	my ($mock, $neptune) = mock_neptune(\$response);

	my $job = $CLASS->new(
		load_id => 'load-complete',
		source_uri => 's3://bucket/file.nt',
		format => 'ntriples',
		neptune => $neptune,
	);

	my $before_time = time;
	my $result = $job->refresh_status();

	is($result, 1, 'refresh_status returns success');
	is($job->status, 'completed', 'Status updated to completed');
	is($job->total_records, 1000, 'Total records updated');
	is($job->loaded_records, 1000, 'Loaded records updated');
	ok($job->completed_at >= $before_time, 'Completion timestamp set');
	is($job->is_completed, T(), 'Job marked as completed');

	$mock->reset_all;
};

subtest 'Refresh status - LOAD_FAILED' => sub {
	my $response = {
		load_id => 'load-fail',
		status => 'LOAD_FAILED',
		error_details => 'S3 access denied',
		errors => { code => 'AccessDenied' },
	};
	my ($mock, $neptune) = mock_neptune(\$response);

	my $job = $CLASS->new(
		load_id => 'load-fail',
		source_uri => 's3://bucket/file.nt',
		format => 'ntriples',
		neptune => $neptune,
	);

	my $before_time = time;
	my $result = $job->refresh_status();

	is($result, 1, 'refresh_status returns success');
	is($job->status, 'failed', 'Status updated to failed');
	is($job->error_details, 'S3 access denied', 'Error details captured');
	is($job->errors, { code => 'AccessDenied' }, 'Error object captured');
	ok($job->failed_at >= $before_time, 'Failure timestamp set');
	is($job->is_failed, T(), 'Job marked as failed');

	$mock->reset_all;
};

subtest 'Refresh status - LOAD_IN_PROGRESS' => sub {
	my $response = {
		load_id => 'load-progress',
		status => 'LOAD_IN_PROGRESS',
		total_records => 10000,
		loaded_records => 5000,
	};
	my ($mock, $neptune) = mock_neptune(\$response);

	my $job = $CLASS->new(
		load_id => 'load-progress',
		source_uri => 's3://bucket/file.nt',
		format => 'ntriples',
		neptune => $neptune,
	);

	my $before_time = time;
	my $result = $job->refresh_status();

	is($result, 1, 'refresh_status returns success');
	is($job->status, 'running', 'Status updated to running');
	is($job->total_records, 10000, 'Total records updated');
	is($job->loaded_records, 5000, 'Loaded records updated');
	ok($job->started_at >= $before_time, 'Start timestamp set');
	is($job->is_running, T(), 'Job marked as running');

	$mock->reset_all;
};

subtest 'Refresh status - LOAD_IN_QUEUE' => sub {
	my $response = {
		load_id => 'load-queue',
		status => 'LOAD_IN_QUEUE',
	};
	my ($mock, $neptune) = mock_neptune(\$response);

	my $job = $CLASS->new(
		load_id => 'load-queue',
		source_uri => 's3://bucket/file.nt',
		format => 'ntriples',
		neptune => $neptune,
	);

	my $result = $job->refresh_status();

	is($result, 1, 'refresh_status returns success');
	is($job->status, 'queued', 'Status updated to queued');
	is($job->is_queued, T(), 'Job marked as queued');

	$mock->reset_all;
};

subtest 'Refresh status - unavailable' => sub {
	my $response = undef;
	my ($mock, $neptune) = mock_neptune(\$response);

	my $job = $CLASS->new(
		load_id => 'load-missing',
		source_uri => 's3://bucket/file.nt',
		format => 'ntriples',
		neptune => $neptune,
	);

	my $result = $job->refresh_status();

	is($result, 0, 'refresh_status returns failure');
	is($job->status, 'submitted', 'Status unchanged when unavailable');

	$mock->reset_all;
};

subtest 'Refresh status - multiple transitions' => sub {
	my $response = {
		load_id => 'load-multi',
		status => 'LOAD_IN_QUEUE',
	};
	my ($mock, $neptune) = mock_neptune(\$response);

	my $job = $CLASS->new(
		load_id => 'load-multi',
		source_uri => 's3://bucket/file.nt',
		format => 'ntriples',
		neptune => $neptune,
	);

	# First refresh: queued
	$job->refresh_status();
	is($job->status, 'queued', 'Initial status: queued');

	# Update mock response to in-progress
	$response = {
		load_id => 'load-multi',
		status => 'LOAD_IN_PROGRESS',
		total_records => 1000,
		loaded_records => 300,
	};
	$job->refresh_status();
	is($job->status, 'running', 'Status transitioned to running');
	ok($job->started_at, 'Start time recorded');

	# Update mock response to completed
	$response = {
		load_id => 'load-multi',
		status => 'LOAD_COMPLETED',
		total_records => 1000,
		loaded_records => 1000,
	};
	$job->refresh_status();
	is($job->status, 'completed', 'Status transitioned to completed');
	ok($job->completed_at, 'Completion time recorded');

	$mock->reset_all;
};

subtest 'Progress calculation' => sub {
	my $response = {
		load_id => 'load-progress',
		status => 'LOAD_IN_PROGRESS',
		total_records => 1000,
		loaded_records => 250,
	};
	my ($mock, $neptune) = mock_neptune(\$response);

	my $job = $CLASS->new(
		load_id => 'load-progress',
		source_uri => 's3://bucket/file.nt',
		format => 'ntriples',
		neptune => $neptune,
	);

	is($job->progress_percent, 0, 'Progress is 0 when no records');

	$job->refresh_status();
	is($job->progress_percent, 25, 'Progress correctly calculated at 25%');

	$response->{loaded_records} = 500;
	$job->refresh_status();
	is($job->progress_percent, 50, 'Progress correctly calculated at 50%');

	$response->{loaded_records} = 1000;
	$job->refresh_status();
	is($job->progress_percent, 100, 'Progress correctly calculated at 100%');

	$mock->reset_all;
};

subtest 'Job serialization' => sub {
	my $response = {
		load_id => 'load-serialize',
		status => 'LOAD_COMPLETED',
	};
	my ($mock, $neptune) = mock_neptune(\$response);

	my $job = $CLASS->new(
		load_id => 'load-serialize',
		source_uri => 's3://bucket/file.nt',
		graph_uri => 'http://example.org/graph',
		format => 'ntriples',
		repo => 'test-repo',
		stage => 'final',
		neptune => $neptune,
	);

	$job->refresh_status();

	my $data = $job->to_hash;

	is $data, hash {
		field load_id => 'load-serialize';
		field source_uri => 's3://bucket/file.nt';
		field graph_uri => 'http://example.org/graph';
		field format => 'ntriples';
		field status => 'completed';
		field repo => 'test-repo';
		field stage => 'final';
		etc();
	}, 'Serializes to hash correctly';

	$mock->reset_all;
};

done_testing;
