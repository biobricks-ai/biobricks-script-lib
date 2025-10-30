#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::LakeFS::Auth';
use Bio_Bricks::LakeFS::Auth::Provider::Env;

# Helper to create Auth with only Env provider (no config file reading)
sub auth_with_env_only {
	return $CLASS->new(
		providers => [Bio_Bricks::LakeFS::Auth::Provider::Env->new]
	);
}

subtest 'Basic Auth instantiation' => sub {
	is auth_with_env_only(), object {
		prop blessed => 'Bio_Bricks::LakeFS::Auth';
	}, 'Can create Auth object';
};

subtest 'get_credentials returns list' => sub {
	local $ENV{LAKEFS_ACCESS_KEY_ID} = 'test_key';
	local $ENV{LAKEFS_SECRET_ACCESS_KEY} = 'test_secret';
	local $ENV{LAKEFS_ENDPOINT} = 'http://localhost:8000';

	my $auth = auth_with_env_only();
	my ($endpoint, $access_key, $secret_key) = $auth->get_credentials;

	is $endpoint, 'http://localhost:8000', 'Got endpoint from env';
	is $access_key, 'test_key', 'Got access key from env';
	is $secret_key, 'test_secret', 'Got secret key from env';
};

subtest 'Individual accessor methods' => sub {
	local $ENV{LAKEFS_ACCESS_KEY_ID} = 'my_key';
	local $ENV{LAKEFS_SECRET_ACCESS_KEY} = 'my_secret';
	local $ENV{LAKEFS_ENDPOINT} = 'http://lakefs:8000';

	my $auth = auth_with_env_only();

	is $auth->get_endpoint, 'http://lakefs:8000', 'get_endpoint works';
	is $auth->get_access_key_id, 'my_key', 'get_access_key_id works';
	is $auth->get_secret_access_key, 'my_secret', 'get_secret_access_key works';
};

subtest 'check_auth_status' => sub {
	local $ENV{LAKEFS_ACCESS_KEY_ID} = 'status_key';
	local $ENV{LAKEFS_SECRET_ACCESS_KEY} = 'status_secret';
	local $ENV{LAKEFS_ENDPOINT} = 'http://lakefs';

	my $auth = auth_with_env_only();
	my $status = $auth->check_auth_status;

	is $status, hash {
		field has_credentials => T();
		field credentials_source => D();
		field endpoint => 'http://lakefs';
		field env_vars_set => array {
			etc();
		};
		etc();
	}, 'check_auth_status returns correct structure';
};

subtest 'No credentials available' => sub {
	local $ENV{LAKEFS_ACCESS_KEY_ID};
	local $ENV{LAKEFS_SECRET_ACCESS_KEY};
	local $ENV{LAKEFS_ENDPOINT};

	delete $ENV{LAKEFS_ACCESS_KEY_ID};
	delete $ENV{LAKEFS_SECRET_ACCESS_KEY};
	delete $ENV{LAKEFS_ENDPOINT};

	my $auth = auth_with_env_only();
	my ($endpoint, $access_key, $secret_key) = $auth->get_credentials;

	is $endpoint, undef, 'No endpoint without env vars';
	is $access_key, undef, 'No access key without env vars';
	is $secret_key, undef, 'No secret key without env vars';
};

subtest 'Credential caching' => sub {
	local $ENV{LAKEFS_ACCESS_KEY_ID} = 'cached_key';
	local $ENV{LAKEFS_SECRET_ACCESS_KEY} = 'cached_secret';
	local $ENV{LAKEFS_ENDPOINT} = 'http://cached';

	my $auth = auth_with_env_only();
	my ($e1, $k1, $s1) = $auth->get_credentials;

	# Change env vars
	$ENV{LAKEFS_ACCESS_KEY_ID} = 'new_key';

	# Should still get cached credentials
	my ($e2, $k2, $s2) = $auth->get_credentials;
	is $k2, 'cached_key', 'Credentials are cached';

	# Clear cache and get new credentials
	$auth->clear_cache;
	my ($e3, $k3, $s3) = $auth->get_credentials;
	is $k3, 'new_key', 'Cache cleared, new credentials retrieved';
};

subtest 'Skip specific providers' => sub {
	local $ENV{LAKEFS_ACCESS_KEY_ID} = 'env_key';
	local $ENV{LAKEFS_SECRET_ACCESS_KEY} = 'env_secret';
	local $ENV{LAKEFS_ENDPOINT} = 'http://env';

	my $auth = auth_with_env_only();

	# With only Env provider, skip_env should result in no credentials
	my ($e1, $k1, $s1) = $auth->get_credentials(skip_env => 1);
	is $k1, undef, 'No credentials when env provider skipped';

	# Normal call should work
	my ($e2, $k2, $s2) = $auth->get_credentials;
	is $k2, 'env_key', 'Gets credentials from env when not skipped';
};

subtest 'Force refresh credentials' => sub {
	local $ENV{LAKEFS_ACCESS_KEY_ID} = 'refresh_key';
	local $ENV{LAKEFS_SECRET_ACCESS_KEY} = 'refresh_secret';
	local $ENV{LAKEFS_ENDPOINT} = 'http://refresh';

	my $auth = auth_with_env_only();
	my ($e1, $k1, $s1) = $auth->get_credentials;

	# Change env
	$ENV{LAKEFS_ACCESS_KEY_ID} = 'refreshed_key';

	# Force refresh
	my ($e2, $k2, $s2) = $auth->get_credentials(refresh => 1);
	is $k2, 'refreshed_key', 'Forced refresh gets new credentials';
};

subtest 'Provider chain with only Env' => sub {
	my $auth = auth_with_env_only();
	my $providers = $auth->providers;

	is scalar(@$providers), 1, 'Has exactly one provider';

	my $has_env_provider = grep { ref($_) =~ /Env/ } @$providers;
	ok $has_env_provider, 'Provider is Env provider';
};

done_testing;
