package Bio_Bricks::LakeFS::Repo;
# ABSTRACT: Repository object for LakeFS operations

use Bio_Bricks::Common::Setup;
use Log::Any qw($log);
use Bio_Bricks::LakeFS::Ref;
use Bio_Bricks::LakeFS::Branch;

ro name => isa => Str;

# Factory methods for creating refs and branches
method ref ($ref_name) {
	$log->debug("Creating ref object", { repo => $self->name, ref => $ref_name });
	return Bio_Bricks::LakeFS::Ref->new(
		repo => $self,
		name => $ref_name,
	);
}

method branch ($branch_name) {
	$log->debug("Creating branch object", { repo => $self->name, branch => $branch_name });
	return Bio_Bricks::LakeFS::Branch->new(
		repo => $self,
		name => $branch_name,
	);
}


# Convenience method to get the LakeFS URI
method lakefs_uri ($path = undef) {
	my $base = "lakefs://" . $self->name;
	return defined($path) ? "$base/$path" : $base;
}

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::LakeFS::Repo;

	# Create a repository object
	my $repo = Bio_Bricks::LakeFS::Repo->new(name => 'biobricks-ice-kg');

	# Create refs and branches
	my $main = $repo->branch('main');
	my $feature = $repo->branch('feature-branch');
	my $commit_ref = $repo->ref('abc123def456');

	# Get repository URI
	my $uri = $repo->lakefs_uri();           # lakefs://biobricks-ice-kg
	my $uri = $repo->lakefs_uri('data/');    # lakefs://biobricks-ice-kg/data/

=head1 DESCRIPTION

Simple data class representing a LakeFS repository.
Acts as a factory for creating L<Bio_Bricks::LakeFS::Ref> and
L<Bio_Bricks::LakeFS::Branch> objects.

=head1 ATTRIBUTES

=attr name

The repository name (required).

=head1 METHODS

=method ref($ref_name)

Create a new L<Bio_Bricks::LakeFS::Ref> object for this repository.

	my $ref = $repo->ref('abc123def456');

=method branch($branch_name)

Create a new L<Bio_Bricks::LakeFS::Branch> object for this repository.

	my $branch = $repo->branch('main');

=method lakefs_uri($path)

Get the full C<lakefs://> URI for this repository, optionally with a path.

	my $uri = $repo->lakefs_uri();        # lakefs://repo-name
	my $uri = $repo->lakefs_uri('data/'); # lakefs://repo-name/data/

=head1 SEE ALSO

L<Bio_Bricks::LakeFS::Ref>, L<Bio_Bricks::LakeFS::Branch>

=cut
