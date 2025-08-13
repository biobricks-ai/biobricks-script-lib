#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::Common::GitHub::URL';

is $CLASS->new(
	url => 'https://github.com/biobricks-ai/tox21'
), object {
	call is_valid => T();
	call owner    => 'biobricks-ai';
	call repo     => 'tox21';
	call ref      => U();
	call path     => U();
}, 'Basic repository URL';

is $CLASS->new(
	url => 'https://github.com/biobricks-ai/tox21.git'
), object {
	call is_valid => T();
	call owner    => 'biobricks-ai';
	call repo     => 'tox21';
}, 'Repository URL with .git suffix is valid';

is $CLASS->new(
	url => 'https://github.com/biobricks-ai/tox21/tree/main'
), object {
	call is_valid => T();
	call owner    => 'biobricks-ai';
	call repo     => 'tox21';
	call ref      => 'main';
	call path     => U();
}, 'URL with branch is valid';

is $CLASS->new(
	url => 'https://github.com/biobricks-ai/tox21/tree/main/data/processed.parquet'
), object {
	call is_valid => T();
	call owner    => 'biobricks-ai';
	call repo     => 'tox21';
	call ref      => 'main';
	call path     => 'data/processed.parquet';
}, 'URL with branch and path is valid';

is $CLASS->new(
	url => 'https://github.com/biobricks-ai/tox21/blob/main/README.md'
), object {
	call is_valid => T();
	call ref      => 'main';
	call path     => 'README.md';
}, 'Blob URL is valid';

is $CLASS->new(
	url => 'https://github.com/biobricks-ai/tox21/commit/abc123def456'
), object {
	call is_valid => T();
	call ref      => 'abc123def456';
}, 'Commit URL is valid';

is $CLASS->new(
	url => 'https://github.com/biobricks-ai/tox21/releases/tag/v1.0.0'
), object {
	call is_valid => T();
	call ref      => 'v1.0.0';
}, 'Tag URL is valid';

is $CLASS->new(
	url => 'git@github.com:biobricks-ai/tox21.git'
), object {
	call is_valid => T();
	call owner    => 'biobricks-ai';
	call repo     => 'tox21';
}, 'SSH URL is valid';

is $CLASS->new(
	url => 'git://github.com/biobricks-ai/tox21.git'
), object {
	call is_valid => T();
	call owner    => 'biobricks-ai';
	call repo     => 'tox21';
}, 'Git protocol URL is valid';

like(
	dies { $CLASS->new( url => 'https://example.com/invalid' ) },
	qr/Invalid.*GitHub/,
	'Invalid URL correctly identified'
);

is $CLASS->new(
	url => 'https://github.com/biobricks-ai/tox21'
), object {
	call [clone_url => 'https'] => 'https://github.com/biobricks-ai/tox21.git';
	call [clone_url => 'ssh'] => 'git@github.com:biobricks-ai/tox21.git';
	call [clone_url => 'git'] => 'git://github.com/biobricks-ai/tox21.git';
	call clone_url => 'https://github.com/biobricks-ai/tox21.git';
}, 'Clone URL generation';

is $CLASS->new(
	url => 'https://github.com/biobricks-ai/tox21/tree/main/data/file.txt'
), object {
	call repo_web_url => 'https://github.com/biobricks-ai/tox21';
	call web_url => 'https://github.com/biobricks-ai/tox21/tree/main/data/file.txt';
}, 'Test web URL generation';

is $CLASS->new(
	url => 'https://github.com/biobricks-ai/tox21'
), object {
	call repo_web_url => 'https://github.com/biobricks-ai/tox21';
	call web_url => 'https://github.com/biobricks-ai/tox21';
}, 'Test web URL generation without ref/path';

is $CLASS->new(
	url => 'https://github.com/biobricks-ai/tox21'
), object {
	call api_url => 'https://api.github.com/repos/biobricks-ai/tox21';
}, 'Test API URL generation';

is $CLASS->new(
	url => 'https://github.com/biobricks-ai/tox21/blob/main/README.md'
), object {
	call raw_url => 'https://raw.githubusercontent.com/biobricks-ai/tox21/main/README.md';
	call [raw_url => 'develop', 'docs/guide.md'] => 'https://raw.githubusercontent.com/biobricks-ai/tox21/develop/docs/guide.md';
}, 'Test raw URL generation';

subtest 'Raw URL without path (should fail)' => sub {
	my $parser = $CLASS->new(
		url => 'https://github.com/biobricks-ai/tox21'
	);

	like(
		dies { $parser->raw_url },
		qr/.*/,
		'Raw URL generation fails without path'
	);
};

is $CLASS->new(
	url => 'https://github.com/biobricks-ai/tox21/tree/main/data/file.txt'
), object {
	call to_hash => hash {
		field owner => 'biobricks-ai';
		field repo  => 'tox21';
		field ref   => 'main';
		field path  => 'data/file.txt';
		field valid => T();
		etc();
	};
}, 'to_hash returns correct structure';

done_testing();
