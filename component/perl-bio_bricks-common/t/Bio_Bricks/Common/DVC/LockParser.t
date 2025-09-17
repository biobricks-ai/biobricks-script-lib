#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::Common::DVC::LockParser';

use FindBin;
use lib "$FindBin::Bin/../lib";

subtest 'Parse simple lock file' => sub {
	my $yaml = <<~'YAML';
		schema: '2.0'
		stages:
		  process_data:
		    cmd: python process.py
		    deps:
		    - path: data/input.txt
		      md5: abc123
		    outs:
		    - path: data/output.txt
		      md5: def456
		YAML

	my $lock = $CLASS->parse_string($yaml);

	is $lock, object {
		prop blessed => 'Bio_Bricks::Common::DVC::Schema::LockFile';
	}, 'Parses into LockFile object';

	is $lock->schema, '2.0', 'Schema version parsed correctly';
	is scalar(keys %{$lock->stages}), 1, 'Has one stage';
};

subtest 'Parse lock file with multiple stages' => sub {
	my $yaml = <<~'YAML';
		schema: '2.0'
		stages:
		  download:
		    cmd: wget data.zip
		    outs:
		    - path: data.zip
		      md5: abc123
		  extract:
		    cmd: unzip data.zip
		    deps:
		    - path: data.zip
		      md5: abc123
		    outs:
		    - path: data/file1.txt
		      md5: def456
		YAML

	my $lock = $CLASS->parse_string($yaml);

	is scalar(keys %{$lock->stages}), 2, 'Has two stages';
	is scalar(@{$lock->STAGE_NAMES}), 2, 'STAGE_NAMES has two entries';

	ok $lock->get_stage('download'), 'Can get download stage';
	ok $lock->get_stage('extract'), 'Can get extract stage';
};

subtest 'Parse directory outputs' => sub {
	my $yaml = <<~'YAML';
		schema: '2.0'
		stages:
		  download_many:
		    outs:
		    - path: data_dir
		      md5: abc123.dir
		      nfiles: 100
		      size: 1024000
		YAML

	my $lock = $CLASS->parse_string($yaml);

	my $stage = $lock->get_stage('download_many');
	my $output = $stage->outs->[0];

	ok $output->IS_DIRECTORY, 'Output is recognized as directory';
	is $output->nfiles, 100, 'Number of files is correct';
	is $output->size, 1024000, 'Total size is correct';
	is $output->path, 'data_dir', 'Path is correct';
	like $output->EFFECTIVE_HASH, qr/\.dir$/, 'Hash ends with .dir';
};

subtest 'Access all outputs' => sub {
	my $yaml = <<~'YAML';
		schema: '2.0'
		stages:
		  stage1:
		    outs:
		    - path: out1.txt
		      md5: hash1
		  stage2:
		    outs:
		    - path: out2.txt
		      md5: hash2
		    - path: out3.txt
		      md5: hash3
		YAML

	my $lock = $CLASS->parse_string($yaml);
	my $outputs = $lock->OUTPUTS;

	is scalar(@$outputs), 3, 'Has three total outputs';
};

subtest 'Parse with hash field pointing to md5' => sub {
	my $yaml = <<~'YAML';
		schema: '2.0'
		stages:
		  test:
		    outs:
		    - path: file.txt
		      hash: md5
		      md5: abc123def456
		YAML

	my $lock = $CLASS->parse_string($yaml);
	my $stage = $lock->get_stage('test');
	my $output = $stage->outs->[0];

	is $output->EFFECTIVE_HASH, 'abc123def456', 'EFFECTIVE_HASH resolves md5 correctly';
};

subtest 'Handle invalid YAML' => sub {
	my $result = $CLASS->parse_string("invalid: yaml: content::");

	is $result, undef, 'Returns undef for invalid YAML';
};

subtest 'Handle empty input' => sub {
	my $result = $CLASS->parse_string(undef);
	is $result, undef, 'Returns undef for undef input';

	$result = $CLASS->parse_string('');
	is $result, undef, 'Returns undef for empty string';
};

done_testing;
