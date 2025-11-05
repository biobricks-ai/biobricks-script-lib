#!/usr/bin/env perl

use Test2::V0 -target => 'Bio_Bricks::Store::Neptune::BulkLoader';

use FindBin;
use lib "$FindBin::Bin/../lib";

# Mock Neptune instance for testing
package MockNeptune {
	use Moo;
	extends 'Bio_Bricks::Store::Neptune';

	# Override to provide a mock endpoint without requiring real config
	has '+endpoint' => (default => 'mock.neptune.amazonaws.com');
	has '+region' => (default => 'us-east-1');
}

subtest 'BulkLoader creation with required params' => sub {
	my $neptune = MockNeptune->new();

	my $loader = $CLASS->new(
		neptune => $neptune,
		iam_role => 'arn:aws:iam::123456789:role/NeptuneLoadRole',
	);

	is $loader, object {
		prop blessed => $CLASS;
		call iam_role => 'arn:aws:iam::123456789:role/NeptuneLoadRole';
	}, 'BulkLoader created with required params';
};

subtest 'Format detection from file path' => sub {
	my $neptune = MockNeptune->new();
	my $loader = $CLASS->new(
		neptune => $neptune,
		iam_role => 'arn:aws:iam::123:role/Role',
	);

	is $loader->detect_format('data/file.nt'), 'ntriples', 'Detects N-Triples';
	is $loader->detect_format('data/file.ttl'), 'turtle', 'Detects Turtle';
	is $loader->detect_format('data/file.rdf'), 'rdfxml', 'Detects RDF/XML';
	is $loader->detect_format('data/file.nq'), 'nquads', 'Detects N-Quads';
	is $loader->detect_format('data/file.hdt'), 'unsupported', 'HDT is unsupported';
	is $loader->detect_format('data/file.txt'), 'unsupported', 'Defaults to unsupported';
};

subtest 'Format detection ignores compression' => sub {
	my $neptune = MockNeptune->new();
	my $loader = $CLASS->new(
		neptune => $neptune,
		iam_role => 'arn:aws:iam::123:role/Role',
	);

	is $loader->detect_format('data/file.nt.gz'), 'ntriples', 'Detects through .gz';
	is $loader->detect_format('data/file.ttl.bz2'), 'turtle', 'Detects through .bz2';
	is $loader->detect_format('data/file.rdf.xz'), 'unsupported', 'Compression type .xz is unsupported';
};

subtest 'Build load request structure' => sub {
	my $neptune = MockNeptune->new();
	my $loader = $CLASS->new(
		neptune => $neptune,
		iam_role => 'arn:aws:iam::123:role/Role',
		region => 'us-east-1',
	);

	my $request = $loader->build_load_request(
		source_uri => 's3://my-bucket/data/file.nt',
		format => 'ntriples',
		graph_uri => 'http://example.org/graph',
	);

	is $request, hash {
		field source => 's3://my-bucket/data/file.nt';
		field format => 'ntriples';
		field iamRoleArn => 'arn:aws:iam::123:role/Role';
		field region => 'us-east-1';
		field failOnError => 'TRUE';
		field parallelism => 'MEDIUM';
		field parserConfiguration => hash {
			field namedGraphUri => 'http://example.org/graph';
			etc();
		};
		etc();
	}, 'Builds correct load request structure';
};

subtest 'Load request without graph URI' => sub {
	my $neptune = MockNeptune->new();
	my $loader = $CLASS->new(
		neptune => $neptune,
		iam_role => 'arn:aws:iam::123:role/Role',
	);

	my $request = $loader->build_load_request(
		source_uri => 's3://bucket/file.ttl',
		format => 'turtle',
	);

	ok !exists $request->{parserConfiguration}, 'No parser config without graph URI';
};

subtest 'Parallelism levels' => sub {
	my $neptune = MockNeptune->new();

	my $loader_medium = $CLASS->new(
		neptune => $neptune,
		iam_role => 'arn:aws:iam::123:role/Role',
		parallelism => 'MEDIUM',
	);

	is $loader_medium->parallelism, 'MEDIUM', 'MEDIUM parallelism set';

	my $loader_high = $CLASS->new(
		neptune => $neptune,
		iam_role => 'arn:aws:iam::123:role/Role',
		parallelism => 'HIGH',
	);

	is $loader_high->parallelism, 'HIGH', 'HIGH parallelism set';
};

subtest 'Update single cardinality setting' => sub {
	my $neptune = MockNeptune->new();

	# Test with flag disabled (default)
	my $loader_disabled = $CLASS->new(
		neptune => $neptune,
		iam_role => 'arn:aws:iam::123:role/Role',
	);

	my $request_disabled = $loader_disabled->build_load_request(
		source_uri => 's3://bucket/file.nt',
		format => 'ntriples',
	);

	ok !exists $request_disabled->{updateSingleCardinalityProperties},
		'Update single cardinality not in request by default';

	# Test with flag enabled
	my $loader_enabled = $CLASS->new(
		neptune => $neptune,
		iam_role => 'arn:aws:iam::123:role/Role',
		update_single_cardinality => 1,
	);

	my $request_enabled = $loader_enabled->build_load_request(
		source_uri => 's3://bucket/file.nt',
		format => 'ntriples',
	);

	ok exists $request_enabled->{updateSingleCardinalityProperties},
		'Update single cardinality in request when enabled';
};

subtest 'Validate format' => sub {
	my $neptune = MockNeptune->new();
	my $loader = $CLASS->new(
		neptune => $neptune,
		iam_role => 'arn:aws:iam::123:role/Role',
	);

	ok $loader->validate_format('ntriples'), 'ntriples is valid';
	ok $loader->validate_format('turtle'), 'turtle is valid';
	ok $loader->validate_format('rdfxml'), 'rdfxml is valid';
	ok $loader->validate_format('nquads'), 'nquads is valid';
	ok !$loader->validate_format('hdt'), 'hdt is invalid';
	ok !$loader->validate_format('unknown'), 'unknown is invalid';
};

subtest 'Required parameters validation' => sub {
	my $neptune = MockNeptune->new();
	my $loader = $CLASS->new(
		neptune => $neptune,
		iam_role => 'arn:aws:iam::123:role/Role',
	);

	like(
		dies { $loader->build_load_request(format => 'ntriples') },
		qr/source_uri|Undef did not pass|type constraint/i,
		'Dies when source_uri not provided'
	);

	like(
		dies { $loader->build_load_request(source_uri => 's3://bucket/file') },
		qr/format|Undef did not pass|type constraint/i,
		'Dies when format not provided'
	);
};

done_testing;
