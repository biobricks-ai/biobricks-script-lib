#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::LakeFS::Branch';

use FindBin;
use lib "$FindBin::Bin/../lib";
use Bio_Bricks::LakeFS::Repo;

subtest 'Branch creation via repo factory' => sub {
	my $repo = Bio_Bricks::LakeFS::Repo->new(name => 'test-repo');
	my $branch = $repo->branch('feature-branch');

	is $branch, object {
		prop blessed => $CLASS;
		call name => 'feature-branch';
	}, 'Branch created via repo factory method';
};

subtest 'Branch extends Ref' => sub {
	my $repo = Bio_Bricks::LakeFS::Repo->new(name => 'test-repo');
	my $branch = $repo->branch('main');

	isa_ok $branch, 'Bio_Bricks::LakeFS::Ref';
	isa_ok $branch, $CLASS;
};

subtest 'Branch requires repo parameter' => sub {
	like(
		dies { $CLASS->new(name => 'branch') },
		qr/required/i,
		'Dies when repo is not provided'
	);
};

subtest 'Branch requires name parameter' => sub {
	my $repo = Bio_Bricks::LakeFS::Repo->new(name => 'test-repo');

	like(
		dies { $CLASS->new(repo => $repo) },
		qr/required/i,
		'Dies when name is not provided'
	);
};

subtest 'Branch has lakefs_uri method' => sub {
	my $repo = Bio_Bricks::LakeFS::Repo->new(name => 'my-repo');
	my $branch = $repo->branch('dev');

	is $branch->lakefs_uri(), 'lakefs://my-repo/dev', 'URI without path';
	is $branch->lakefs_uri('data/file.txt'), 'lakefs://my-repo/dev/data/file.txt', 'URI with path';
};

subtest 'Branch has repo reference' => sub {
	my $repo = Bio_Bricks::LakeFS::Repo->new(name => 'biobricks-kg');
	my $branch = $repo->branch('main');

	is $branch->repo, object {
		prop blessed => 'Bio_Bricks::LakeFS::Repo';
		call name => 'biobricks-kg';
	}, 'Branch has reference to repo';
};

subtest 'Multiple branches have same repo' => sub {
	my $repo = Bio_Bricks::LakeFS::Repo->new(name => 'shared-repo');
	my $main = $repo->branch('main');
	my $feature = $repo->branch('feature');

	is $main->repo->name, 'shared-repo', 'Main branch has correct repo';
	is $feature->repo->name, 'shared-repo', 'Feature branch has correct repo';
};

done_testing;
