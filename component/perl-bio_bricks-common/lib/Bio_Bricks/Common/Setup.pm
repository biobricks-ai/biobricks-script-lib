package Bio_Bricks::Common::Setup;
# ABSTRACT: Common imports and setup for Bio_Bricks modules

use strict;
use warnings;
use autodie;

use Import::Into;

use feature qw(say postderef);
use Function::Parameters ();
use MooX::TypeTiny ();
use With::Roles ();

use Feature::Compat::Try ();

use Path::Tiny ();
use Carp ();
use JSON::PP ();

use Type::Utils ();

sub import {
	my ($class, @tags) = @_;
	my $target = caller;

	# Default to :class if no tags specified
	@tags = (':class') unless @tags;

	# Parse tags into a set
	my %tag_set;
	for my $tag (@tags) {
		if ($tag =~ /^:(base|class|role)$/) {
			$tag_set{$1} = 1;
		} else {
			Carp::croak("Invalid import tag '$tag'. Use :base, :class, or :role");
		}
	}

	# Validate mutually exclusive tags
	my $mode_count = grep { $tag_set{$_} } qw(base class role);
	if ($mode_count > 1) {
		Carp::croak("Only one of :base, :class, or :role can be specified");
	}

	# Determine the mode
	my $mode = $tag_set{base} ? 'base' : $tag_set{role} ? 'role' : 'class';

	# Core Perl strictness and safety
	strict->import::into($target);
	warnings->import::into($target);
	autodie->import::into($target);

	# Modern Perl features
	feature->import::into($target,
		qw(say state postderef),
		qw(isa)x!!($^V > v5.32.0),
	);

	Feature::Compat::Try->import::into($target);

	# Role composition (available in all modes)
	With::Roles->import::into($target);

	# Function signatures with type checking
	my %type_tiny_fp_check = (reify_type => sub { Type::Utils::dwim_type($_[0]) });
	Function::Parameters->import::into($target,
		{
			fun         => { defaults => 'function_lax',    %type_tiny_fp_check },
			classmethod => { defaults => 'classmethod_lax', %type_tiny_fp_check },
			method      => { defaults => 'method_lax',      %type_tiny_fp_check },
		}
	);

	# Object system - import based on mode
	if ($mode eq 'class') {
		Moo->import::into($target);
		Sub::HandlesVia->import::into($target);
		MooX::ShortHas->import::into($target);
	} elsif ($mode eq 'role') {
		Moo::Role->import::into($target);
		Sub::HandlesVia->import::into($target);
		MooX::ShortHas->import::into($target);
	}
	# :base - no object system imported

	# Type system
	Types::Standard->import::into($target, qw(
		Str Bool Int Num
		Maybe Optional
		Slurpy
		ArrayRef HashRef
		InstanceOf ConsumerOf
		Any
	));

	# Common utilities
	Path::Tiny->import::into($target);
	Carp->import::into($target, qw(croak carp));
	JSON::PP->import::into($target, qw(encode_json decode_json));
	PerlX::Maybe->import::into($target);

	# Namespace cleanup
	namespace::autoclean->import::into($target);

	# Finally, remove specific warnings
	if ($^V > v5.34.0) {
		warnings->unimport::out_of($target, qw(experimental::try));
	}

	return;
}

1;

__END__

=head1 SYNOPSIS

	# For classes (default)
	use Bio_Bricks::Common::Setup;

	# For roles
	use Bio_Bricks::Common::Setup ':role';

	# For modules without object system
	use Bio_Bricks::Common::Setup ':base';

	# Example usage (class):
	package Bio_Bricks::Common::Example;
	use Bio_Bricks::Common::Setup;

	ro config => isa => Str;

	method process_data(Str $input, (Maybe[HashRef]) $options = undef) {
		say "Processing: $input";
		my $path = path($input);
		croak "File not found" unless $path->exists;

		try {
			my $data = decode_json($path->slurp);
			return $data;
		} catch ($e) {
			carp "Failed to parse JSON: $e";
			return {};
		}
	}

=head1 DESCRIPTION

This module provides a comprehensive set of common imports and setup for Bio_Bricks
modules. It combines modern Perl features, object-oriented programming tools, type
checking, and commonly used utilities into a single import.

=head1 IMPORT TAGS

=head2 :class (default)

Import this for standard L<Moo>-based classes:

	use Bio_Bricks::Common::Setup;  # :class is implicit

