package Bio_Bricks::Common::AWS::Paws::S3::GetObjectAttributesOutput;
# ABSTRACT: Response from GetObjectAttributes API call

use Moose;

has Checksum => (is => 'ro', isa => 'HashRef');
has DeleteMarker => (is => 'ro', isa => 'Bool', header_name => 'x-amz-delete-marker', traits => ['ParamInHeader']);
has ETag => (is => 'ro', isa => 'Str', header_name => 'ETag', traits => ['ParamInHeader']);
has LastModified => (is => 'ro', isa => 'Str', header_name => 'Last-Modified', traits => ['ParamInHeader']);
has ObjectParts => (is => 'ro', isa => 'HashRef');
has ObjectSize => (is => 'ro', isa => 'Int');
has RequestCharged => (is => 'ro', isa => 'Str', header_name => 'x-amz-request-charged', traits => ['ParamInHeader']);
has StorageClass => (is => 'ro', isa => 'Str');
has VersionId => (is => 'ro', isa => 'Str', header_name => 'x-amz-version-id', traits => ['ParamInHeader']);

has _request_id => (is => 'ro', isa => 'Str');

1;

__END__

=head1 NAME

Bio_Bricks::Common::AWS::Paws::S3::GetObjectAttributesOutput - Response from GetObjectAttributes

=head1 DESCRIPTION

This class represents the response from GetObjectAttributes API call.

=head1 ATTRIBUTES

=head2 Checksum => HashRef

Checksum of the object. Contains keys like C<ChecksumCRC32>, C<ChecksumCRC32C>, C<ChecksumSHA1>, C<ChecksumSHA256>.

=head2 DeleteMarker => Bool

Whether the object is a delete marker (versioned buckets).

=head2 ETag => Str

Entity tag of the object.

=head2 LastModified => Str

Date and time when object was last modified.

=head2 ObjectParts => HashRef

Multipart upload information. Contains:
- C<IsTruncated> (Bool)
- C<MaxParts> (Int)
- C<NextPartNumberMarker> (Int)
- C<PartNumberMarker> (Int)
- C<Parts> (ArrayRef) - each part has C<PartNumber>, C<Size>, C<ChecksumCRC32>, etc.
- C<PartsCount> (Int)

=head2 ObjectSize => Int

Size of the object in bytes.

=head2 RequestCharged => Str

If present, indicates requester was charged for the request.

=head2 StorageClass => Str

Storage class of the object.

=head2 VersionId => Str

Version ID of the object (versioned buckets).

=head1 SEE ALSO

L<https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObjectAttributes.html>

=cut
