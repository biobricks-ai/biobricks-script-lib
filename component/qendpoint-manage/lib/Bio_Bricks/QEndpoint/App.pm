package Bio_Bricks::QEndpoint::App;

use strict;
use warnings;
use feature qw(say signatures postderef);
use Syntax::Construct qw( // <<~ /r );

use List::UtilsBy qw(partition_by);
use List::Util qw(max);

use Getopt::Long::Descriptive;
use Pod::Usage;

use IO::Socket::INET;

use Path::Tiny qw(path);

use I18N::Langinfo qw(langinfo CODESET);
use JSON::MaybeXS;
use Text::Table::Tiny qw(generate_table);
use Shell::Config::Generate;

use Log::Any '$log';
use Log::Any::Adapter 'Screen';

use Bio_Bricks::QEndpoint::Instance;

# Detect UTF-8 support and set output encoding
my $codeset = langinfo(CODESET());
my $is_utf8 = $codeset =~ /UTF-8/i;
if ($is_utf8) {
	binmode STDOUT, ':encoding(UTF-8)';
	binmode STDERR, ':encoding(UTF-8)';
}

my $json = JSON::MaybeXS->new->utf8(1)->canonical(1);

# Schema version for JSON files
our $SCHEMA_VERSION = 1;

# Default values
our $CONFIG_DIR = path($ENV{HOME})->child('.config/qendpoint-manage');
my $DEFAULT_SPARQL = <<~'SPARQL';
	SELECT *
	WHERE {
		?subj ?pred ?obj .
	}
	LIMIT 10
	SPARQL
my $DEFAULT_ACCEPT = 'application/sparql-results+json';

our $PROCESS_SENTINEL = path($0)->basename;

# Format shortcuts
my %FORMAT_TO_MIME_MAP = (
	json => 'application/sparql-results+json',
	xml  => 'application/sparql-results+xml',
	csv  => 'text/csv',
	tsv  => 'text/tab-separated-values',
);

# Helper function to create required parameter validation
sub _mk_required_param ($param_name) {
	return (
		"${param_name} is required" => sub {
			defined($_[0]) or die "Option --${param_name} is required\n"
		}
	);
}

# Helper function to check one_of constraints manually since Getopt::Long::Descriptive's one_of is buggy.
# Returns the option that is set, or undef if none, or dies if multiple are set.
sub check_one_of ($opt, $group_name, @option_names) {
	my @set_opts = grep { $opt->can($_) && defined $opt->$_ } @option_names;

	if (@set_opts > 1) {
		die "Only one of --" . join(', --', @option_names) . " may be specified\n";
	}

	return @set_opts ? $set_opts[0] : undef;
}

# Function to manually validate constraints since Getopt::Long::Descriptive isn't doing it
sub validate_constraints ($opt, $usage) {
	# Manual validation of one_of groups due to Getopt::Long::Descriptive bugs
	# See: <https://github.com/rjbs/Getopt-Long-Descriptive/issues/32>.

	# Group options by their one_of constraint using partition_by
	my %one_of_groups = partition_by { $_->{constraint}{one_of} }
		grep { exists $_->{constraint}{one_of} } $usage->{options}->@*;

	# Validate each one_of group and implement implies logic
	for my $group_name (keys %one_of_groups) {
		my @group_options = @{$one_of_groups{$group_name}};
		my @option_names = map { $_->{name} } @group_options;

		# Check which options in this group are set
		my $selected_option = check_one_of($opt, $group_name, @option_names);

		if ($selected_option) {
			# Find the selected option's constraint info
			my ($option_info) = grep { $_->{name} eq $selected_option } @group_options;
			my $implies_to = $option_info->{constraint}{implies}{$group_name} // $selected_option;

			# Set the group attribute (implements implies logic)
			$opt->{$group_name} = $implies_to;
		}
	}

	# Validate callbacks for options that have values
	for my $option ($usage->{options}->@*) {
		# Skip spacers and unnamed options
		next unless $option->{constraint}
			&& defined $option->{constraint}{callbacks}
			&& defined $option->{name};

		my $option_name = $option->{name};
		my $value = $opt->can($option_name) ? $opt->$option_name : undef;
		for my $constraint_name (keys $option->{constraint}{callbacks}->%*) {
			my $callback = $option->{constraint}{callbacks}{$constraint_name};
			eval { $callback->($value) };
			if ($@) {
				die $@;
			}
		}
	}
}

sub start_qendpoint {
	my $hdt_file = shift;
	Bio_Bricks::QEndpoint::Instance->create_instance($hdt_file);
}

sub query_qendpoint {
	my ($target, $sparql_query, $accept_format) = @_;

	$sparql_query //= $DEFAULT_SPARQL;
	$accept_format //= $DEFAULT_ACCEPT;

	# Get all running instances
	my @instances = Bio_Bricks::QEndpoint::Instance->list_all;
	my @running_instances = grep { $_->is_running } @instances;

	die "Error: No qendpoint instances appear to be running.\n"
		unless @running_instances;

	# Interactive mode if no target provided
	unless ($target) {
		print "Available qendpoint instances:\n";
		list_instances('table');  # Use table format for interactive display
		print "\nUsage: qendpoint-manage query <HDT_PATH|INSTANCE_ID> [SPARQL_QUERY]\n";
		return;
	}

	# Find the instance by HDT file path or instance ID
	my $found_instance = Bio_Bricks::QEndpoint::Instance->find_instance($target);

	unless ($found_instance && $found_instance->is_running) {
		$log->error("No running qendpoint instance found for: $target");
		say STDERR "Available instances:";
		say STDERR "INSTANCE_ID\tHDT_FILE\tPORT\tPID";

		for my $instance (@running_instances) {
			say STDERR "@{[ $instance->instance_id ]}\t@{[ $instance->hdt_file ]}\t@{[ $instance->port ]}\t@{[ $instance->pid ]}";
		}
		exit 1;
	}

	my $endpoint_url = $found_instance->endpoint_url;

	# Execute SPARQL query
	$log->info("Querying qendpoint at <$endpoint_url>...");
	$log->info("HDT file: @{[ $found_instance->hdt_file ]}");
	$log->info("Instance ID: @{[ $found_instance->instance_id ]}");
	$log->info("Query: $sparql_query");

	exec 'curl', qw(-X POST), $endpoint_url,
		 qw(-H), "Accept: $accept_format",
		 qw(-H), 'Content-Type: application/sparql-query',
		 qw(-d), $sparql_query;
}

sub list_instances {
	my ($output_format) = @_;

	my @instances = Bio_Bricks::QEndpoint::Instance->list_all;

	unless (@instances) {
		$log->warn("No instances found");
		return;
	}

	my @tab_header = qw(INSTANCE_ID PORT PID STATUS ENDPOINT HDT_FILE);
	my $generate_tab_data_row = sub($instance) {
		my $json_data = $instance->TO_JSON;
		return [
			$json_data->{instance_id}      ,
			$json_data->{port}        // '',
			$json_data->{pid}         // '',
			$json_data->{status}           ,
			$json_data->{endpoint}    // '',
			$json_data->{hdt_file}         ,
		];
	};
	my $generate_tab_rows = sub($instances) {
		return [
			\@tab_header,
			map $generate_tab_data_row->($_), @$instances
		];
	};

	if ($output_format eq 'json') {
		# Output as JSONL (one JSON object per line)
		say join "\n", map $json->encode($_->TO_JSON), @instances;
	} elsif ($output_format eq 'tsv') {
		# Output as TSV
		say join "\n",
			map { join"\t", @$_ }
			$generate_tab_rows->(\@instances)->@*;
	} else {
		# Default table format using Text::Table::Tiny
		say generate_table(
			rows       => $generate_tab_rows->(\@instances),
			header_row => 1,
			style      => $is_utf8 ? 'boxrule' : 'classic'
		);
	}
}

sub stop_instance {
	my ($target) = @_;

	# Find the instance by HDT file path or instance ID
	my $instance = Bio_Bricks::QEndpoint::Instance->find_instance($target);

	unless ($instance) {
		die "Error: No qendpoint instance found for: $target\n";
	}

	$instance->stop;
}

sub stop_all_instances {
	$log->info("Stopping all running instances...");

	# Get all instances
	my @instances = Bio_Bricks::QEndpoint::Instance->list_all;
	my @running_instances = grep { $_->is_running } @instances;

	unless (@running_instances) {
		$log->info("No running instances found");
		return;
	}

	my $stopped = 0;
	for my $instance (@running_instances) {
		$log->info("Stopping instance: @{[ $instance->instance_id ]}");
		$instance->stop;
		$stopped++;
	}

	say "Stopped $stopped instances";
}

sub shell_config {
	my ($target) = @_;

	# Find the instance by HDT file path or instance ID
	my $instance = Bio_Bricks::QEndpoint::Instance->find_instance($target);

	unless ($instance && $instance->is_running) {
		die "Error: No running qendpoint instance found for: $target\n";
	}

	# Generate shell configuration
	my $config = Shell::Config::Generate->new;
	$config->set('SPARQL_ENDPOINT', $instance->endpoint_url);

	# Output the configuration
	print $config->generate;
}

sub cleanup_instances {
	$log->info("Cleaning up stopped instances...");

	# Get all instances
	my @instances = Bio_Bricks::QEndpoint::Instance->list_all;
	my $removed = 0;

	for my $instance (@instances) {
		# Only remove instances that are definitely stopped (not running and not valid processes)
		next unless !$instance->is_running && !$instance->is_process_valid;
		$log->info("Removing stopped instance: @{[ $instance->instance_id
			]} (Status: @{[ $instance->status // 'unknown'
			]}, PID @{[ $instance->pid // 'none'
			]}, HDT @{[ $instance->hdt_file ]})");
		# Remove the instance directory
		$instance->dir->remove_tree if $instance->dir->exists;
		$removed++;
	}

	say "Removed $removed stopped instances";
}

