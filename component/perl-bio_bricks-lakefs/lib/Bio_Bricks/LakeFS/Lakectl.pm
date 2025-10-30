package Bio_Bricks::LakeFS::Lakectl;
# ABSTRACT: LakeFS lakectl command-line interface wrapper

use Bio_Bricks::Common::Setup;
use Log::Any qw($log);
use IPC::Run3;
use File::Which qw(which);
use Bio_Bricks::LakeFS::Error;
use Bio_Bricks::LakeFS::Auth;

lazy auth => sub {
	Bio_Bricks::LakeFS::Auth->new;
}, isa => InstanceOf['Bio_Bricks::LakeFS::Auth'];

lazy lakectl_path => method () {
	# Check if lakectl is in PATH
	my $path = which('lakectl');
	return $path if defined $path;

	# Check common installation locations
	my @common_paths = (
		'/usr/local/bin/lakectl',
		'/usr/bin/lakectl',
		'/opt/lakefs/lakectl',
		path($ENV{HOME}, '.local', 'bin', 'lakectl')->stringify,
	);

	for my $path (@common_paths) {
		return $path if -x $path;
	}

	Bio_Bricks::LakeFS::Error::lakectl::not_found->throw("lakectl not found in PATH or common locations. Please install lakectl.");
}, isa => Str;

ro verbose => isa => Bool, default => 0;

lazy _env => method () {
	my ($endpoint, $access_key_id, $secret_access_key) = $self->auth->get_credentials;

	return unless $endpoint && $access_key_id && $secret_access_key;

	return {
		LAKECTL_SERVER_ENDPOINT_URL => $endpoint,
		LAKECTL_CREDENTIALS_ACCESS_KEY_ID => $access_key_id,
		LAKECTL_CREDENTIALS_SECRET_ACCESS_KEY => $secret_access_key,
	};
}, isa => Maybe[Dict[
	LAKECTL_SERVER_ENDPOINT_URL => Str,
	LAKECTL_CREDENTIALS_ACCESS_KEY_ID => Str,
	LAKECTL_CREDENTIALS_SECRET_ACCESS_KEY => Str,
]];

# Helper to get LakeFS URI from object or string
method _get_lakefs_uri ($obj_or_string) {
	if (ref($obj_or_string) && $obj_or_string->can('lakefs_uri')) {
		return $obj_or_string->lakefs_uri;
	}
	return $obj_or_string;
}

