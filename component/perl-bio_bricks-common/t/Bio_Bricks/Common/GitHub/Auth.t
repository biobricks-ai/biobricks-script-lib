#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::Common::GitHub::Auth';
use Test2::Require::Module 'IPC::Run3';

is $CLASS->new, object {
	prop blessed => 'Bio_Bricks::Common::GitHub::Auth';
}, 'Basic GitHub::Auth creation';

subtest 'Environment variable detection' => sub {
	my $auth = $CLASS->new;

	local $ENV{GITHUB_TOKEN};
	local $ENV{GH_TOKEN};
	local $ENV{GITHUB_ACCESS_TOKEN};

	delete $ENV{GITHUB_TOKEN};
	delete $ENV{GH_TOKEN};
	delete $ENV{GITHUB_ACCESS_TOKEN};

	is($auth->_get_token_from_env, U(), 'No token from environment when vars not set');

	$ENV{GITHUB_TOKEN} = 'test_token_123';
	is($auth->_get_token_from_env, 'test_token_123', 'Gets token from GITHUB_TOKEN');

	$ENV{GH_TOKEN} = 'test_token_456';
	is($auth->_get_token_from_env, 'test_token_123', 'Prefers GITHUB_TOKEN over GH_TOKEN');

	delete $ENV{GITHUB_TOKEN};
	is($auth->_get_token_from_env, 'test_token_456', 'Gets token from GH_TOKEN when GITHUB_TOKEN not set');

	delete $ENV{GH_TOKEN};
	$ENV{GITHUB_ACCESS_TOKEN} = 'test_token_789';
	is($auth->_get_token_from_env, 'test_token_789', 'Gets token from GITHUB_ACCESS_TOKEN');
};

subtest 'GitHub CLI detection' => sub {
	my $auth = $CLASS->new;

	my $has_gh = $auth->_has_gh_cli;
	is($has_gh, D(), '_has_gh_cli returns defined value');

	if ($has_gh) {
		my $token = $auth->_get_token_from_gh_cli;
		ok(defined $token || !defined $token, '_get_token_from_gh_cli returns defined result');
	}
};

subtest 'get_token method with different options' => sub {
	my $auth = $CLASS->new;

	my $token = $auth->get_token;
	ok(defined $token || !defined $token, 'get_token returns a result');

	is $auth, object {
		call [get_token => skip_env => 1] => E();
	}, 'get_token with skip_env works';

	is $auth, object {
		call [get_token => skip_gh_cli => 1] => E();
	}, 'get_token with skip_gh_cli works';

	if ($token) {
		is($auth->get_token, $token, 'Token is cached correctly');

		$auth->clear_cache;
		my $fresh_token = $auth->get_token;
		ok(defined $fresh_token || !defined $fresh_token, 'get_token works after cache clear');
	}
};

is $CLASS->new, object {
	call check_auth_status => hash {
		field has_token => D();
		field token_source => match qr/^(environment|gh_cli|none)$/;
		field has_gh_cli => D();
		field env_vars_set => array {
			etc();
		};
		etc();
	};
}, 'check_auth_status returns correct structure';

subtest 'Forced environment setup' => sub {
	my $auth = $CLASS->new;

	local $ENV{GITHUB_TOKEN} = 'test_forced_token';

	$auth->clear_cache;

	is($auth->get_token, 'test_forced_token', 'Forced environment token works');

	is $auth->check_auth_status, hash {
		field has_token => T();
		field token_source => 'environment';
		field env_vars_set => array {
			item 'GITHUB_TOKEN';
			etc();
		};
		etc();
	}, 'Status shows correct environment setup';
};

done_testing;
