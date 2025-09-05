#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::Common::GitHub::Auth::Provider::GhCLI';

use FindBin;
use lib "$FindBin::Bin/../lib";

subtest 'Provider attributes' => sub {
	my $provider = $CLASS->new;

	is $provider, object {
		prop blessed => $CLASS;
		call source_type => 'gh_cli';
		call name => 'gh_cli';
	}, 'GhCLI provider has correct attributes';
};

subtest 'valid() checks for gh CLI' => sub {
	my $provider = $CLASS->new;

	# valid() should return a boolean
	my $is_valid = $provider->valid;
	is($is_valid, D(), 'valid() returns defined value');

	# valid() should match _has_gh_cli
	is $provider->valid, $provider->_has_gh_cli,
		'valid() delegates to _has_gh_cli';
};

subtest '_has_gh_cli detection' => sub {
	my $provider = $CLASS->new;

	my $has_gh = $provider->_has_gh_cli;

	# Should return a boolean
	ok(defined $has_gh, '_has_gh_cli returns defined value');
	ok($has_gh == 0 || $has_gh == 1, '_has_gh_cli returns boolean');
};

subtest 'get_token returns undef if gh CLI not available' => sub {
	my $provider = $CLASS->new;

	skip_all 'gh CLI is available, cannot test unavailable case'
		if $provider->_has_gh_cli;

	is $provider->get_token, U(),
		'get_token returns undef when gh not available';
};

subtest 'get_token with gh CLI available' => sub {
	my $provider = $CLASS->new;

	skip_all 'gh CLI not available'
		unless $provider->_has_gh_cli;

	my $token = $provider->get_token;

	# Token should either be undef (not authenticated) or a valid token string
	if (defined $token) {
		ok(length($token) > 0, 'Token is non-empty');
		like($token, qr/^[a-zA-Z0-9_]+$/, 'Token matches expected pattern');
		unlike($token, qr/^\s|\s$/, 'Token is trimmed');
	} else {
		pass('get_token returns undef when gh not authenticated');
	}
};

subtest 'get_token handles errors gracefully' => sub {
	my $provider = $CLASS->new;

	# get_token should not die even if there are issues
	my $token;
	ok(lives { $token = $provider->get_token }, 'get_token does not die');

	# Should return undef or a valid token
	ok(!defined($token) || $token =~ /^[a-zA-Z0-9_]+$/,
		'Returns undef or valid token');
};

subtest 'Provider role compliance' => sub {
	my $provider = $CLASS->new;

	# Check that required role methods exist
	can_ok($provider, 'valid');
	can_ok($provider, 'get_token');
	can_ok($provider, 'source_type');
	can_ok($provider, 'name');

	# Verify role is applied
	ok($provider->DOES('Bio_Bricks::Common::GitHub::Auth::Provider'),
		'Provider consumes required role');
};

done_testing;
