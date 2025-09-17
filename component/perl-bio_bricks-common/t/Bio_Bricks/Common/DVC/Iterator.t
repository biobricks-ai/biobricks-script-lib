#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::Common::DVC::Iterator';

use FindBin;
use lib "$FindBin::Bin/../lib";
use Bio_Bricks::Common::DVC::Schema;

# Mock storage for testing
package MockStorage {
	use Moo;
	use URI::s3;
	extends 'Bio_Bricks::Common::DVC::Storage';

	has '+base_uri' => (default => 's3://test-bucket/files');

	sub resolve {
		my ($self, $output) = @_;
		my $hash = $output->EFFECTIVE_HASH;
		return URI::s3->new("s3://test-bucket/files/md5/" . substr($hash, 0, 2) . "/" . substr($hash, 2));
	}

	sub fetch_directory {
		my ($self, $output) = @_;
		# Return empty directory for simplicity
		package MockDirectory {
			use Moo;
			has files => (is => 'ro', default => sub { [] });
		}
		return MockDirectory->new();
	}

	# Implement required methods as stubs
	sub head_object { }
	sub get_object { }
	sub object_exists { return 1; }
}

subtest 'Iterator with single file output' => sub {
	my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'data/test.csv',
		md5 => 'abc123def456',
		size => 1024,
	);

	my $storage = MockStorage->new();
	my $iterator = $CLASS->new(
		storage => $storage,
		output => $output,
	);

	is $iterator, object {
		prop blessed => $CLASS;
	}, 'Iterator created successfully';

	# Call iterator as coderef
	my $result = $iterator->();

	ok $result, 'Iterator returns result';
	ok $result->is_ok, 'Result is ok';

	my $item = $result->unwrap;
	is $item, object {
		call path => 'data/test.csv';
		call hash => 'abc123def456';
		call size => 1024;
	}, 'Item has correct properties';

	# Next call should return undef (exhausted)
	my $second = $iterator->();
	is $second, undef, 'Iterator exhausted after one item';
};

subtest 'Iterator callable with &{} overload' => sub {
	my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'file.txt',
		md5 => '123456',
	);

	my $storage = MockStorage->new();
	my $iterator = $CLASS->new(
		storage => $storage,
		output => $output,
	);

	# Test that iterator is callable
	my $result = &$iterator;
	ok $result, 'Can call iterator with &{} syntax';
	ok $result->is_ok, 'Result is ok';
};

subtest 'Iterator with directory output returns empty' => sub {
	my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'data_dir',
		md5 => 'abc123.dir',
		nfiles => 0,
	);

	my $storage = MockStorage->new();
	my $iterator = $CLASS->new(
		storage => $storage,
		output => $output,
	);

	# Directory with no files should return undef immediately
	my $result = $iterator->();
	is $result, undef, 'Empty directory returns undef';
};

subtest 'Multiple iterations exhaust iterator' => sub {
	my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'single.txt',
		md5 => 'hash1',
	);

	my $storage = MockStorage->new();
	my $iterator = $CLASS->new(
		storage => $storage,
		output => $output,
	);

	my $first = $iterator->();
	ok $first, 'First call returns item';

	my $second = $iterator->();
	is $second, undef, 'Second call returns undef';

	my $third = $iterator->();
	is $third, undef, 'Third call also returns undef';
};

subtest 'Iterator item provides access to storage' => sub {
	my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'test.parquet',
		md5 => 'def789',
	);

	my $storage = MockStorage->new();
	my $iterator = $CLASS->new(
		storage => $storage,
		output => $output,
	);

	my $result = $iterator->();
	my $item = $result->unwrap;

	# Item should have access to storage via iterator
	is $item->storage, object {
		prop blessed => 'MockStorage';
	}, 'Item provides access to storage';
};

subtest 'URI resolution through storage' => sub {
	my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'data/file.hdt',
		md5 => '0123456789abcdef',
	);

	my $storage = MockStorage->new();
	my $iterator = $CLASS->new(
		storage => $storage,
		output => $output,
	);

	my $result = $iterator->();
	my $item = $result->unwrap;

	like $item->uri->as_string, qr{s3://test-bucket/files/md5/01/23456789abcdef}, 'URI resolved correctly';
};

done_testing;
