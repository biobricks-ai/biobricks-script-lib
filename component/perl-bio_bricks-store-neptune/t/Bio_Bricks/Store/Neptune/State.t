#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::Store::Neptune::State';
use Test2::Mock;
use Path::Tiny;

use Bio_Bricks::Store::Neptune;
use Bio_Bricks::Store::Neptune::LoadJob;

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

subtest 'State creation with file' => sub {
	my $temp_file = Path::Tiny->tempfile(SUFFIX => '.json');

	is $CLASS->new(file_path => $temp_file->stringify), object {
		prop blessed => 'Bio_Bricks::Store::Neptune::State';
		call file_path => $temp_file->stringify;
	}, 'Can create State object with file';
};

subtest 'Initialize empty state file' => sub {
	my $temp_file = Path::Tiny->tempfile(SUFFIX => '.json');

	my $state = $CLASS->new(file_path => $temp_file->stringify);
	$state->save;

	my @jobs = $state->get_all_jobs;
	is(scalar(@jobs), 0, 'Empty state has zero jobs');
	ok($temp_file->exists, 'State file created');
};

subtest 'Add and retrieve jobs' => sub {
	my $temp_file = Path::Tiny->tempfile(SUFFIX => '.json');
	my $state = $CLASS->new(file_path => $temp_file->stringify, auto_save => 0);

	my $job1 = Bio_Bricks::Store::Neptune::LoadJob->new(
		load_id => 'job-001',
		source_uri => 's3://bucket/file1.nt',
		format => 'ntriples',
	);

	my $job2 = Bio_Bricks::Store::Neptune::LoadJob->new(
		load_id => 'job-002',
		source_uri => 's3://bucket/file2.ttl',
		format => 'turtle',
	);

	$state->add_job($job1);
	$state->add_job($job2);

	my @jobs = $state->get_all_jobs;
	is(scalar(@jobs), 2, 'State contains 2 jobs');

	my $retrieved = $state->get_job($job1->key);
	is $retrieved, object {
		call load_id => 'job-001';
		call source_uri => 's3://bucket/file1.nt';
	}, 'Retrieved job has correct properties';
};

subtest 'Job uniqueness by key' => sub {
	my $temp_file = Path::Tiny->tempfile(SUFFIX => '.json');
	my $state = $CLASS->new(file_path => $temp_file->stringify, auto_save => 0);

	my $job1 = Bio_Bricks::Store::Neptune::LoadJob->new(
		load_id => 'first-load',
		source_uri => 's3://bucket/file1.nt',
		format => 'ntriples',
	);

	my $job2 = Bio_Bricks::Store::Neptune::LoadJob->new(
		load_id => 'second-load',
		source_uri => 's3://bucket/file1.nt',
		format => 'ntriples',
	);

	$state->add_job($job1);
	$state->add_job($job2);

	my @jobs = $state->get_all_jobs;
	is(scalar(@jobs), 1, 'Duplicate key replaces existing job');

	my $retrieved = $state->get_job($job1->key);
	is($retrieved->load_id, 'second-load',
		'Latest job with duplicate key wins');
};

subtest 'Check if already loaded' => sub {
	my $temp_file = Path::Tiny->tempfile(SUFFIX => '.json');
	my $state = $CLASS->new(file_path => $temp_file->stringify, auto_save => 0);

	my $response = {
		load_id => 'completed-job',
		status => 'LOAD_COMPLETED',
	};
	my ($mock, $neptune) = mock_neptune(\$response);

	my $job = Bio_Bricks::Store::Neptune::LoadJob->new(
		load_id => 'completed-job',
		source_uri => 's3://bucket/data.nt',
		graph_uri => 'http://example.org/graph1',
		format => 'ntriples',
		neptune => $neptune,
	);

	$job->refresh_status();
	$state->add_job($job);

	is($state->is_already_loaded('s3://bucket/data.nt', 'http://example.org/graph1'), T(),
		'Detects already loaded file');

	is($state->is_already_loaded('s3://bucket/other.nt', 'http://example.org/graph1'), F(),
		'Different source not marked as loaded');

	is($state->is_already_loaded('s3://bucket/data.nt', 'http://example.org/graph2'), F(),
		'Different graph not marked as loaded');

	$mock->reset_all;
};

