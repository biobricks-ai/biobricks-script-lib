package Bio_Bricks::Common::Rclone::Runner;
# ABSTRACT: Rclone command execution wrapper

use Bio_Bricks::Common::Setup;
use IPC::Run3;
use Log::Any qw($log);

has rclone_path => (
	is => 'ro',
	isa => Str,
	required => 1,
);

has config_dir => (
	is => 'ro',
	isa => Str,
	required => 1,
);

has verbose => (
	is => 'ro',
	isa => Bool,
	default => 0,
);

has default_flags => (
	is => 'ro',
	isa => ArrayRef[Str],
	default => sub { ['--config-dir'] },
);

method _run_command ($args, %options) {
	my @cmd = ($self->rclone_path);

	# Add config file path (not config-dir)
	my $config_file = path($self->config_dir, 'rclone.conf');
	push @cmd, '--config', $config_file->stringify;

	# Add common flags
	push @cmd, '--verbose' if $self->verbose;

	# Add command-specific args
	push @cmd, @$args;

	# Add JSON flag if requested
	push @cmd, '--json' if $options{json};

	$log->debug("Executing rclone command", {
		full_command => \@cmd,
		args_passed => $args,
		options => \%options
	});

	warn "Running: @cmd\n" if $self->verbose;

	my ($stdout, $stderr);
	my $stdin = $options{stdin};

	eval {
		run3(\@cmd, \$stdin, \$stdout, \$stderr);
	};

	if ($@) {
		croak "Failed to run rclone: $@";
	}

	if ($? != 0) {
		my $exit_code = $? >> 8;
		$log->error("rclone command failed", {
			command => \@cmd,
			exit_code => $exit_code,
			stdout => $stdout,
			stderr => $stderr
		});
		croak "rclone failed with exit code $exit_code: $stderr";
	}

	warn "Output: $stdout\n" if $self->verbose && $stdout;
	warn "Errors: $stderr\n" if $self->verbose && $stderr;

	if ($options{json} && $stdout) {
		return JSON::PP->new->utf8->decode($stdout);
	}

	return $stdout;
}

# File transfer operations
method sync ($source, $destination, %options) {
	my @args = ('sync', $source, $destination);

	push @args, '--dry-run' if $options{dry_run};
	push @args, '--progress' if $options{progress};
	push @args, '--checksum' if $options{checksum};
	push @args, '--ignore-times' if $options{ignore_times};
	push @args, '--delete-excluded' if $options{delete_excluded};

	if ($options{filters}) {
		for my $filter (@{$options{filters}}) {
			push @args, '--filter', $filter;
		}
	}

	if ($options{bwlimit}) {
		push @args, '--bwlimit', $options{bwlimit};
	}

	return $self->_run_command(\@args);
}

method copy ($source, $destination, %options) {
	my @args = ('copy', $source, $destination);

	push @args, '--dry-run' if $options{dry_run};
	push @args, '--progress' if $options{progress};
	push @args, '--checksum' if $options{checksum};
	push @args, '--ignore-times' if $options{ignore_times};

	if ($options{filters}) {
		for my $filter (@{$options{filters}}) {
			push @args, '--filter', $filter;
		}
	}

	if ($options{bwlimit}) {
		push @args, '--bwlimit', $options{bwlimit};
	}

	return $self->_run_command(\@args);
}

method copyto ($source, $destination, %options) {
	my @args = ('copyto', $source, $destination);

	push @args, '--dry-run' if $options{dry_run};
	push @args, '--progress' if $options{progress};
	push @args, '--checksum' if $options{checksum};
	push @args, '--ignore-times' if $options{ignore_times};

	if ($options{filters}) {
		for my $filter (@{$options{filters}}) {
			push @args, '--filter', $filter;
		}
	}

	if ($options{bwlimit}) {
		push @args, '--bwlimit', $options{bwlimit};
	}

	return $self->_run_command(\@args);
}

method move ($source, $destination, %options) {
	my @args = ('move', $source, $destination);

	push @args, '--dry-run' if $options{dry_run};
	push @args, '--progress' if $options{progress};

	return $self->_run_command(\@args);
}

method moveto ($source, $destination, %options) {
	my @args = ('moveto', $source, $destination);

	push @args, '--dry-run' if $options{dry_run};
	push @args, '--progress' if $options{progress};

	return $self->_run_command(\@args);
}

# Listing operations
method list ($remote, %options) {
	my @args = ('ls', $remote);

	push @args, '--recursive' if $options{recursive};

	return $self->_run_command(\@args, json => $options{json});
}

method list_dirs ($remote, %options) {
	my @args = ('lsd', $remote);

	push @args, '--recursive' if $options{recursive};

	return $self->_run_command(\@args, json => $options{json});
}

method list_files ($remote, %options) {
	my @args = ('lsf', $remote);

	push @args, '--recursive' if $options{recursive};
	push @args, '--dirs-only' if $options{dirs_only};
	push @args, '--files-only' if $options{files_only};

	return $self->_run_command(\@args);
}

# Info operations
method size ($remote, %options) {
	my @args = ('size', $remote);

	return $self->_run_command(\@args, json => $options{json});
}

method about ($remote, %options) {
	my @args = ('about', $remote);

	return $self->_run_command(\@args, json => $options{json});
}

method check ($source, $destination, %options) {
	my @args = ('check', $source, $destination);

	push @args, '--checkfile', $options{checkfile} if $options{checkfile};

	return $self->_run_command(\@args);
}

# Config operations
method config_show (%options) {
	my @args = ('config', 'show');

	push @args, $options{remote} if $options{remote};

	return $self->_run_command(\@args);
}

method listremotes () {
	my @args = ('listremotes');

	my $output = $self->_run_command(\@args);

	# Parse the output to extract remote names
	my @remotes;
	for my $line (split /\n/, $output || '') {
		$line =~ s/^\s+|\s+$//g;
		next unless $line;
		if ($line =~ /^([^:]+):$/) {
			push @remotes, $1;
		}
	}

	return @remotes;
}

# Test operations
method test ($remote) {
	my @args = ('test', 'info', $remote);

	eval {
		$self->_run_command(\@args);
		return 1;
	};

	return 0;  # Failed
}

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::Common::Rclone::Runner;

	my $runner = Bio_Bricks::Common::Rclone::Runner->new(
		rclone_path => '/usr/bin/rclone',
		config_dir => '/home/user/.config/rclone'
	);

	# Sync files
	$runner->sync('local:/path', 'remote:bucket/path',
		progress => 1,
		dry_run => 1
	);

	# Copy files
	$runner->copy('s3:bucket/file.txt', 'lakefs:repo/branch/file.txt');

	# List files
	my $files = $runner->list('remote:bucket/', json => 1);

	# Get size information
	my $size_info = $runner->size('remote:bucket/', json => 1);

	# Test remote connection
	my $ok = $runner->test('remote:');

=head1 DESCRIPTION

This module provides a wrapper around rclone commands, handling command construction,
execution, and output parsing. It supports all major rclone operations including
sync, copy, list, and configuration management.

The module automatically handles common rclone flags and provides a consistent
interface for JSON output parsing where supported.

=cut
