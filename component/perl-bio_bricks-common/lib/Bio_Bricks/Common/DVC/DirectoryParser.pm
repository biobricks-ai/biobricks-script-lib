package Bio_Bricks::Common::DVC::DirectoryParser;

use Bio_Bricks::Common::Setup;
use MooX::Struct
	File => [qw( relpath md5 size )];

=head1 NAME

Bio_Bricks::Common::DVC::DirectoryParser - Parser for DVC .dir JSON files

=head1 SYNOPSIS

	use Bio_Bricks::Common::DVC::DirectoryParser;

	# Parse from JSON string
	my $dir = Bio_Bricks::Common::DVC::DirectoryParser->parse_string($json_string);

	# Or construct from already parsed data
	my $dir = Bio_Bricks::Common::DVC::DirectoryParser->new(data => $parsed_data);

	# Access files
	my @files = @{ $dir->files };

	# Get file count and total size
	my $count = $dir->file_count;
	my $total_size = $dir->total_size;

=head1 DESCRIPTION

This module parses DVC .dir JSON files which contain metadata about files in a DVC directory.

=cut

# Raw parsed data
ro data => required => 1;

# Files as File objects
lazy files => method () {
	my @files;

	return \@files unless $self->data && ref($self->data) eq 'ARRAY';

	for my $entry (@{$self->data}) {
		next unless ref($entry) eq 'HASH';

		push @files, File->new(
			relpath => $entry->{relpath},
			md5 => $entry->{md5},
			size => $entry->{size} || 0,
		);
	}

	return \@files;
};

# File count
lazy file_count => method () {
	return scalar(@{$self->files});
};

# Total size of all files
lazy total_size => method () {
	my $total = 0;
	for my $file (@{$self->files}) {
		$total += $file->size || 0;
	}
	return $total;
};

# Files matching a pattern
lazy rdf_files => method () {
	return $self->find_files_by_pattern(qr/\.(hdt|nt|ttl|rdf|owl)$/i);
};

=classmethod parse_string

Class method to parse a DVC .dir JSON content string and return a new DirectoryParser instance.

	my $dir = Bio_Bricks::Common::DVC::DirectoryParser->parse_string($json_content);

=cut

classmethod parse_string ($json_content) {

	return unless $json_content;

	my $data = eval { decode_json($json_content) };
	return unless $data;

	# DVC .dir files should contain an array
	if (ref($data) eq 'ARRAY') {
		return $class->new(data => $data);
	}

	# Sometimes might be wrapped in an object
	if (ref($data) eq 'HASH' && $data->{files}) {
		return $class->new(data => $data->{files});
	}

	return;
}

=method find_files_by_pattern

Find files matching a pattern in the directory.

	my @matching = @{ $dir->find_files_by_pattern(qr/\.txt$/) };

=cut

method find_files_by_pattern ($pattern) {

	return [] unless $pattern;

	my @matching;
	for my $file (@{$self->files}) {
		next unless $file->relpath;
		push @matching, $file if $file->relpath =~ $pattern;
	}

	return \@matching;
}

=method get_file_by_path

Get a specific file by its relative path.

	my $file = $dir->get_file_by_path('data.txt');

=cut

method get_file_by_path ($relpath) {

	return unless $relpath;

	for my $file (@{$self->files}) {
		return $file if $file->relpath && $file->relpath eq $relpath;
	}

	return;
}

1;