# Dispatch table for subcommands
my %DISPATCH = (
	'start' => {
		sort_key => 10,
		description => 'Start a new qendpoint instance',
		options => [
			[ 'hdt-file=s', "HDT file to serve (required)", {
				callbacks => { _mk_required_param('hdt-file') =>, },
			} ],
		],
		handler => sub ($opt, $usage) {
			start_qendpoint($opt->hdt_file);
		},
	},
	'query' => {
		sort_key => 20,
		description => 'Query a qendpoint instance',
		options => [
			[ 'target|t=s', "HDT file path or instance ID (required)", {
				callbacks => { _mk_required_param('target') =>, }
			} ],
			[],
			[ 'query_source' => hidden => { one_of => [
				[ 'query|q=s', "SPARQL query string" ],
				[ 'file|f=s', "Read SPARQL query from file" ],
			] } ],
			[],
			[ 'accept_source' => hidden => { one_of => [
				[ 'accept|a=s', "Accept header format (MIME type)" ],
				[ 'format=s', "Format shortcut: @{[ join ', ', sort keys %FORMAT_TO_MIME_MAP ]}", {
					callbacks => {
						'valid format' => sub {
							return unless defined $_[0];
							exists $FORMAT_TO_MIME_MAP{lc($_[0])}
								or die "Invalid format '$_[0]'. Valid formats: @{[
									join(', ', sort keys %FORMAT_TO_MIME_MAP)
								]}\n";
						}
					}
				} ],
			] } ],
		],
		handler => sub ($opt, $usage) {
			# Handle accept format
			my $accept_mime =
				( ! defined $opt->{accept_source}
				? $DEFAULT_ACCEPT
				: ( $opt->{accept_source} eq 'format'
					? $FORMAT_TO_MIME_MAP{lc($opt->format)}
					: $opt->accept )
				);

			# Handle query source
			my $sparql_query;
			SET_SPARQL_QUERY: {
				last SET_SPARQL_QUERY unless defined $opt->{query_source};
				if ($opt->{query_source} eq 'file') {
					$sparql_query = path($opt->file)->slurp_utf8;
				} elsif ($opt->{query_source} eq 'query') {
					$sparql_query = $opt->query;
				}
			}
			# If no query source specified, will use default in query_qendpoint

			query_qendpoint($opt->target, $sparql_query, $accept_mime);
		},
	},
	'list' => {
		sort_key => 30,
		description => 'List qendpoint instances',
		options => [
			[ 'output_format' => hidden => {
				one_of => [
					[ 'table', "Output as formatted table (default)" ],
					[ 'json|j', "Output as JSONL (one JSON object per line)" ],
					[ 'tsv', "Output as TSV (tab-separated values)" ],
				], default => 'table' } ],
		],
		handler => sub ($opt, $usage) { list_instances($opt->output_format) },
	},
	'stop' => {
		sort_key => 40,
		description => 'Stop a qendpoint instance',
		options => [
			[ 'target|t=s', "HDT file path or instance ID (required)", {
				callbacks => { _mk_required_param('target') =>, }
			} ],
		],
		handler => sub ($opt, $usage) { stop_instance($opt->target) },
	},
	'stop-all' => {
		sort_key => 50,
		description => 'Stop all running qendpoint instances',
		options => [],
		handler => sub ($opt, $usage) { stop_all_instances() },
	},
	'shell-config' => {
		sort_key => 60,
		description => 'Generate shell configuration for a qendpoint instance',
		options => [
			[ 'target|t=s', "HDT file path or instance ID (required)", {
				callbacks => { _mk_required_param('target') =>, }
			} ],
		],
		handler => sub ($opt, $usage) { shell_config($opt->target) },
	},
	'cleanup' => {
		sort_key => 70,
		description => 'Remove stopped instance directories',
		options => [],
		handler => sub ($opt, $usage) { cleanup_instances() },
	},
);

