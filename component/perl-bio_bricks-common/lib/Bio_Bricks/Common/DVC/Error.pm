package Bio_Bricks::Common::DVC::Error;
# ABSTRACT: Structured exceptions for DVC operations

use v5.36;

# Define failures in this package namespace
use custom::failures qw(
	storage::fetch
	storage::parse
	directory::parse
	directory::not_found
	lock::parse
);

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::Common::DVC::Error;

	# Throw structured exceptions
	Bio_Bricks::Common::DVC::Error::storage::fetch->throw({
		msg => "Failed to fetch object from storage",
		payload => {
			backend => 'S3',
			bucket => $bucket,
			key => $key,
			error => $error,
		}
	});

	Bio_Bricks::Common::DVC::Error::directory::not_found->throw({
		msg => "Directory metadata not found",
		payload => {
			path => $path,
			md5 => $md5,
		}
	});

	# Catch and handle exceptions
	use Feature::Compat::Try;

	try {
		$storage->fetch_directory($output);
	} catch ($e) {
		if ($e->$_isa('failure') && $e->$_isa('Bio_Bricks::Common::DVC::Error::storage::fetch')) {
			my $payload = $e->payload;
			warn "Failed to fetch from storage: $payload->{error}\n";
		}
	}

=head1 DESCRIPTION

This module defines structured exceptions for DVC operations using the
custom::failures pragma. DVC modules can use this to throw structured
exceptions with rich context, avoiding verbose stacktraces.

=head1 EXCEPTION TYPES

=head2 Bio_Bricks::Common::DVC::Error::storage::fetch

Thrown when there's a failure fetching an object from storage (S3, local, etc.).

	Bio_Bricks::Common::DVC::Error::storage::fetch->throw({
		msg => "Storage error fetching directory",
		payload => {
			backend => 'S3',
			bucket => 'my-bucket',
			key => 'path/to/file.dir',
			error => 'Not Found',
		}
	});

=head2 Bio_Bricks::Common::DVC::Error::storage::parse

Thrown when storage response cannot be parsed.

	Bio_Bricks::Common::DVC::Error::storage::parse->throw({
		msg => "Failed to parse storage response",
		payload => {
			backend => 'S3',
			content => $content,
			error => $@,
		}
	});

=head2 Bio_Bricks::Common::DVC::Error::directory::parse

Thrown when directory JSON cannot be parsed.

	Bio_Bricks::Common::DVC::Error::directory::parse->throw({
		msg => "Failed to parse directory metadata",
		payload => {
			path => $path,
			content => $json_content,
			error => $@,
		}
	});

=head2 Bio_Bricks::Common::DVC::Error::directory::not_found

Thrown when directory metadata file is not found in storage.

	Bio_Bricks::Common::DVC::Error::directory::not_found->throw({
		msg => "Directory metadata not found",
		payload => {
			path => $path,
			bucket => $bucket,
			key => $key,
		}
	});

=head2 Bio_Bricks::Common::DVC::Error::lock::parse

Thrown when DVC lock file cannot be parsed.

	Bio_Bricks::Common::DVC::Error::lock::parse->throw({
		msg => "Failed to parse dvc.lock file",
		payload => {
			content => $content,
			error => $@,
		}
	});

=head1 SEE ALSO

L<failures> - The underlying failure/exception framework

L<Bio_Bricks::Common::DVC::Storage::S3> - S3 storage backend that uses these exceptions

L<Feature::Compat::Try> - Modern try/catch syntax for exception handling

=cut
