package Bio_Bricks::Common::DVC::Storage;
# ABSTRACT: Base class for DVC storage backends

use Bio_Bricks::Common::Setup;

# Base URI for the storage (can be overridden by subclasses)
ro base_uri => isa => Str, required => 1;

# Resolve a DVC output to its storage URI
# Must be implemented by subclasses
method resolve ($output_obj) {
	die "resolve() must be implemented by subclass";
}

# Get the hash path for DVC storage (common pattern)
method hash_path ($hash) {
	return unless $hash;

	# DVC uses first 2 chars as directory, rest as filename
	my $prefix = substr($hash, 0, 2);
	my $suffix = substr($hash, 2);

	return ($prefix, $suffix);
}

# URI-based storage operations (to be implemented by subclasses)
method head_object ($uri) {
	die "head_object() must be implemented by subclass";
}

method get_object ($uri) {
	die "get_object() must be implemented by subclass";
}

method object_exists ($uri) {
	die "object_exists() must be implemented by subclass";
}

1;