Imports: L<Moo>, L<Sub::HandlesVia>, L<MooX::ShortHas>, L<With::Roles>, and all base features.

=head2 :role

Import this for L<Moo::Role>-based roles:

	use Bio_Bricks::Common::Setup ':role';

Imports: L<Moo::Role>, L<Sub::HandlesVia>, L<MooX::ShortHas>, L<With::Roles>, and all base features.

=head2 :base

Import this for modules that don't need an object system:

	use Bio_Bricks::Common::Setup ':base';

Imports: All features except L<Moo>/L<Moo::Role>. Still includes L<With::Roles> for role
composition. Useful for utility modules, functions-only modules, or when you want
to use a different object system.

This provides:

=over 4

=item * Modern Perl: C<strict>, C<warnings>, C<autodie>, C<say>, C<state>, C<postderef>, C<try>/C<catch>

=item * L<With::Roles> - Role composition

=item * Type system: L<Types::Standard> exports (C<Str>, C<Bool>, C<Int>, C<Num>, C<Maybe>, C<Optional>, C<Slurpy>, C<ArrayRef>, C<HashRef>, C<InstanceOf>, C<ConsumerOf>, C<Any>)

=item * Function signatures: C<fun>, C<method>, C<classmethod> with type checking via L<Function::Parameters>

=item * Utilities: L<Path::Tiny>, L<Carp> (C<croak>, C<carp>), L<JSON::PP> (C<encode_json>, C<decode_json>), L<PerlX::Maybe>

=item * Automatic namespace cleanup via L<namespace::autoclean>

=back

=head1 IMPORTED MODULES AND FEATURES

=head2 Core Perl

=over 4

=item * C<strict>, C<warnings>, C<autodie> - Standard Perl safety

=item * C<say>, C<state>, C<postderef> - Modern Perl features

=item * C<isa> - Built-in type checking (Perl 5.32+)

=item * C<try>/C<catch> - Exception handling via L<Feature::Compat::Try>

=back

=head2 Object System

=over 4

=item * L<Moo> - Lightweight object system

=item * L<Sub::HandlesVia> - Delegated method generation for attributes

=item * L<MooX::ShortHas> - Concise attribute syntax (C<ro>, C<rw>, C<lazy>)

=item * L<With::Roles> - Role composition

=item * L<namespace::autoclean> - Automatic namespace cleanup

=back

=head2 Type System

Imports common types from L<Types::Standard>:

=over 4

=item * Basic types: C<Str>, C<Bool>, C<Int>, C<Num>

=item * Containers: C<ArrayRef>, C<HashRef>

=item * Modifiers: C<Maybe>, C<Optional>, C<Slurpy>

=item * Object types: C<InstanceOf>, C<ConsumerOf>

=item * Universal: C<Any>

=back

=head2 Function Signatures

=over 4

=item * C<fun> - Function with type checking

=item * C<method> - Object method with type checking

=item * C<classmethod> - Class method with type checking

=back

All via L<Function::Parameters>.

=head2 Common Utilities

=over 4

=item * L<Path::Tiny> - File path manipulation

=item * L<Carp> - Enhanced error reporting (C<croak>, C<carp>)

=item * L<JSON::PP> - JSON encoding/decoding (C<encode_json>, C<decode_json>)

=item * L<PerlX::Maybe> - Conditional hash/array elements (C<maybe>)

=back

=head1 EXAMPLES

=head2 Basic Module Structure

	package Bio_Bricks::Common::Example;
	use Bio_Bricks::Common::Setup;

	has config_file => (
		is => 'ro',
		isa => Str,
		required => 1,
	);

	method load_config() {
		my $path = path($self->config_file);
		croak "Config file not found" unless $path->exists;

		try {
			return decode_json($path->slurp);
		} catch ($e) {
			croak "Invalid JSON in config: $e";
		}
	}

=head2 Function with Type Checking

	fun calculate_percentage(Int $value, Int $total) {
		croak "Total cannot be zero" if $total == 0;
		return ($value / $total) * 100;
	}

=head2 Method with Optional Parameters

	method download_file(Str $url, (Maybe[Str]) $destination = undef) {
		my $dest = $destination // path($url)->basename;
		say "Downloading $url to $dest";
		# ... implementation
	}

=head1 COMPATIBILITY

This module requires Perl 5.20 or later. Some features (like C<isa>) are only
available in newer Perl versions and are conditionally imported.

=cut
