package Bio_Bricks::Common::AWS::Paws::S3::GetObjectAttributes;
# ABSTRACT: Paws class for GetObjectAttributes API call

use Moose;

has Bucket => (is => 'ro', isa => 'Str', uri_name => 'Bucket', traits => ['ParamInURI'], required => 1);
has Key => (is => 'ro', isa => 'Str', uri_name => 'Key', traits => ['ParamInURI'], required => 1);
has ObjectAttributes => (is => 'ro', isa => 'ArrayRef[Str]', header_name => 'x-amz-object-attributes', traits => ['ParamInHeader'], required => 1);
has ExpectedBucketOwner => (is => 'ro', isa => 'Str', header_name => 'x-amz-expected-bucket-owner', traits => ['ParamInHeader']);
has MaxParts => (is => 'ro', isa => 'Int', query_name => 'max-parts', traits => ['ParamInQuery']);
has PartNumberMarker => (is => 'ro', isa => 'Int', query_name => 'part-number-marker', traits => ['ParamInQuery']);
has RequestPayer => (is => 'ro', isa => 'Str', header_name => 'x-amz-request-payer', traits => ['ParamInHeader']);
has SSECustomerAlgorithm => (is => 'ro', isa => 'Str', header_name => 'x-amz-server-side-encryption-customer-algorithm', traits => ['ParamInHeader']);
has SSECustomerKey => (is => 'ro', isa => 'Str', header_name => 'x-amz-server-side-encryption-customer-key', traits => ['ParamInHeader']);
has SSECustomerKeyMD5 => (is => 'ro', isa => 'Str', header_name => 'x-amz-server-side-encryption-customer-key-MD5', traits => ['ParamInHeader']);
has VersionId => (is => 'ro', isa => 'Str', query_name => 'versionId', traits => ['ParamInQuery']);

use MooseX::ClassAttribute;

class_has _api_call => (isa => 'Str', is => 'ro', default => 'GetObjectAttributes');
class_has _api_uri  => (isa => 'Str', is => 'ro', default => '/{Bucket}/{Key+}?attributes');
class_has _api_method  => (isa => 'Str', is => 'ro', default => 'GET');
class_has _returns => (isa => 'Str', is => 'ro', default => 'Bio_Bricks::Common::AWS::Paws::S3::GetObjectAttributesOutput');
class_has _result_key => (isa => 'Str', is => 'ro');

1;

__END__

=head1 NAME

Bio_Bricks::Common::AWS::Paws::S3::GetObjectAttributes - Arguments for GetObjectAttributes API call

=head1 DESCRIPTION

This class represents the parameters for calling the GetObjectAttributes method on S3.
GetObjectAttributes retrieves object metadata without returning the object itself.

=head1 SYNOPSIS

	my $s3 = $paws->s3;
	my $result = $s3->GetObjectAttributes(
		Bucket => 'my-bucket',
		Key => 'my-key',
		ObjectAttributes => ['ETag', 'ObjectSize'],
	);

=head1 ATTRIBUTES

=head2 B<REQUIRED> Bucket => Str

The bucket name containing the object.

=head2 B<REQUIRED> Key => Str

The object key.

=head2 B<REQUIRED> ObjectAttributes => ArrayRef[Str]

Object attributes to retrieve. Valid values: C<ETag>, C<Checksum>, C<ObjectParts>, C<StorageClass>, C<ObjectSize>

=head2 ExpectedBucketOwner => Str

The account ID of the expected bucket owner.

=head2 MaxParts => Int

Maximum number of parts to return for multipart objects.

=head2 PartNumberMarker => Int

Part number marker for pagination.

=head2 RequestPayer => Str

Confirms that requester pays for the request. Valid value: C<requester>

=head2 SSECustomerAlgorithm => Str

Server-side encryption algorithm (for customer-provided keys).

=head2 SSECustomerKey => Str

Server-side encryption key (for customer-provided keys).

=head2 SSECustomerKeyMD5 => Str

MD5 digest of the encryption key.

=head2 VersionId => Str

Version ID of the object.

=head1 SEE ALSO

L<https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObjectAttributes.html>

=cut
