package Bio_Bricks::Common::DVC::Storage::FS;

use Bio_Bricks::Common::Setup;
use URI::file;
use Bio_Bricks::Common::DVC::DirectoryParser;

extends 'Bio_Bricks::Common::DVC::Storage';

# Override base_uri type for filesystem
has '+base_uri' => (isa => InstanceOf['URI::file']);

method resolve ($output_obj) {
	return unless $output_obj && $output_obj->EFFECTIVE_HASH;

	my $hash = $output_obj->EFFECTIVE_HASH;
	my ($prefix, $suffix) = $self->hash_path($hash);

	# Get base path from URI
	my $base_path = path($self->base_uri->file);

	# Build DVC cache path: cache/files/md5/xx/xxxxx
	my $file_path = $base_path->child('files', 'md5', $prefix, $suffix);

	return URI::file->new($file_path->stringify);
}

# Keep file_path for backward compatibility
method file_path ($output_obj) {
	my $uri = $self->resolve($output_obj);
	return $uri ? path($uri->file) : undef;
}

# Fetch and parse directory metadata from filesystem
method fetch_directory ($dir_output) {

	my $dir_uri = $self->resolve($dir_output);
	return unless $dir_uri;

	my $dir_file_path = $dir_uri->file;
	return unless -f $dir_file_path;

	eval {
		# Read and parse the .dir JSON file
		my $json_content = do {
			local $/;
			open my $fh, '<', $dir_file_path or die "Cannot open $dir_file_path: $!";
			<$fh>;
		};

		return Bio_Bricks::Common::DVC::DirectoryParser->parse_string($json_content);
	};
	if ($@) {
		die "Filesystem error reading directory " . $dir_output->path . ": $@";
	}

	return;
}

1;