subtest 'Get jobs by status' => sub {
	my $temp_file = Path::Tiny->tempfile(SUFFIX => '.json');
	my $state = $CLASS->new(file_path => $temp_file->stringify, auto_save => 0);

	# Mock for completed jobs
	my $response1 = {
		load_id => 'job-1',
		status => 'LOAD_COMPLETED',
	};
	my ($mock1, $neptune1) = mock_neptune(\$response1);

	my $job1 = Bio_Bricks::Store::Neptune::LoadJob->new(
		load_id => 'job-1',
		source_uri => 's3://bucket/f1.nt',
		format => 'ntriples',
		neptune => $neptune1,
	);
	$job1->refresh_status();

	# Mock for failed job
	my $response2 = {
		load_id => 'job-2',
		status => 'LOAD_FAILED',
	};
	my ($mock2, $neptune2) = mock_neptune(\$response2);

	my $job2 = Bio_Bricks::Store::Neptune::LoadJob->new(
		load_id => 'job-2',
		source_uri => 's3://bucket/f2.nt',
		format => 'ntriples',
		neptune => $neptune2,
	);
	$job2->refresh_status();

	# Mock for another completed job
	my $response3 = {
		load_id => 'job-3',
		status => 'LOAD_COMPLETED',
	};
	my ($mock3, $neptune3) = mock_neptune(\$response3);

	my $job3 = Bio_Bricks::Store::Neptune::LoadJob->new(
		load_id => 'job-3',
		source_uri => 's3://bucket/f3.nt',
		format => 'ntriples',
		neptune => $neptune3,
	);
	$job3->refresh_status();

	$state->add_job($job1);
	$state->add_job($job2);
	$state->add_job($job3);

	my @completed = $state->get_jobs_by_status('completed');
	is(scalar(@completed), 2, 'Found 2 completed jobs');

	my @failed = $state->get_jobs_by_status('failed');
	is(scalar(@failed), 1, 'Found 1 failed job');

	$mock1->reset_all;
	$mock2->reset_all;
	$mock3->reset_all;
};

subtest 'State persistence' => sub {
	my $temp_file = Path::Tiny->tempfile(SUFFIX => '.json');

	my $job_key;
	{
		my $state = $CLASS->new(file_path => $temp_file->stringify);

		my $job = Bio_Bricks::Store::Neptune::LoadJob->new(
			load_id => 'persist-job',
			source_uri => 's3://bucket/persist.nt',
			format => 'ntriples',
		);

		$job_key = $job->key;
		$state->add_job($job);
		$state->save;
	}

	# Create new state instance and load from file
	my $state2 = $CLASS->new(file_path => $temp_file->stringify);

	my @jobs = $state2->get_all_jobs;
	is(scalar(@jobs), 1, 'State loaded from file');

	my $retrieved = $state2->get_job($job_key);
	is($retrieved->source_uri, 's3://bucket/persist.nt',
		'Persisted job has correct data');
};

subtest 'List all jobs' => sub {
	my $temp_file = Path::Tiny->tempfile(SUFFIX => '.json');
	my $state = $CLASS->new(file_path => $temp_file->stringify, auto_save => 0);

	for my $i (1..5) {
		my $job = Bio_Bricks::Store::Neptune::LoadJob->new(
			load_id => "job-$i",
			source_uri => "s3://bucket/file$i.nt",
			format => 'ntriples',
		);
		$state->add_job($job);
	}

	my @all_jobs = $state->get_all_jobs;
	is(scalar(@all_jobs), 5, 'get_all_jobs returns all jobs');
};

done_testing;