sub run {
# Main script
my $subcommand = shift @ARGV || '';

# Define sorted subcommands for help display
my @sorted_subcommands = sort { $DISPATCH{$a}{sort_key} <=> $DISPATCH{$b}{sort_key} } keys %DISPATCH;
my $max_subcommand_len = max map { length } @sorted_subcommands;

# Handle help at top level - show available subcommands
if (!$subcommand || $subcommand eq 'help' || $subcommand eq '--help' || $subcommand eq '-h') {
	say <<~"EOF";
	qendpoint-manage - Manage qendpoint SPARQL instances

	USAGE:
	    qendpoint-manage <subcommand> [options]

	SUBCOMMANDS:
	@{[ join qq{\n}, map { sprintf "    %-${max_subcommand_len}s %s", $_, $DISPATCH{$_}{description} } @sorted_subcommands ]}

	For help with a specific subcommand:
	    qendpoint-manage <subcommand> --help

	For complete documentation:
	    qendpoint-manage --man
	EOF
	exit 0;
}

# Handle --man at top level
if ($subcommand eq '--man') {
	pod2usage(-input => __FILE__, -exitval => 0, -verbose => 2);
}

# Check if subcommand exists
unless (exists $DISPATCH{$subcommand}) {
	say STDERR <<~"EOF";
	Error: Unknown subcommand '$subcommand'

	Available subcommands:
	@{[ join qq{\n}, map { "    $_" } @sorted_subcommands ]}
	For help: qendpoint-manage --help
	EOF
	exit 1;
}

# Execute subcommand
my $cmd_info = $DISPATCH{$subcommand};
my @options = @{$cmd_info->{options}};
my ($opt, $usage) = describe_options(
	"qendpoint-manage $subcommand %o",
	( @options ? (@options, []) : () ),
	[ 'help|h', "Show this help message" ],
	[ 'man', "Show manual page", { hidden => 1 } ],
);

# Handle help and man options
if ($opt->help) {
	say $usage->text;
	exit 0;
}

if ($opt->man) {
	pod2usage(-exitval => 0, -verbose => 2);
}

# Validate constraints before calling handler
eval { validate_constraints($opt, $usage) };
if ($@) {
	say STDERR $@;
	say $usage->text;
	exit 1;
}

# Execute the handler
$cmd_info->{handler}->($opt, $usage);
}

