#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::Common::DVC::Iterator::Item';

use FindBin;
use lib "$FindBin::Bin/../lib";
use Bio_Bricks::Common::DVC::Schema;
use Bio_Bricks::Common::DVC::Iterator;
use URI::s3;

# Mock storage for testing
package MockStorage {
	use Moo;
	extends 'Bio_Bricks::Common::DVC::Storage';
	has '+base_uri' => (default => 's3://test-bucket/files');
	sub resolve { URI::s3->new('s3://test-bucket/file.csv') }
	sub head_object { }
	sub get_object { }
	sub object_exists { 1 }
	sub fetch_directory {
		package MockDir { use Moo; has files => (is => 'ro', default => sub { [] }); }
		MockDir->new();
	}
}

subtest 'Create item with required attributes' => sub {
	my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'data/test.csv',
		md5 => 'abc123',
		size => 1024,
	);
	my $storage = MockStorage->new();
	my $iterator = Bio_Bricks::Common::DVC::Iterator->new(
		storage => $storage,
		output => $output,
	);
	my $uri = URI::s3->new('s3://bucket/file.csv');

	my $item = $CLASS->new(
		output => $output,
		uri => $uri,
		iterator => $iterator,
	);

	is $item, object {
		prop blessed => $CLASS;
		call output => $output;
		call uri => $uri;
		call iterator => $iterator;
	}, 'Item created with required attributes';
};

subtest 'path_segments splits path correctly' => sub {
	my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'data/subdir/test.csv',
		md5 => 'abc123',
	);
	my $storage = MockStorage->new();
	my $iterator = Bio_Bricks::Common::DVC::Iterator->new(
		storage => $storage,
		output => $output,
	);
	my $uri = URI::s3->new('s3://bucket/file.csv');

	is $CLASS->new(
		output => $output,
		uri => $uri,
		iterator => $iterator,
	), object {
		call path_segments => ['data', 'subdir', 'test.csv'];
		call path => 'data/subdir/test.csv';
	}, 'Path segments and reconstruction work correctly';
};

subtest 'Delegated methods' => sub {
	my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'test.csv',
		md5 => 'abc123',
		size => 2048,
	);
	my $storage = MockStorage->new();
	my $iterator = Bio_Bricks::Common::DVC::Iterator->new(
		storage => $storage,
		output => $output,
	);
	my $uri = URI::s3->new('s3://bucket/file.csv');

	is $CLASS->new(
		output => $output,
		uri => $uri,
		iterator => $iterator,
	), object {
		call hash => 'abc123';
		call size => 2048;
		call is_directory => F();
		call is_file => T();
		call storage => $storage;
	}, 'Delegated methods work correctly';
};

subtest 'file_extension parsing' => sub {
	my $storage = MockStorage->new();
	my $uri = URI::s3->new('s3://bucket/file');

	my @cases = (
		['test.csv', 'csv'],
		['data.tar.gz', 'gz'],
		['noextension', undef],
		['dir/file.txt', 'txt'],
		['.hidden', 'hidden'],
	);

	for my $case (@cases) {
		my ($path, $expected_ext) = @$case;
		my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
			path => $path,
			md5 => 'hash',
		);
		my $iterator = Bio_Bricks::Common::DVC::Iterator->new(
			storage => $storage,
			output => $output,
		);

		is $CLASS->new(
			output => $output,
			uri => $uri,
			iterator => $iterator,
		), object {
			call file_extension => $expected_ext;
		}, "Extension for '$path' is " . ($expected_ext // 'undef');
	}
};

