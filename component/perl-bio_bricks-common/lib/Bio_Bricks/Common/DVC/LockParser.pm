package Bio_Bricks::Common::DVC::LockParser;

use Bio_Bricks::Common::Setup;
use Bio_Bricks::Common::DVC::Schema;
use Bio_Bricks::Common::DVC::Schema::Types qw(LockFile);
use YAML::XS qw(Load);

=head1 NAME

Bio_Bricks::Common::DVC::LockParser - Parser for DVC lock files

=head1 SYNOPSIS

	use Bio_Bricks::Common::DVC::LockParser;

	# Parse from YAML string
	my $lock = Bio_Bricks::Common::DVC::LockParser->parse_string($yaml_string);

	# Access outputs
	my @outputs = @{ $lock->OUTPUTS };

	# Get stage info
	my $schema = $lock->schema;

=head1 DESCRIPTION

This module parses DVC lock files and returns L<Bio_Bricks::Common::DVC::Schema::LockFile> objects.

=cut

=classmethod parse_string

Class method to parse a DVC lock file content string and return a LockFile object.

	my $lock = Bio_Bricks::Common::DVC::LockParser->parse_string($yaml_content);

=cut

classmethod parse_string ($yaml_content) {

	return unless $yaml_content;

	my $data = eval { Load($yaml_content) };
	return unless $data;

	return Bio_Bricks::Common::DVC::Schema::LockFile->new($data);
}

1;
