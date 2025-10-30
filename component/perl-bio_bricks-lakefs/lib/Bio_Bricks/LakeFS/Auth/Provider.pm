package Bio_Bricks::LakeFS::Auth::Provider;
# ABSTRACT: Base role for LakeFS authentication providers

use Bio_Bricks::Common::Setup ':role';

requires 'valid';
requires 'get_credentials';

ro name => isa => Str;

ro source_type => isa => Str;

1;

__END__

=head1 SYNOPSIS

	package Bio_Bricks::LakeFS::Auth::Provider::MyProvider;
	use Moo;
	with 'Bio_Bricks::LakeFS::Auth::Provider';

	sub valid {
		# Return true if this provider can provide credentials
	}

	sub get_credentials {
		# Return ($endpoint, $access_key_id, $secret_access_key)
	}

=head1 DESCRIPTION

Base role for LakeFS authentication providers. All providers must implement
C<valid> and C<get_credentials> methods.

=cut