subtest 'basename and dirname' => sub {
	my $storage = MockStorage->new();
	my $uri = URI::s3->new('s3://bucket/file');

	my @cases = (
		['data/subdir/test.csv', 'test.csv', 'data/subdir', ['data', 'subdir']],
		['test.csv', 'test.csv', '', []],
		['dir/file.txt', 'file.txt', 'dir', ['dir']],
	);

	for my $case (@cases) {
		my ($path, $expected_base, $expected_dir, $expected_dir_segs) = @$case;
		my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
			path => $path,
			md5 => 'hash',
		);
		my $iterator = Bio_Bricks::Common::DVC::Iterator->new(
			storage => $storage,
			output => $output,
		);

		is $CLASS->new(
			output => $output,
			uri => $uri,
			iterator => $iterator,
		), object {
			call basename => $expected_base;
			call dirname => $expected_dir;
			call dirname_segments => $expected_dir_segs;
		}, "Path components for '$path'";
	}
};

subtest 'parent_directory and from_directory' => sub {
	my $storage = MockStorage->new();
	my $uri = URI::s3->new('s3://bucket/file');

	my $parent_output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'parent_dir',
		md5 => 'parent_hash.dir',
	);

	my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'parent_dir/file.csv',
		md5 => 'file_hash',
	);

	my $iterator = Bio_Bricks::Common::DVC::Iterator->new(
		storage => $storage,
		output => $output,
	);

	is $CLASS->new(
		output => $output,
		uri => $uri,
		iterator => $iterator,
	), object {
		call has_parent_directory => F();
		call from_directory => U();
	}, 'Item without parent_directory';

	is $CLASS->new(
		output => $output,
		uri => $uri,
		iterator => $iterator,
		parent_directory => $parent_output,
	), object {
		call has_parent_directory => T();
		call parent_directory => $parent_output;
		call from_directory => 'parent_dir';
	}, 'Item with parent_directory';
};

subtest 'size_human formatting' => sub {
	my $storage = MockStorage->new();
	my $uri = URI::s3->new('s3://bucket/file');

	my @cases = (
		[1024, qr/1\.0K/],
		[1048576, qr/1\.0M/],
		[100, qr/100/],
	);

	for my $case (@cases) {
		my ($size, $pattern) = @$case;
		my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
			path => 'test.csv',
			md5 => 'hash',
			size => $size,
		);
		my $iterator = Bio_Bricks::Common::DVC::Iterator->new(
			storage => $storage,
			output => $output,
		);
		my $item = $CLASS->new(
			output => $output,
			uri => $uri,
			iterator => $iterator,
		);

		like $item->size_human, $pattern, "Human size for $size bytes";
	}
};

subtest 'summary method' => sub {
	my $storage = MockStorage->new();
	my $uri = URI::s3->new('s3://bucket/file');

	my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'data/test.csv',
		md5 => 'hash',
		size => 2048,
	);
	my $iterator = Bio_Bricks::Common::DVC::Iterator->new(
		storage => $storage,
		output => $output,
	);

	is $CLASS->new(
		output => $output,
		uri => $uri,
		iterator => $iterator,
	), object {
		call summary => match qr/data\/test\.csv.*\.csv.*2\.0K/;
	}, 'Summary includes path, extension, and size';

	# Test summary with parent directory
	my $parent_output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'parent_dir',
		md5 => 'parent.dir',
	);

	is $CLASS->new(
		output => $output,
		uri => $uri,
		iterator => $iterator,
		parent_directory => $parent_output,
	), object {
		call summary => match qr/from directory: parent_dir/;
	}, 'Summary includes parent directory info';
};

subtest 'file without extension' => sub {
	my $storage = MockStorage->new();
	my $uri = URI::s3->new('s3://bucket/file');

	my $output = Bio_Bricks::Common::DVC::Schema::Output->new(
		path => 'README',
		md5 => 'hash',
		size => 100,
	);
	my $iterator = Bio_Bricks::Common::DVC::Iterator->new(
		storage => $storage,
		output => $output,
	);

	is $CLASS->new(
		output => $output,
		uri => $uri,
		iterator => $iterator,
	), object {
		call file_extension => U();
		call summary => match qr/\.unknown/;
	}, 'File without extension shows .unknown in summary';
};

done_testing;
