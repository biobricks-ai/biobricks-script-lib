#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::Common::DVC::DirectoryParser';

use FindBin;
use lib "$FindBin::Bin/../lib";

subtest 'Parse simple directory JSON' => sub {
	my $json = '[
		{"relpath": "file1.txt", "md5": "abc123", "size": 100},
		{"relpath": "file2.txt", "md5": "def456", "size": 200}
	]';

	my $dir = $CLASS->parse_string($json);

	is $dir, object {
		prop blessed => $CLASS;
		call file_count => 2;
		call total_size => 300;
	}, 'Parses directory JSON';

	is $dir->files->[0], object {
		call relpath => 'file1.txt';
		call md5 => 'abc123';
		call size => 100;
	}, 'First file has correct properties';
};

subtest 'Parse wrapped directory JSON' => sub {
	my $json = '{"files": [
		{"relpath": "data.csv", "md5": "xyz789", "size": 500}
	]}';

	my $dir = $CLASS->parse_string($json);

	is $dir, object {
		call file_count => 1;
		call total_size => 500;
	}, 'Parses wrapped directory JSON';
};

subtest 'Handle empty and invalid data' => sub {
	is $CLASS->parse_string(''), U(), 'Empty string returns undef';
	is $CLASS->parse_string(undef), U(), 'Undef returns undef';
	is $CLASS->parse_string('invalid json'), U(), 'Invalid JSON returns undef';
	is $CLASS->parse_string('{"not": "array"}'), U(), 'Non-array/non-files object returns undef';

	is $CLASS->new(data => []), object {
		call file_count => 0;
		call total_size => 0;
	}, 'Empty array has 0 files and size';
};

subtest 'Handle files without size' => sub {
	my $json = '[
		{"relpath": "file1.txt", "md5": "abc123"},
		{"relpath": "file2.txt", "md5": "def456", "size": null}
	]';

	is $CLASS->parse_string($json), object {
		call total_size => 0;
	}, 'Handles missing/null sizes';
};

subtest 'Handle invalid entries' => sub {
	my $json = '[
		{"relpath": "file1.txt", "md5": "abc123", "size": 100},
		"not a hash",
		{"relpath": "file2.txt", "md5": "def456", "size": 200}
	]';

	is $CLASS->parse_string($json), object {
		call file_count => 2;
		call total_size => 300;
	}, 'Skips invalid entries and calculates correctly';
};

subtest 'find_files_by_pattern' => sub {
	my $json = '[
		{"relpath": "data.csv", "md5": "abc", "size": 100},
		{"relpath": "script.py", "md5": "def", "size": 200},
		{"relpath": "output.txt", "md5": "ghi", "size": 300},
		{"relpath": "data.txt", "md5": "jkl", "size": 400}
	]';

	my $dir = $CLASS->parse_string($json);

	is $dir->find_files_by_pattern(qr/\.txt$/), array {
		item object { call relpath => 'output.txt'; };
		item object { call relpath => 'data.txt'; };
		end;
	}, 'Finds 2 .txt files';

	is $dir->find_files_by_pattern(qr/\.csv$/), array {
		item object { call relpath => 'data.csv'; };
		end;
	}, 'Finds 1 .csv file';

	is $dir->find_files_by_pattern(qr/\.xyz$/), [], 'No matches returns empty array';

	is $dir->find_files_by_pattern(undef), [], 'Undef pattern returns empty array';
};

subtest 'rdf_files lazy attribute' => sub {
	my $json = '[
		{"relpath": "data.nt", "md5": "abc", "size": 100},
		{"relpath": "schema.ttl", "md5": "def", "size": 200},
		{"relpath": "output.hdt", "md5": "ghi", "size": 300},
		{"relpath": "data.csv", "md5": "jkl", "size": 400}
	]';

	is $CLASS->parse_string($json), object {
		call rdf_files => array {
			item object { call relpath => match qr/\.nt$/; };
			item object { call relpath => match qr/\.ttl$/; };
			item object { call relpath => match qr/\.hdt$/; };
			end;
		};
	}, 'Finds 3 RDF files';
};

subtest 'get_file_by_path' => sub {
	my $json = '[
		{"relpath": "file1.txt", "md5": "abc123", "size": 100},
		{"relpath": "file2.txt", "md5": "def456", "size": 200}
	]';

	my $dir = $CLASS->parse_string($json);

	my $file = $dir->get_file_by_path('file1.txt');
	is $file, object {
		call relpath => 'file1.txt';
		call md5 => 'abc123';
		call size => 100;
	}, 'Finds file by path';

	is $dir->get_file_by_path('nonexistent.txt'), U(), 'Returns undef for missing file';
	is $dir->get_file_by_path(undef), U(), 'Returns undef for undef path';
	is $dir->get_file_by_path(''), U(), 'Returns undef for empty path';
};

subtest 'Direct construction with data' => sub {
	my $data = [
		{relpath => 'test.txt', md5 => 'hash123', size => 42}
	];

	is $CLASS->new(data => $data), object {
		call file_count => 1;
		call files => array {
			item object { call relpath => 'test.txt'; };
			end;
		};
	}, 'Can construct directly with data';
};

done_testing;
