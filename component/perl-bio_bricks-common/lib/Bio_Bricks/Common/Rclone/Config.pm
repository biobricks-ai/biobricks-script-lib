package Bio_Bricks::Common::Rclone::Config;
# ABSTRACT: Rclone configuration file management

use Bio_Bricks::Common::Setup;

has config_dir => (
	is => 'ro',
	isa => Str,
	required => 1,
);

has config_file => (
	is => 'ro',
	isa => Str,
	lazy => 1,
	builder => '_build_config_file',
);

has verbose => (
	is => 'ro',
	isa => Bool,
	default => 0,
);

has _config_data => (
	is => 'rw',
	isa => HashRef,
	lazy => 1,
	builder => '_load_config',
);

method _build_config_file () {
	my $config_dir = path($self->config_dir);
	$config_dir->mkpath unless $config_dir->exists;
	return $config_dir->child('rclone.conf')->stringify;
}

method _load_config () {
	my $config_file = path($self->config_file);
	my %config;

	return \%config unless $config_file->exists;

	my $content = $config_file->slurp_utf8;
	my $current_section;

	for my $line (split /\n/, $content) {
		$line =~ s/^\s+|\s+$//g;  # trim whitespace
		next if $line eq '' || $line =~ /^#/;  # skip empty lines and comments

		if ($line =~ /^\[(.+)\]$/) {
			$current_section = $1;
			$config{$current_section} = {};
		} elsif ($current_section && $line =~ /^([^=]+)\s*=\s*(.*)$/) {
			my ($key, $value) = ($1, $2);
			$key =~ s/^\s+|\s+$//g;
			$value =~ s/^\s+|\s+$//g;
			$config{$current_section}{$key} = $value;
		}
	}

	return \%config;
}

method _save_config () {
	my $config_data = $self->_config_data;
	my $config_file = path($self->config_file);

	my @lines;

	for my $section_name (sort keys %$config_data) {
		push @lines, "[$section_name]";

		my $section = $config_data->{$section_name};
		for my $key (sort keys %$section) {
			my $value = $section->{$key};
			push @lines, "$key = $value";
		}

		push @lines, "";  # blank line between sections
	}

	$config_file->spew_utf8(join("\n", @lines));
	warn "Saved rclone config to $config_file\n" if $self->verbose;
}

method add_remote ($name, $config) {
	croak "Remote name required" unless $name;
	croak "Remote config required" unless $config && ref $config eq 'HASH';
	croak "Remote config must include 'type'" unless $config->{type};

	my $config_data = $self->_config_data;
	$config_data->{$name} = { %$config };  # copy to avoid mutation

	$self->_save_config();

	warn "Added rclone remote '$name'\n" if $self->verbose;
	return 1;
}

method remove_remote ($name) {
	croak "Remote name required" unless $name;

	my $config_data = $self->_config_data;

	unless (exists $config_data->{$name}) {
		croak "Remote '$name' not found";
	}

	delete $config_data->{$name};
	$self->_save_config();

	warn "Removed rclone remote '$name'\n" if $self->verbose;
	return 1;
}

method get_remote ($name) {
	croak "Remote name required" unless $name;

	my $config_data = $self->_config_data;
	return $config_data->{$name};
}

method list_remotes () {
	my $config_data = $self->_config_data;
	return sort keys %$config_data;
}

method remote_exists ($name) {
	my $config_data = $self->_config_data;
	return exists $config_data->{$name};
}

method update_remote ($name, $updates) {
	croak "Remote name required" unless $name;
	croak "Updates required" unless $updates && ref $updates eq 'HASH';

	my $config_data = $self->_config_data;

	unless (exists $config_data->{$name}) {
		croak "Remote '$name' not found";
	}

	# Merge updates into existing config
	my $remote_config = $config_data->{$name};
	for my $key (keys %$updates) {
		$remote_config->{$key} = $updates->{$key};
	}

	$self->_save_config();

	warn "Updated rclone remote '$name'\n" if $self->verbose;
	return 1;
}

method reload_config () {
	$self->_config_data($self->_load_config());
	return 1;
}

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::Common::Rclone::Config;

	my $config = Bio_Bricks::Common::Rclone::Config->new(
		config_dir => '/home/user/.config/rclone'
	);

	# Add a new remote
	$config->add_remote('myremote', {
		type => 's3',
		provider => 'AWS',
		access_key_id => 'AKIA...',
		secret_access_key => 'secret...',
		region => 'us-east-1',
	});

	# List all remotes
	my @remotes = $config->list_remotes();

	# Get remote configuration
	my $remote_config = $config->get_remote('myremote');

	# Update remote
	$config->update_remote('myremote', {
		region => 'us-west-2'
	});

	# Remove remote
	$config->remove_remote('myremote');

=head1 DESCRIPTION

This module manages rclone configuration files, providing methods to add, update,
remove, and query remote configurations. It handles the INI-style configuration
format used by rclone.

The configuration file is automatically created if it doesn't exist, and all
changes are immediately persisted to disk.

=cut
