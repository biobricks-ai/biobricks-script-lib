package Bio_Bricks::Common::Output;
# ABSTRACT: Colored user-facing output utilities

use Bio_Bricks::Common::Setup;
use Term::ANSIColor qw(colored);
use Exporter::Tiny ();

use base 'Exporter::Tiny';

our @EXPORT_OK = qw(
	output_info output_success output_warning output_error
	output_debug output_status output_header output_separator
	set_color get_color disable_colors enable_colors
	set_quiet_mode is_quiet_mode
);

our %EXPORT_TAGS = (
	all => [@EXPORT_OK],
	basic => [qw(output_info output_success output_warning output_error)],
	config => [qw(set_color get_color disable_colors enable_colors set_quiet_mode)],
);

# Color mappings - can be customized via environment or config
my %COLOR_MAP = (
	info      => 'cyan',
	success   => 'green',
	warning   => 'yellow',
	error     => 'red',
	debug     => 'white',
	header    => 'bold blue',
	separator => 'blue',

	# Common status colors
	completed => 'green',
	failed    => 'red',
	running   => 'cyan',
	queued    => 'yellow',
	pending   => 'yellow',
	stopped   => 'red',
);

# Global settings
my $COLORED_OUTPUT = 1;  # Can be disabled for non-TTY or testing
my $QUIET_MODE = 0;      # Suppress non-essential output

=head1 NAME

Bio_Bricks::Common::Output - Colored user-facing output utilities

=head1 SYNOPSIS

	use Bio_Bricks::Common::Output qw(:basic);

	# Basic output functions
	output_info("Processing files...");
	output_success("✓ Load completed successfully");
	output_warning("⚠ Queue is nearly full");
	output_error("✗ Failed to connect to Neptune");

	# Status with custom colors
	output_status("completed", "Job finished successfully");
	output_status("failed", "Job encountered errors");

	# Formatting
	output_header("Neptune Bulk Loader");
	output_separator();

	# Configuration
	set_color('info', 'blue');
	disable_colors();

=head1 DESCRIPTION

This module provides standardized, colored output functions for user-facing
messages in BioBricks scripts. It separates user output from logging and
provides consistent formatting and color schemes.

=head1 FUNCTIONS

=cut

fun output_info(Str $message, Str $prefix = "") {
	return if $QUIET_MODE;

	my $output = $prefix ? "$prefix $message" : $message;
	say _colorize($output, 'info');
}

fun output_success(Str $message, Str $prefix = "✓") {
	return if $QUIET_MODE;

	my $output = $prefix ? "$prefix $message" : $message;
	say _colorize($output, 'success');
}

fun output_warning(Str $message, Str $prefix = "⚠") {
	return if $QUIET_MODE;

	my $output = $prefix ? "$prefix $message" : $message;
	say _colorize($output, 'warning');
}

fun output_error(Str $message, Str $prefix = "✗") {
	my $output = $prefix ? "$prefix $message" : $message;
	say _colorize($output, 'error');
}

fun output_debug(Str $message, Str $prefix = "") {
	return if $QUIET_MODE;
	return unless $ENV{DEBUG} || $ENV{VERBOSE};

	my $output = $prefix ? "$prefix $message" : $message;
	say _colorize($output, 'debug');
}

fun output_status(Str $status, Str $message = "") {
	return if $QUIET_MODE;

	my $status_colored = _colorize($status, $status);
	my $output = $message ? "$status_colored: $message" : $status_colored;
	say $output;
}

fun output_header(Str $title, Str $char = "=") {
	return if $QUIET_MODE;

	my $length = length($title) + 4;
	my $separator = $char x $length;

	say "";
	say _colorize($separator, 'separator');
	say _colorize("  $title  ", 'header');
	say _colorize($separator, 'separator');
	say "";
}

fun output_separator(Int $length = 60, Str $char = "=") {
	return if $QUIET_MODE;

	say _colorize($char x $length, 'separator');
}

=head2 Configuration Functions

=cut

fun set_color(Str $type, Str $color) {
	$COLOR_MAP{$type} = $color;
}

fun get_color(Str $type) {
	return $COLOR_MAP{$type} // 'white';
}

fun disable_colors() {
	$COLORED_OUTPUT = 0;
}

fun enable_colors() {
	$COLORED_OUTPUT = 1;
}

fun set_quiet_mode(Bool $quiet = 1) {
	$QUIET_MODE = $quiet;
}

fun is_quiet_mode() {
	return $QUIET_MODE;
}

=head2 Internal Functions

=cut

fun _colorize(Str $text, Str $type) {
	return $text unless $COLORED_OUTPUT;
	return $text unless -t STDOUT;  # Don't color if not a terminal

	my $color = get_color($type);
	return colored($text, $color);
}

# Auto-detect color support and TTY
sub import {
	# Disable colors if not a TTY or NO_COLOR is set
	if (!-t STDOUT || $ENV{NO_COLOR}) {
		disable_colors();
	}

	# Enable quiet mode if QUIET is set
	if ($ENV{QUIET}) {
		set_quiet_mode(1);
	}

	# Call parent import for exporting
	goto &Exporter::Tiny::import;
}

1;

=head1 ENVIRONMENT VARIABLES

=over 4

=item NO_COLOR

Disable colored output when set.

=item QUIET

Enable quiet mode, suppressing non-essential output.

=item DEBUG, VERBOSE

Enable debug output when set.

=back

=head1 CUSTOMIZATION

Colors can be customized programmatically:

	set_color('success', 'bright_green');
	set_color('custom_status', 'bold yellow');

=cut
