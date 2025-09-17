package Bio_Bricks::Common::DVC::Iterator;
# ABSTRACT: Iterator for DVC storage Output (file or directory)

use Bio_Bricks::Common::Setup;
use Bio_Bricks::Common::DVC::DirectoryParser;
use Bio_Bricks::Common::DVC::Iterator::Item;
use results qw(ok err);
use overload '&{}' => \&_iterator_coderef;

with qw(MooX::Log::Any);

# Required inputs
ro storage => isa => InstanceOf['Bio_Bricks::Common::DVC::Storage'];
ro output  => isa => InstanceOf['Bio_Bricks::Common::DVC::Schema::Output'];

# Iterator state (private)
has _stack => (is => 'rw', default => sub { [] });  # Stack of items to process
has _initialized => (is => 'rw', default => 0);

# Initialize the iterator
method _initialize () {
	return if $self->_initialized;

	# Just push the initial output onto the stack
	# Processing happens lazily in _next
	push @{$self->_stack}, {
		type => 'output',
		output => $self->output,
		parent_directory => undef
	};

	$self->_initialized(1);
}

# Get next item from iterator
method _next () {
	$self->_initialize unless $self->_initialized;

	# Process items from stack until we find a file or run out
	while (@{$self->_stack}) {
		my $stack_item = shift @{$self->_stack};

		if ($stack_item->{type} eq 'output') {
			my $output = $stack_item->{output};
			my $parent_dir = $stack_item->{parent_directory};

			if ($output->IS_DIRECTORY) {
				# Directory - fetch .dir and push files onto stack
				$self->log->infof("Lazily expanding directory: %s", $output->path);

				my $directory;
				try {
					$directory = $self->storage->fetch_directory($output);
					$self->log->tracef("fetch_directory returned: %s",
						defined $directory ? "directory with " . scalar(@{$directory->files}) . " files" : "undefined");
				} catch ($e) {
					$self->log->errorf("Error fetching directory %s: %s", $output->path, $e);
					return err("Error fetching directory metadata for " . $output->path . ": $e");
				}

				unless ($directory) {
					$self->log->warnf("No directory metadata found for: %s", $output->path);
					return err("No directory metadata found for " . $output->path);
				}

				# Push directory's files onto stack (in reverse order so they're processed in order)
				for my $dir_file (reverse @{$directory->files}) {
					my $file_path = $output->path . '/' . $dir_file->relpath;
					my $file_output = Bio_Bricks::Common::DVC::Schema::Output->new(
						path => $file_path,
						md5 => $dir_file->md5,
						size => $dir_file->size
					);

					unshift @{$self->_stack}, {
						type => 'output',
						output => $file_output,
						parent_directory => $output
					};
				}

				# Continue to next item in stack
				next;
			} else {
				# File - resolve and return it
				$self->log->tracef("Processing file: %s", $output->path);

				my $uri = $self->storage->resolve($output);
				if ($uri) {
					my $item = Bio_Bricks::Common::DVC::Iterator::Item->new(
						output => $output,
						uri => $uri,
						iterator => $self,
						maybe parent_directory => $parent_dir,
					);
					return ok($item);
				} else {
					return err("Could not resolve URI for file: " . $output->path);
				}
			}
		}
	}

	# No more items
	return undef;
}

# Overload &{} to make object callable as iterator
method _iterator_coderef () {
	return sub { $self->_next };
}



1;
