package Bio_Bricks::Common::FileType;

use Bio_Bricks::Common::Setup;
use List::Util qw(first);
use Exporter 'import';

our @EXPORT_OK = qw(detect_file_type);

# File type detection patterns
my @FILE_TYPES = (
	# RDF/Knowledge Graph formats
	{ pattern => qr/\.hdt$/i,                          type => 'HDT' },
	{ pattern => qr/\.nt(?:\.gz|\.bz2|\.xz)?$/i,     type => 'N-Triples' },
	{ pattern => qr/\.ttl(?:\.gz|\.bz2|\.xz)?$/i,    type => 'Turtle' },
	{ pattern => qr/\.(?:rdf|owl)(?:\.gz|\.bz2|\.xz)?$/i, type => 'RDF/XML' },
	{ pattern => qr/\.nq(?:\.gz|\.bz2|\.xz)?$/i,     type => 'N-Quads' },
	{ pattern => qr/\.trig(?:\.gz|\.bz2|\.xz)?$/i,   type => 'TriG' },
	{ pattern => qr/\.jsonld(?:\.gz|\.bz2|\.xz)?$/i, type => 'JSON-LD' },

	# Data formats
	{ pattern => qr/\.parquet$/i,                      type => 'Parquet' },
	{ pattern => qr/\.csv(?:\.gz|\.bz2|\.xz)?$/i,    type => 'CSV' },
	{ pattern => qr/\.tsv(?:\.gz|\.bz2|\.xz)?$/i,    type => 'TSV' },
	{ pattern => qr/\.json(?:\.gz|\.bz2|\.xz)?$/i,   type => 'JSON' },
	{ pattern => qr/\.xml(?:\.gz|\.bz2|\.xz)?$/i,    type => 'XML' },
	{ pattern => qr/\.txt(?:\.gz|\.bz2|\.xz)?$/i,    type => 'Text' },

	# Archive formats
	{ pattern => qr/\.zip$/i,                          type => 'ZIP' },
	{ pattern => qr/\.tar$/i,                          type => 'TAR' },
	{ pattern => qr/\.tar\.gz$/i,                      type => 'TAR.GZ' },
	{ pattern => qr/\.tar\.bz2$/i,                     type => 'TAR.BZ2' },
	{ pattern => qr/\.tar\.xz$/i,                      type => 'TAR.XZ' },
	{ pattern => qr/\.7z$/i,                           type => '7Z' },

	# Database formats
	{ pattern => qr/\.db$/i,                           type => 'SQLite' },
	{ pattern => qr/\.sqlite$/i,                       type => 'SQLite' },
	{ pattern => qr/\.sqlite3$/i,                      type => 'SQLite' },

	# Binary formats
	{ pattern => qr/\.bin$/i,                          type => 'Binary' },
	{ pattern => qr/\.dat$/i,                          type => 'Data' },
);

fun detect_file_type ($path) {
	my $match = first { $path =~ $_->{pattern} } @FILE_TYPES;
	return $match ? $match->{type} : 'Other';
}

1;

__END__

=head1 NAME

Bio_Bricks::Common::FileType - File type detection for BioBricks

=head1 SYNOPSIS

	use Bio_Bricks::Common::FileType qw(detect_file_type);

	my $type = detect_file_type('data.hdt');           # Returns 'HDT'
	my $type = detect_file_type('triples.nt.gz');      # Returns 'N-Triples'
	my $type = detect_file_type('unknown.xyz');        # Returns 'Other'

=head1 DESCRIPTION

This module provides file type detection based on file extensions,
with special support for RDF/knowledge graph formats commonly used
in BioBricks.

=head1 FUNCTIONS

=func detect_file_type($path)

Detects the file type based on the file path/name extension.

Returns a string describing the file type, or 'Other' if the type
cannot be determined.

=head1 SUPPORTED FILE TYPES

=head2 RDF/Knowledge Graph Formats

=over 4

=item * HDT - Header Dictionary Triples

=item * N-Triples - Line-based RDF triples

=item * Turtle - Terse RDF Triple Language

=item * RDF/XML - RDF in XML format (includes OWL files)

=item * N-Quads - Line-based RDF quads

=item * TriG - Turtle with named graphs

=item * JSON-LD - JSON for Linked Data

=back

=head2 Data Formats

=over 4

=item * Parquet - Apache Parquet columnar format

=item * CSV - Comma-separated values

=item * TSV - Tab-separated values

=item * JSON - JavaScript Object Notation

=item * XML - Extensible Markup Language

=item * Text - Plain text files

=back

=head2 Archive Formats

=over 4

=item * ZIP - ZIP compressed archive

=item * TAR - Tape archive

=item * TAR.GZ - Gzip compressed TAR

=item * TAR.BZ2 - Bzip2 compressed TAR

=item * TAR.XZ - XZ compressed TAR

=item * 7Z - 7-Zip archive

=back

=head2 Database Formats

=over 4

=item * SQLite - SQLite database files

=back

=head1 COMPRESSION SUPPORT

The module recognizes compressed versions of data and RDF formats
with the following extensions:

=over 4

=item * .gz - Gzip compression

=item * .bz2 - Bzip2 compression

=item * .xz - XZ compression

=back

=cut