1;

__END__

=encoding UTF-8

=head1 NAME

qendpoint-manage - Manage qendpoint instances for HDT file SPARQL queries

=head1 SYNOPSIS

qendpoint-manage <subcommand> [options]

=head1 DESCRIPTION

qendpoint-manage is a tool for managing qendpoint instances that serve SPARQL queries
against HDT (Header-Dictionary-Triples) files. It handles instance lifecycle management,
query execution, and provides utilities for working with HDT-based SPARQL endpoints.

=head1 SUBCOMMANDS

=head2 start

Start a new qendpoint instance serving an HDT file.

    qendpoint-manage start --hdt-file <HDT_FILE>

Options:

=over 4

=item B<--hdt-file> <path>

Required. Path to the HDT file to serve.

=back

=head2 query

Execute a SPARQL query against a running qendpoint instance.

    qendpoint-manage query --target <HDT_FILE|INSTANCE_ID> [options]

Options:

=over 4

=item B<--target|-t> <path|id>

Required. HDT file path or instance ID to query.

=item B<--query|-q> <string>

SPARQL query string. Cannot be used with --file.

=item B<--file|-f> <path>

Read SPARQL query from file. Cannot be used with --query.

=item B<--accept|-a> <mime-type>

Accept header format (MIME type) for results. Default: application/sparql-results+json

=item B<--format> <format>

Format shortcut. Valid values: json xml csv tsv

=back

If neither --query nor --file is specified, uses a default query:

    SELECT *
    WHERE {
        ?subj ?pred ?obj .
    }
    LIMIT 10

=head2 list

List all qendpoint instances.

    qendpoint-manage list [options]

Options:

