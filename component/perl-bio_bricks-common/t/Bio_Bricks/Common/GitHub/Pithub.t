#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::Common::GitHub::Pithub';
use Test2::Require::Module 'Pithub';

is $CLASS->new, object {
	prop blessed => 'Bio_Bricks::Common::GitHub::Pithub';
}, 'Basic GitHub::Pithub creation';

subtest 'Token injection from environment' => sub {
	local $ENV{GITHUB_TOKEN} = 'test_token_from_env';

	my $pithub = $CLASS->new;
	is($pithub->token, 'test_token_from_env', 'Token injected from environment');
};

subtest 'Explicit token overrides environment' => sub {
	local $ENV{GITHUB_TOKEN} = 'env_token';

	my $pithub = $CLASS->new(token => 'explicit_token');
	is($pithub->token, 'explicit_token', 'Explicit token takes precedence');
};

subtest 'Works without token' => sub {
	delete local $ENV{GITHUB_TOKEN};
	delete local $ENV{GH_TOKEN};
	delete local $ENV{GITHUB_ACCESS_TOKEN};

	my $pithub = $CLASS->new;
	is($pithub, object {
		prop blessed => 'Bio_Bricks::Common::GitHub::Pithub';
	}, 'Can create instance without token');
};

subtest 'Inherits from Pithub' => sub {
	my $pithub = $CLASS->new;
	ok($pithub->isa('Pithub'), 'Instance isa Pithub');
	ok($pithub->can('repos'), 'Has repos method from Pithub');
	ok($pithub->can('users'), 'Has users method from Pithub');
	ok($pithub->can('issues'), 'Has issues method from Pithub');
};

subtest 'Child instances inherit token' => sub {
	local $ENV{GITHUB_TOKEN} = 'parent_token';

	my $pithub = $CLASS->new;

	my $repos = $pithub->repos;
	is($repos->token, 'parent_token', 'Child repos instance inherits token');

	my $users = $pithub->users;
	is($users->token, 'parent_token', 'Child users instance inherits token');
};

done_testing;
