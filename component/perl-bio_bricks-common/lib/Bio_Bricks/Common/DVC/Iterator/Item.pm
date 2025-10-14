package Bio_Bricks::Common::DVC::Iterator::Item;
# ABSTRACT: Item object for DVC Iterator results

use Bio_Bricks::Common::Setup;
use Number::Bytes::Human qw(format_bytes);

# Core data from iterator
ro output => isa => InstanceOf['Bio_Bricks::Common::DVC::Schema::Output'], required => 1;
ro uri => isa => InstanceOf['URI::s3'], required => 1;

# Reference back to iterator for accessing storage operations
ro iterator => isa => InstanceOf['Bio_Bricks::Common::DVC::Iterator'], required => 1, handles => {
	storage => 'storage',
};

# Optional reference to parent directory output object
ro parent_directory => (
	isa => InstanceOf['Bio_Bricks::Common::DVC::Schema::Output'],
	required => 0,
	predicate => 'has_parent_directory',
);

# Computed attributes from output
method path_segments () {
	my $path = $self->output->path;
	my @segments = grep length, split '/', $path;
	return \@segments;
}

method hash () {
	return $self->output->EFFECTIVE_HASH;
}

method is_directory () {
	return $self->output->IS_DIRECTORY;
}

method size () {
	return $self->output->size;
}

# Computed path from segments
{
no warnings 'redefine'; # Path::Tiny::path() via ::Setup
method path () {
	return join('/', @{$self->path_segments});
}
}

# Get parent directory path if this came from a directory
method from_directory () {
	return unless $self->has_parent_directory;
	return $self->parent_directory->path;
}

# Convenience methods
method is_file () {
	return !$self->is_directory;
}

method file_extension () {
	my $last_segment = $self->path_segments->[-1];
	return $last_segment =~ /\.([^.]+)$/ ? $1 : undef;
}

method basename () {
	return $self->path_segments->[-1];
}

method dirname () {
	my @segments = @{$self->path_segments};
	return '' if @segments <= 1;
	pop @segments;
	return join('/', @segments);
}

method dirname_segments () {
	my @segments = @{$self->path_segments};
	return [] if @segments <= 1;
	pop @segments;
	return \@segments;
}


# Human-readable size
method size_human () {
	return format_bytes($self->size);
}

# Summary for debugging/logging
method summary () {
	my $ext = $self->file_extension // 'unknown';
	my $summary = sprintf("%s (.%s, %s)",
		$self->path,
		$ext,
		$self->size_human
	);

	if ($self->from_directory) {
		$summary .= " from directory: " . $self->from_directory;
	}

	return $summary;
}

1;
