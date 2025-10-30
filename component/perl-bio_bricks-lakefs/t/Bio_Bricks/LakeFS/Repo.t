#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::LakeFS::Repo';

subtest 'Repository object creation' => sub {
	is $CLASS->new(name => 'test-repo'), object {
		prop blessed => 'Bio_Bricks::LakeFS::Repo';
		call name => 'test-repo';
	}, 'Can create Repo object with name';
};

subtest 'Repository name is required' => sub {
	like(
		dies { $CLASS->new() },
		qr/required/i,
		'Dies when name is not provided'
	);
};

subtest 'Create ref from repo' => sub {
	my $repo = $CLASS->new(name => 'my-repo');
	my $ref = $repo->ref('abc123def');

	is $ref, object {
		prop blessed => 'Bio_Bricks::LakeFS::Ref';
		call name => 'abc123def';
	}, 'ref() creates Ref object';
};

subtest 'Create branch from repo' => sub {
	my $repo = $CLASS->new(name => 'my-repo');
	my $branch = $repo->branch('main');

	is $branch, object {
		prop blessed => 'Bio_Bricks::LakeFS::Branch';
		call name => 'main';
	}, 'branch() creates Branch object';
};

subtest 'lakefs_uri without path' => sub {
	my $repo = $CLASS->new(name => 'biobricks-ice-kg');
	my $uri = $repo->lakefs_uri();

	is $uri, 'lakefs://biobricks-ice-kg', 'URI without path';
};

subtest 'lakefs_uri with path' => sub {
	my $repo = $CLASS->new(name => 'biobricks-ice-kg');
	my $uri = $repo->lakefs_uri('data/file.hdt');

	is $uri, 'lakefs://biobricks-ice-kg/data/file.hdt', 'URI with path';
};

subtest 'Multiple branches from same repo' => sub {
	my $repo = $CLASS->new(name => 'multi-repo');
	my $main = $repo->branch('main');
	my $feature = $repo->branch('feature-branch');
	my $dev = $repo->branch('dev');

	is $main->name, 'main', 'Main branch created';
	is $feature->name, 'feature-branch', 'Feature branch created';
	is $dev->name, 'dev', 'Dev branch created';
};

subtest 'Multiple refs from same repo' => sub {
	my $repo = $CLASS->new(name => 'ref-repo');
	my $ref1 = $repo->ref('commit-abc123');
	my $ref2 = $repo->ref('commit-def456');

	is $ref1->name, 'commit-abc123', 'First ref created';
	is $ref2->name, 'commit-def456', 'Second ref created';
};

done_testing;
