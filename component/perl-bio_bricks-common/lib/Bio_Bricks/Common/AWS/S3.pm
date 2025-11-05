package Bio_Bricks::Common::AWS::S3;
# ABSTRACT: S3 client with simplified interface

use Bio_Bricks::Common::Setup;
use Bio_Bricks::Common::AWS::Paws;
use Bio_Bricks::Common::AWS::Paws::S3::GetObjectAttributes;
use Bio_Bricks::Common::AWS::Paws::S3::GetObjectAttributesOutput;

ro paws => isa => InstanceOf['Bio_Bricks::Common::AWS::Paws'], default => sub { Bio_Bricks::Common::AWS::Paws->new };
ro bucket => isa => Maybe[Str];

lazy _s3 => method () {
	return $self->paws->s3;
};

method head_object (%args) {
	# Use default bucket if not specified
	$args{Bucket} //= $self->bucket if $self->bucket;

	return $self->_s3->HeadObject(%args);
}

method get_object (%args) {
	# Use default bucket if not specified
	$args{Bucket} //= $self->bucket if $self->bucket;

	return $self->_s3->GetObject(%args);
}

method list_objects_v2 (%args) {
	# Use default bucket if not specified
	$args{Bucket} //= $self->bucket if $self->bucket;

	return $self->_s3->ListObjectsV2(%args);
}

method list_buckets () {
	return $self->_s3->ListBuckets;
}

method object_exists (%args) {
	eval {
		$self->head_object(%args);
		return 1;
	};

	return 0 if $@ =~ /NoSuchKey/i;
	die $@ if $@;  # Re-throw other errors
	return 1;
}

method download_object (%args) {
	my $key = delete $args{Key} or die "Key is required";
	my $file = delete $args{File} or die "File is required";

	my $result = $self->get_object(Key => $key, %args);

	if ($result->Body) {
		open my $fh, '>', $file or die "Cannot write to $file: $!";
		binmode $fh;
		print $fh $result->Body;
		close $fh;
		return 1;
	}

	return 0;
}

method get_object_attributes (%args) {
	# Use default bucket if not specified
	$args{Bucket} //= $self->bucket if $self->bucket;

	# GetObjectAttributes requires ObjectAttributes parameter
	$args{ObjectAttributes} //= ['ETag', 'ObjectSize'];

	# Call through Paws low-level API since GetObjectAttributes isn't in Paws yet
	my $call_object = $self->_s3->new_with_coercions(
		'Bio_Bricks::Common::AWS::Paws::S3::GetObjectAttributes',
		%args
	);
	return $self->_s3->caller->do_call($self->_s3, $call_object);
}

1;