=over 4

=item B<--json|-j>

Output as JSONL (one JSON object per line).

=item B<--tsv>

Output as TSV (tab-separated values).

=item B<--table>

Output as formatted table (default).

=back

=head2 stop

Stop a running qendpoint instance.

    qendpoint-manage stop --target <HDT_FILE|INSTANCE_ID>

Options:

=over 4

=item B<--target|-t> <path|id>

Required. HDT file path or instance ID to stop.

=back

=head2 stop-all

Stop all running qendpoint instances.

    qendpoint-manage stop-all

=head2 shell-config

Generate shell configuration for a running instance.

    qendpoint-manage shell-config --target <HDT_FILE|INSTANCE_ID>

Options:

=over 4

=item B<--target|-t> <path|id>

Required. HDT file path or instance ID.

=back

Outputs shell commands to set SPARQL_ENDPOINT environment variable.

=head2 cleanup

Remove configuration for stopped instances.

    qendpoint-manage cleanup

This command removes the configuration directories for instances that have been stopped and are no longer running.

=head1 EXAMPLES

=head2 Starting a new instance

    # Start serving an HDT file
    qendpoint-manage start --hdt-file /path/to/data.hdt

    # Output:
    # Instance ID: qendpoint_1234567890_001
    # Port: 8080
    # PID: 12345

=head2 Querying an instance

    # Query using default SPARQL
    qendpoint-manage query --target /path/to/data.hdt

    # Query with custom SPARQL
    qendpoint-manage query --target /path/to/data.hdt \
        --query 'SELECT ?s WHERE { ?s a <http://example.org/Person> } LIMIT 10'

    # Query from file
    qendpoint-manage query --target qendpoint_1234567890_001 \
        --file query.sparql

    # Query with CSV output
    qendpoint-manage query --target /path/to/data.hdt \
        --format csv --query 'SELECT * WHERE { ?s ?p ?o } LIMIT 100'

=head2 Managing instances

    # List all instances (default table format)
    qendpoint-manage list

    # List as JSON
    qendpoint-manage list --json

    # List as TSV
    qendpoint-manage list --tsv

    # List as formatted table (explicit)
    qendpoint-manage list --table

    # Stop an instance
    qendpoint-manage stop --target qendpoint_1234567890_001

    # Stop all running instances
    qendpoint-manage stop-all

    # Clean up stopped instances
    qendpoint-manage cleanup

=head2 Shell integration

    # Set environment variables for an instance
    eval $(qendpoint-manage shell-config --target /path/to/data.hdt)

    # Now you can use curl directly
    curl -X POST "$SPARQL_ENDPOINT" \
        -H "Accept: application/sparql-results+json" \
        -H "Content-Type: application/sparql-query" \
        -d 'SELECT * WHERE { ?s ?p ?o } LIMIT 10'

=head1 CONFIGURATION

qendpoint-manage stores its configuration in C<~/.config/qendpoint-manage/>

The directory structure is:

    ~/.config/qendpoint-manage/
    ├── graph-set/                                       # Indexed HDT files
    │   └── <graph-set-id>/
    │       ├── graph-set.json
    │       ├── index_dev.hdt -> /path/to/original.hdt
    │       └── index_dev.hdt.index.v1-1
    └── instance/                                        # Running instances
        └── <instance-id>/
            ├── instance.json
            ├── qendpoint.log
            ├── qendpoint.err
            ├── repo_model.ttl
            └── qendpoint/
                └── hdt-store/
                    ├── index_dev.hdt -> ../../graph-set/.../index_dev.hdt
                    └── index_dev.hdt.index.v1-1 -> ../../graph-set/.../index_dev.hdt.index.v1-1

=head1 DEPENDENCIES

=over 4

=item * C<qendpoint.sh> - The qendpoint server

=item * C<qepSearch.sh> - HDT indexing tool

=item * C<curl> - For executing SPARQL queries

=item * Java runtime - Required by qendpoint

=back

=head1 ENVIRONMENT

=over 4

=item C<JAVA_OPTIONS>

Java options passed to qendpoint. Set automatically by this tool.

=item C<SPARQL_ENDPOINT>

Set by shell-config subcommand. Contains the SPARQL endpoint URL.

=back

=head1 FILES

=over 4

=item C<~/.config/qendpoint-manage/>

Configuration directory containing graph-sets and instances. See L</CONFIGURATION> for details.

=back

=head1 SEE ALSO

L<https://github.com/the-qa-company/qEndpoint>

=cut
