package Bio_Bricks::LakeFS::Error;
# ABSTRACT: Structured exceptions for LakeFS operations

use v5.36;

# Define failures in this package namespace
use custom::failures qw(
	lakectl::command
	lakectl::not_found
	lakectl::exit_code
);

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::LakeFS::Error;

	# Throw structured exceptions
	Bio_Bricks::LakeFS::Error::lakectl::not_found->throw("lakectl binary not found");

	Bio_Bricks::LakeFS::Error::lakectl::command->throw({
		msg => "Command execution failed",
		payload => {
			command => \@cmd,
			stdout => $stdout,
			stderr => $stderr,
		}
	});

	# Catch and handle exceptions
	use Feature::Compat::Try;

	try {
		Bio_Bricks::LakeFS::Error::lakectl::exit_code->throw({
			msg => "lakectl command failed",
			payload => {
				command => ['lakectl', 'fs', 'stat', $path],
				exit_code => 1,
				stdout => '',
				stderr => 'Not found',
			}
		});
	} catch ($e) {
		if ($e->$_isa('failure') && ref($e) =~ /Bio_Bricks::LakeFS::Error/) {
			my $payload = $e->payload;
			warn "Command failed: @{$payload->{command}}\n";
			warn "STDERR: $payload->{stderr}\n" if $payload->{stderr};
		}
	}

=head1 DESCRIPTION

This module defines structured exceptions for LakeFS operations using the
custom::failures pragma. Other LakeFS modules can use this to throw
structured exceptions with rich context.

=head1 EXCEPTION TYPES

=head2 Bio_Bricks::LakeFS::Error::lakectl::command

Thrown when there's a general failure executing a lakectl command.

	Bio_Bricks::LakeFS::Error::lakectl::command->throw({
		msg => "Failed to execute lakectl command",
		payload => {
			command => \@cmd,
			error => $@,
			stdout => $stdout // '',
			stderr => $stderr // '',
		}
	});

=head2 Bio_Bricks::LakeFS::Error::lakectl::not_found

Thrown when the lakectl binary cannot be found in PATH or common locations.

	Bio_Bricks::LakeFS::Error::lakectl::not_found->throw(
		"lakectl not found in PATH or common locations. Please install lakectl."
	);

=head2 Bio_Bricks::LakeFS::Error::lakectl::exit_code

Thrown when lakectl returns a non-zero exit code.

	Bio_Bricks::LakeFS::Error::lakectl::exit_code->throw({
		msg => "lakectl command failed with exit code $exit_code",
		payload => {
			command => \@cmd,
			exit_code => $exit_code,
			stdout => $stdout // '',
			stderr => $stderr // '',
		}
	});

=head1 SEE ALSO

L<failures> - The underlying failure/exception framework

L<Bio_Bricks::LakeFS::Lakectl> - Main module that uses these exceptions

L<Feature::Compat::Try> - Modern try/catch syntax for exception handling

=cut
