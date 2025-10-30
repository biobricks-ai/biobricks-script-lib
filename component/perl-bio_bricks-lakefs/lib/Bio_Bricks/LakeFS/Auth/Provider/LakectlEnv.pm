package Bio_Bricks::LakeFS::Auth::Provider::LakectlEnv;
# ABSTRACT: LakeFS authentication provider from lakectl environment variables

use Bio_Bricks::Common::Setup;

with 'Bio_Bricks::LakeFS::Auth::Provider';

ro '+name' => (
	default => 'Lakectl Environment Variables',
);

ro '+source_type' => (
	default => 'lakectl_env',
);

method valid () {
	return defined($ENV{LAKECTL_SERVER_ENDPOINT_URL})
		&& defined($ENV{LAKECTL_CREDENTIALS_ACCESS_KEY_ID})
		&& defined($ENV{LAKECTL_CREDENTIALS_SECRET_ACCESS_KEY});
}

method get_credentials () {
	return unless $self->valid;

	return (
		$ENV{LAKECTL_SERVER_ENDPOINT_URL},
		$ENV{LAKECTL_CREDENTIALS_ACCESS_KEY_ID},
		$ENV{LAKECTL_CREDENTIALS_SECRET_ACCESS_KEY}
	);
}

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::LakeFS::Auth::Provider::LakectlEnv;

	my $provider = Bio_Bricks::LakeFS::Auth::Provider::LakectlEnv->new;

	if ($provider->valid) {
		my ($endpoint, $access_key_id, $secret_access_key) = $provider->get_credentials;
	}

=head1 DESCRIPTION

This provider retrieves LakeFS authentication credentials from lakectl-specific
environment variables:

=over 4

=item * C<LAKECTL_SERVER_ENDPOINT_URL> - LakeFS server endpoint URL

=item * C<LAKECTL_CREDENTIALS_ACCESS_KEY_ID> - LakeFS access key ID

=item * C<LAKECTL_CREDENTIALS_SECRET_ACCESS_KEY> - LakeFS secret access key

=back

All three environment variables must be set for this provider to be valid.
These are the same environment variables that lakectl itself uses.

=cut
