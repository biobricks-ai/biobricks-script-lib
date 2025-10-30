package Bio_Bricks::LakeFS::Auth::Provider::Env;
# ABSTRACT: LakeFS authentication provider from environment variables

use Bio_Bricks::Common::Setup;

with 'Bio_Bricks::LakeFS::Auth::Provider';

ro '+name' => (
	default => 'Environment Variables',
);

ro '+source_type' => (
	default => 'env',
);

method valid () {
	return defined($ENV{LAKEFS_ENDPOINT})
		&& defined($ENV{LAKEFS_ACCESS_KEY_ID})
		&& defined($ENV{LAKEFS_SECRET_ACCESS_KEY});
}

method get_credentials () {
	return unless $self->valid;

	return (
		$ENV{LAKEFS_ENDPOINT},
		$ENV{LAKEFS_ACCESS_KEY_ID},
		$ENV{LAKEFS_SECRET_ACCESS_KEY}
	);
}

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::LakeFS::Auth::Provider::Env;

	my $provider = Bio_Bricks::LakeFS::Auth::Provider::Env->new;

	if ($provider->valid) {
		my ($endpoint, $access_key_id, $secret_access_key) = $provider->get_credentials;
	}

=head1 DESCRIPTION

This provider retrieves LakeFS authentication credentials from environment variables:

=over 4

=item * C<LAKEFS_ENDPOINT> - LakeFS server endpoint URL

=item * C<LAKEFS_ACCESS_KEY_ID> - LakeFS access key ID

=item * C<LAKEFS_SECRET_ACCESS_KEY> - LakeFS secret access key

=back

All three environment variables must be set for this provider to be valid.

=cut
