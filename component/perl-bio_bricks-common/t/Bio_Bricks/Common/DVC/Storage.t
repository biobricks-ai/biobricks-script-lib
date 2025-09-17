#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::Common::DVC::Storage';

use FindBin;
use lib "$FindBin::Bin/../lib";

subtest 'Storage base class requires base_uri' => sub {
	like(
		dies { $CLASS->new() },
		qr/required/i,
		'Cannot create storage without base_uri'
	);

	is $CLASS->new(base_uri => 's3://bucket/prefix'), object {
		prop blessed => $CLASS;
		call base_uri => 's3://bucket/prefix';
	}, 'Can create with base_uri';
};

subtest 'hash_path splits hash correctly' => sub {
	my $storage = $CLASS->new(base_uri => 's3://test/bucket');

	is [$storage->hash_path('abcdef123456')], ['ab', 'cdef123456'],
		'Splits hash into prefix and suffix';

	is [$storage->hash_path('12')], ['12', ''],
		'Handles short hash';

	is $storage->hash_path(''), U(),
		'Returns undef for empty hash';

	is $storage->hash_path(undef), U(),
		'Returns undef for undef hash';
};

subtest 'Subclass methods must be implemented' => sub {
	my $storage = $CLASS->new(base_uri => 's3://test/bucket');

	like(
		dies { $storage->resolve('fake_output') },
		qr/must be implemented by subclass/,
		'resolve() dies if not implemented'
	);

	like(
		dies { $storage->head_object('s3://test/obj') },
		qr/must be implemented by subclass/,
		'head_object() dies if not implemented'
	);

	like(
		dies { $storage->get_object('s3://test/obj') },
		qr/must be implemented by subclass/,
		'get_object() dies if not implemented'
	);

	like(
		dies { $storage->object_exists('s3://test/obj') },
		qr/must be implemented by subclass/,
		'object_exists() dies if not implemented'
	);
};

done_testing;
