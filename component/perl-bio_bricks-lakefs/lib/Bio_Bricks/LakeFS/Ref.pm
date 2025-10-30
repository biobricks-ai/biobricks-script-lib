package Bio_Bricks::LakeFS::Ref;
# ABSTRACT: Reference (ref) object for LakeFS operations

use Bio_Bricks::Common::Setup;
with 'MooX::Log::Any';

ro repo => (
	isa => InstanceOf['Bio_Bricks::LakeFS::Repo'],
	weak_ref => 1,  # Avoid circular references
);

ro name => isa => Str;

# Get the full LakeFS URI for this ref
method lakefs_uri ($path = undef) {
	my $base = "lakefs://" . $self->repo->name . "/" . $self->name;
	return defined($path) ? "$base/$path" : $base;
}


1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::LakeFS::Repo;

	# Create via repository factory
	my $repo = Bio_Bricks::LakeFS::Repo->new(name => 'my-repo');
	my $ref = $repo->ref('abc123');

	# Get the lakefs:// URI
	my $uri = $ref->lakefs_uri();              # lakefs://my-repo/abc123
	my $uri_with_path = $ref->lakefs_uri('data/file.txt');  # lakefs://my-repo/abc123/data/file.txt

=head1 DESCRIPTION

Represents a reference (commit, tag, or branch ref) in a LakeFS repository.
This is a simple data class that holds repository and ref name information
and can generate C<lakefs://> URIs.

=head1 ATTRIBUTES

=attr repo

The parent L<Bio_Bricks::LakeFS::Repo> object (required, weak reference).

=attr name

The ref name/ID (required).

=head1 METHODS

=method lakefs_uri($path)

Get the full C<lakefs://> URI for this ref, optionally with a path.

	my $uri = $ref->lakefs_uri();           # lakefs://repo-name/ref-name
	my $uri = $ref->lakefs_uri('data/');    # lakefs://repo-name/ref-name/data/

=head1 SEE ALSO

L<Bio_Bricks::LakeFS::Repo>, L<Bio_Bricks::LakeFS::Branch>

=cut