method _run_command ($args, %options) {
	my @cmd = ($self->lakectl_path, @$args);

	$log->debug("Executing lakectl command", { command => \@cmd });
	warn "Running: @cmd\n" if $self->verbose;

	my ($stdout, $stderr);
	my $stdin = $options{stdin};

	# Build environment with auth credentials
	my %env = %ENV;
	if ($self->_env) {
		%env = (%env, %{$self->_env});
	}

	# Set LAKECTL_INTERACTIVE=false to ensure consistent TSV output
	$env{LAKECTL_INTERACTIVE} = 'false';

	local %ENV = %env;

	eval {
		run3(\@cmd, \$stdin, \$stdout, \$stderr);
	};

	if ($@) {
		my $payload = {
			command => \@cmd,
			error => $@,
			stdout => $stdout // '',
			stderr => $stderr // '',
		};
		$log->error("lakectl command execution failed", $payload);
		Bio_Bricks::LakeFS::Error::lakectl::command->throw({
			msg => "Failed to execute lakectl command",
			payload => $payload,
		});
	}

	if ($? != 0) {
		my $exit_code = $? >> 8;
		my $payload = {
			command => \@cmd,
			exit_code => $exit_code,
			stdout => $stdout // '',
			stderr => $stderr // '',
		};
		$log->error("lakectl command failed with non-zero exit code", $payload);
		Bio_Bricks::LakeFS::Error::lakectl::exit_code->throw({
			msg => "lakectl command failed with exit code $exit_code",
			payload => $payload,
		});
	}

	$log->debug("lakectl command completed successfully", {
		command => \@cmd,
		stdout_length => length($stdout // ''),
		stderr_length => length($stderr // '')
	});

	warn "Output: $stdout\n" if $self->verbose && $stdout;
	warn "Errors: $stderr\n" if $self->verbose && $stderr;

	return $stdout;
}

# Object operations
method upload ($source, $destination, %options) {
	my @args = ('fs', 'upload');

	push @args, '--source', $source;
	push @args, '--recursive' if $options{recursive};
	push @args, '--content-type', $options{content_type} if $options{content_type};
	push @args, $destination;

	return $self->_run_command(\@args);
}

method download ($source, $destination, %options) {
	my @args = ('fs', 'download');

	push @args, '--recursive' if $options{recursive};
	push @args, $source;
	push @args, '--output', $destination if $destination ne '-';

	return $self->_run_command(\@args);
}

method copy ($source, $destination, %options) {
	my @args = ('fs', 'cp');

	push @args, '--recursive' if $options{recursive};
	push @args, $source, $destination;

	return $self->_run_command(\@args);
}

method move ($source, $destination) {
	my @args = ('fs', 'mv', $source, $destination);
	return $self->_run_command(\@args);
}

method remove ($path, %options) {
	my @args = ('fs', 'rm');

	push @args, '--recursive' if $options{recursive};
	push @args, $path;

	return $self->_run_command(\@args);
}

method list ($path, %options) {
	my @args = ('fs', 'ls');

	push @args, '--recursive' if $options{recursive};
	push @args, $path if $path;

	my $output = $self->_run_command(\@args);

	# Parse output if requested
	if ($options{parse}) {
		my @objects;
		for my $line (split /\n/, $output) {
			next if $line !~ /\S/;

			# Handle recursive output format: "object timestamp size path"
			if ($options{recursive} && $line =~ /^object\s+(.+?)\s+([\d.]+\s+\w+)\s+(.+)$/) {
				my ($timestamp, $size_str, $file_path) = ($1, $2, $3);
				push @objects, {
					type => 'object',
					timestamp => $timestamp,
					human_size => $size_str,
					path => $file_path
				};
			}
			# Handle non-recursive output: "common_prefix path"
			elsif ($line =~ /^(common_prefix|object)\s+(.+)$/) {
				push @objects, {
					type => $1,
					path => $2
				};
			}
		}
		return \@objects;
	}

	return $output;
}

method stat ($path) {
	my @args = ('fs', 'stat', $path);
	my $output = $self->_run_command(\@args);

	# Parse the text output into a hash structure
	my %stat_info;
	for my $line (split /\n/, $output) {
		if ($line =~ /^Path:\s+(.+)$/) {
			$stat_info{path} = $1;
		} elsif ($line =~ /^Modified Time:\s+(.+)$/) {
			$stat_info{modified_time} = $1;
		} elsif ($line =~ /^Size:\s+(\d+)/) {
			$stat_info{size} = $1;
		} elsif ($line =~ /^Human Size:\s+(.+)$/) {
			$stat_info{human_size} = $1;
		} elsif ($line =~ /^Physical Address:\s+(.+)$/) {
			$stat_info{physical_address} = $1;
		} elsif ($line =~ /^Checksum:\s+(\S+)/) {
			$stat_info{checksum} = $1;
		} elsif ($line =~ /^Content[-\s]?Type:\s+(.+)$/i) {
			$stat_info{content_type} = $1;
		}
	}

	return \%stat_info;
}

# Repository operations
method list_repos (%options) {
	my @args = ('repo', 'list');
	my $output = $self->_run_command(\@args);

	# Parse TSV output if requested
	if ($options{parse}) {
		my @repos;
		for my $line (split /\n/, $output) {
			next if $line !~ /\S/;

			# TSV format matches table headers: REPOSITORY, CREATION DATE, DEFAULT REF NAME, STORAGE ID, STORAGE NAMESPACE
			my @fields = split /\t/, $line;
			if (@fields >= 5) {
				push @repos, {
					repository => $fields[0],
					creation_date => $fields[1],
					default_ref_name => $fields[2],
					storage_id => $fields[3],
					storage_namespace => $fields[4]
				};
			}
		}
		return \@repos;
	}

	return $output;
}

method create_repo ($name, $storage_namespace, %options) {
	my @args = ('repo', 'create', $name, $storage_namespace);

	push @args, '--default-branch', $options{default_branch} if $options{default_branch};

	return $self->_run_command(\@args);
}

method delete_repo ($name) {
	my @args = ('repo', 'delete', $name, '--yes');
	return $self->_run_command(\@args);
}

# Branch operations
method list_branches ($repository, %options) {
	my $repo_uri = $self->_get_lakefs_uri($repository);
	my @args = ('branch', 'list', $repo_uri);
	my $output = $self->_run_command(\@args);

	# Parse TSV output when not connected to TTY (no headers, just TSV data)
	if ($options{parse}) {
		my @branches;
		for my $line (split /\n/, $output) {
			next if $line !~ /\S/;

			# TSV format matches table headers: BRANCH<TAB>COMMIT ID
			my @fields = split /\t/, $line;

			if (@fields >= 2) {
				push @branches, {
					id => $fields[0],
					commit_id => $fields[1]
				};
			}
		}
		return \@branches;
	}

	return $output;
}

method create_branch ($branch, $source) {
	my $branch_uri = $self->_get_lakefs_uri($branch);
	my $source_uri = $self->_get_lakefs_uri($source);

	my @args = ('branch', 'create', $branch_uri, '--source', $source_uri);
	return $self->_run_command(\@args);
}

method delete_branch ($branch) {
	my $branch_uri = $self->_get_lakefs_uri($branch);

	my @args = ('branch', 'delete', $branch_uri, '--yes');
	return $self->_run_command(\@args);
}

# Commit operations
method commit ($branch, $message, %options) {
	my $branch_uri = $self->_get_lakefs_uri($branch);
	my @args = ('commit', $branch_uri, '--message', $message);

	if ($options{metadata}) {
		for my $key (keys %{$options{metadata}}) {
			push @args, '--meta', "$key=$options{metadata}{$key}";
		}
	}

	return $self->_run_command(\@args);
}

method log ($ref, %options) {
	my $ref_uri = $self->_get_lakefs_uri($ref);
	my @args = ('log', $ref_uri);

	push @args, '--amount', $options{amount} if $options{amount};
	push @args, '--after', $options{after} if $options{after};

	return $self->_run_command(\@args);
}

# Diff operations
method diff ($left_ref, $right_ref, %options) {
	my $left_uri = $self->_get_lakefs_uri($left_ref);
	my $right_uri = $self->_get_lakefs_uri($right_ref);
	my @args = ('diff', $left_uri, $right_uri);

	push @args, '--prefix', $options{prefix} if $options{prefix};

	return $self->_run_command(\@args);
}

# Merge operations
method merge ($source, $destination, %options) {
	my $source_uri = $self->_get_lakefs_uri($source);
	my $dest_uri = $self->_get_lakefs_uri($destination);
	my @args = ('merge', $source_uri, $dest_uri);

	push @args, '--message', $options{message} if $options{message};
	push @args, '--strategy', $options{strategy} if $options{strategy};

	return $self->_run_command(\@args);
}

# Import/Export operations
method import_data ($source, $destination, %options) {
	my @args = ('import');

	push @args, '--from', $source;
	push @args, '--to', $destination;
	push @args, '--message', $options{message} if $options{message};

	return $self->_run_command(\@args);
}

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::LakeFS::Lakectl;

	# Create client (uses Auth module for credentials)
	my $lakectl = Bio_Bricks::LakeFS::Lakectl->new();

	# Or with custom auth
	my $auth = Bio_Bricks::LakeFS::Auth->new();
	my $lakectl = Bio_Bricks::LakeFS::Lakectl->new(auth => $auth);

	# Upload files (optimized for large files)
	$lakectl->upload('/local/path/file.hdt', 'lakefs://repo/branch/path/file.hdt');
	$lakectl->upload('/local/dir/', 'lakefs://repo/branch/path/', recursive => 1);

	# Download files
	$lakectl->download('lakefs://repo/branch/path/file.hdt', '/local/path/file.hdt');

	# List objects
	my $objects = $lakectl->list('lakefs://repo/branch/path/');

	# Repository operations
	$lakectl->create_repo('my-repo', 's3://my-bucket/path');
	my $repos = $lakectl->list_repos();

	# Branch operations
	$lakectl->create_branch('my-repo', 'feature', 'main');
	my $branches = $lakectl->list_branches('my-repo');

	# Commit changes
	$lakectl->commit('my-repo', 'branch', 'Added RDF files',
		metadata => { source => 'biobricks', rev => 'abc123' }
	);

	# View history
	my $commits = $lakectl->log('my-repo', 'main', amount => 10);

=head1 DESCRIPTION

LakeFS client using the lakectl CLI tool for operations that benefit from its
optimized handling, especially for large file uploads and downloads. This module
provides a Perl wrapper around lakectl with proper authentication handling via
the Bio_Bricks::LakeFS::Auth module.

Key advantages over HTTP API:
- Optimized chunked uploads for large files
- Progress reporting for long operations
- Resume capability for interrupted transfers
- Streaming operations without loading entire files into memory

=head1 ENVIRONMENT

The module sets the following environment variables for lakectl authentication:

=over 4

=item LAKECTL_SERVER_ENDPOINT_URL

=item LAKECTL_CREDENTIALS_ACCESS_KEY_ID

=item LAKECTL_CREDENTIALS_SECRET_ACCESS_KEY

=back

These are automatically populated from the Auth module's credential providers.

=cut
