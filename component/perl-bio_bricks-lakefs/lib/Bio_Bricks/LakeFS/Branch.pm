package Bio_Bricks::LakeFS::Branch;
# ABSTRACT: Branch object for LakeFS operations

use Bio_Bricks::Common::Setup;

extends 'Bio_Bricks::LakeFS::Ref';


1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::LakeFS::Repo;

	# Create via repository factory
	my $repo = Bio_Bricks::LakeFS::Repo->new(name => 'my-repo');
	my $main = $repo->branch('main');
	my $feature = $repo->branch('feature-branch');

	# Get the lakefs:// URI
	my $uri = $main->lakefs_uri();                   # lakefs://my-repo/main
	my $uri = $feature->lakefs_uri('data/file.txt'); # lakefs://my-repo/feature-branch/data/file.txt

=head1 DESCRIPTION

Represents a branch in a LakeFS repository. Extends L<Bio_Bricks::LakeFS::Ref>
to provide branch-specific semantics. This is a simple data class that holds
repository and branch name information and can generate C<lakefs://> URIs.

=head1 INHERITS

L<Bio_Bricks::LakeFS::Ref>

=head1 ATTRIBUTES

Inherits all attributes from L<Bio_Bricks::LakeFS::Ref>:

=over 4

=item * repo - The parent L<Bio_Bricks::LakeFS::Repo> object

=item * name - The branch name

=back

=head1 METHODS

Inherits all methods from L<Bio_Bricks::LakeFS::Ref>:

=over 4

=item * lakefs_uri($path) - Get the full C<lakefs://> URI for this branch

=back

=head1 SEE ALSO

L<Bio_Bricks::LakeFS::Repo>, L<Bio_Bricks::LakeFS::Ref>

=cut
