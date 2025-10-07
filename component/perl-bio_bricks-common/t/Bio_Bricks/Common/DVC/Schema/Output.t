#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin/../lib";
use Bio_Bricks::Common::DVC::Schema;  # Load parent module first
use Test2::V0 -target => 'Bio_Bricks::Common::DVC::Schema::Output';

subtest 'Create simple file output' => sub {
	my $output = $CLASS->new(
		path => 'data/test.csv',
		md5 => 'abc123def456',
		size => 2048,
	);

	is $output, object {
		call path => 'data/test.csv';
		call md5 => 'abc123def456';
		call size => 2048;
		call EFFECTIVE_HASH => 'abc123def456';
		call IS_DIRECTORY => F();
	}, 'Simple file output created correctly';
};

subtest 'Create directory output' => sub {
	my $output = $CLASS->new(
		path => 'data_dir',
		md5 => '123456.dir',
		nfiles => 50,
		size => 1024000,
	);

	is $output, object {
		call path => 'data_dir';
		call md5 => '123456.dir';
		call nfiles => 50;
		call size => 1024000;
		call EFFECTIVE_HASH => '123456.dir';
		call IS_DIRECTORY => T();
	}, 'Directory output recognized correctly';
};

subtest 'EFFECTIVE_HASH resolution with hash field' => sub {
	my $output = $CLASS->new(
		path => 'file.txt',
		hash => 'md5',
		md5 => 'def789abc123',
	);

	is $output->EFFECTIVE_HASH, 'def789abc123', 'EFFECTIVE_HASH resolves from md5 when hash="md5"';
};

subtest 'EFFECTIVE_HASH falls back to md5' => sub {
	my $output = $CLASS->new(
		path => 'file.txt',
		md5 => 'fallback123',
	);

	is $output->EFFECTIVE_HASH, 'fallback123', 'EFFECTIVE_HASH uses md5 directly';
};

subtest 'EFFECTIVE_HASH with checksum' => sub {
	my $output = $CLASS->new(
		path => 'file.txt',
		checksum => 'checksum456',
	);

	is $output->EFFECTIVE_HASH, 'checksum456', 'EFFECTIVE_HASH falls back to checksum';
};

subtest 'Optional cache and persist flags' => sub {
	my $output = $CLASS->new(
		path => 'cached.txt',
		md5 => 'hash1',
		cache => 1,
		persist => 1,
	);

	is $output, object {
		call cache => T();
		call persist => T();
	}, 'Cache and persist flags work';
};

subtest 'Optional remote field' => sub {
	my $output = $CLASS->new(
		path => 'remote-file.txt',
		md5 => 'remote123',
		remote => 'myremote',
	);

	is $output->remote, 'myremote', 'Remote field set correctly';
};

subtest 'IS_DIRECTORY detects .dir suffix' => sub {
	my $dir_output = $CLASS->new(
		path => 'some_directory',
		md5 => 'anything.dir',
	);

	ok $dir_output->IS_DIRECTORY, 'Hash ending in .dir detected as directory';

	my $file_output = $CLASS->new(
		path => 'some_file.txt',
		md5 => 'abc123',
	);

	ok !$file_output->IS_DIRECTORY, 'Hash without .dir detected as file';
};

subtest 'Minimal output with only path and md5' => sub {
	my $output = $CLASS->new(
		path => 'minimal.txt',
		md5 => 'min123',
	);

	is $output, object {
		call path => 'minimal.txt';
		call md5 => 'min123';
		call EFFECTIVE_HASH => 'min123';
		call IS_DIRECTORY => F();
	}, 'Minimal output works';
};

subtest 'Output with nfiles indicates directory structure' => sub {
	my $output = $CLASS->new(
		path => 'multi_files',
		md5 => 'multi.dir',
		nfiles => 100,
		size => 5000000,
	);

	is $output, object {
		call nfiles => 100;
		call size => 5000000;
		call IS_DIRECTORY => T();
	}, 'Multi-file directory output';
};

done_testing;
