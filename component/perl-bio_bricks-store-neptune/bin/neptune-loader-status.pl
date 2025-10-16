#!/usr/bin/env perl

use Bio_Bricks::Common::Setup;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../../perl-bio_bricks-store-neptune/lib";

use Getopt::Long;
use Pod::Usage;
use JSON::PP;
use Text::Table::Tiny qw(generate_table);
use I18N::Langinfo qw(langinfo CODESET);
use POSIX qw(strftime);
use Bio_Bricks::Store::Neptune;
use Log::Any::Adapter ('Screen');
use Log::Any qw($log);

# Detect UTF-8 support and set output encoding
my $codeset = langinfo(CODESET());
my $is_utf8 = $codeset =~ /UTF-8/i;
if ($is_utf8) {
	binmode STDOUT, ':encoding(UTF-8)';
	binmode STDERR, ':encoding(UTF-8)';
}

# Command line options
my %opts = (
	neptune_endpoint => 'localhost',
	neptune_port => 8182,
	ssl_verify => 0,  # Default to disabled for localhost
	load_id => [],     # Specific load IDs to check (empty = all)
	limit => 0,        # Limit number of jobs to fetch (0 = all)
	format => 'table', # table, json, or tsv
	help => 0,
);

GetOptions(
	'neptune-endpoint|e=s' => \$opts{neptune_endpoint},
	'neptune-port=i'       => \$opts{neptune_port},
	'ssl-verify!'          => \$opts{ssl_verify},
	'load-id|l=s@'         => \$opts{load_id},     # Can specify multiple times
	'limit|n=i'            => \$opts{limit},
	'format|f=s'           => \$opts{format},
	'json|j'               => sub { $opts{format} = 'json' },
	'tsv'                  => sub { $opts{format} = 'tsv' },
	'table'                => sub { $opts{format} = 'table' },
	'help|h'               => \$opts{help},
) or pod2usage(2);

pod2usage(1) if $opts{help};

# Create Neptune client
my $neptune = Bio_Bricks::Store::Neptune->new(
	endpoint   => $opts{neptune_endpoint},
	port       => $opts{neptune_port},
	ssl_verify => $opts{ssl_verify},
);

my $json = JSON::PP->new->pretty->canonical;

# Get list of load IDs to process
my @load_ids_to_check;
if (@{$opts{load_id}}) {
	# Use specified load IDs
	@load_ids_to_check = @{$opts{load_id}};
} else {
	# Get all recent load IDs
	my $status = $neptune->get_loader_status();
	@load_ids_to_check = @{$status->{payload}{loadIds} // []};
}

# Apply limit if specified
if ($opts{limit} > 0 && @load_ids_to_check > $opts{limit}) {
	@load_ids_to_check = @load_ids_to_check[0 .. $opts{limit} - 1];
}

# Fetch detailed status for each load
my @jobs;
for my $load_id (@load_ids_to_check) {
	my $status = $neptune->get_loader_status($load_id);
	my $job = $status->{payload}{overallStatus};
	if ($job) {
		$job->{load_id} = $load_id;
		push @jobs, $job;
	}
}

# Output based on format
if ($opts{format} eq 'json') {
	print $json->encode(\@jobs);
} elsif ($opts{format} eq 'tsv') {
	output_tsv(\@jobs);
} else {
	# Default table format
	output_table(\@jobs);
}

fun output_table($jobs) {

	return print "No load jobs found\n" unless @$jobs;

	my @rows = (['LOAD_ID', 'STATUS', 'RECORDS', 'ERRORS', 'DUPES', 'TIME(s)', 'STARTED', 'SOURCE']);

	for my $job (@$jobs) {
		my $errors = ($job->{parsingErrors} // 0) + ($job->{insertErrors} // 0);
		my $source = $job->{fullUri} // 'N/A';
		# Truncate long S3 URIs for table display
		$source =~ s{^s3://([^/]+)/(.{20}).*(.{20})$}{s3://$1/...$3} if length($source) > 60;

		# Format start time
		my $start_time = 'Not started';
		if ($job->{startTime} && $job->{startTime} > 0) {
			my $epoch = $job->{startTime};
			$start_time = strftime('%Y-%m-%d %H:%M:%S', localtime($epoch));
		}

		push @rows, [
			$job->{load_id},
			$job->{status} // 'UNKNOWN',
			$job->{totalRecords} // 0,
			$errors,
			$job->{totalDuplicates} // 0,
			$job->{totalTimeSpent} // 0,
			$start_time,
			$source,
		];
	}

	print generate_table(rows => \@rows, header_row => 1, style => $is_utf8 ? 'boxrule' : 'classic');
}

fun output_tsv($jobs) {

	return unless @$jobs;

	print join("\t", 'LOAD_ID', 'STATUS', 'TOTAL_RECORDS', 'PARSING_ERRORS', 'INSERT_ERRORS', 'DUPLICATES', 'TIME_SPENT', 'SOURCE') . "\n";

	for my $job (@$jobs) {
		print join("\t",
			$job->{load_id},
			$job->{status} // 'UNKNOWN',
			$job->{totalRecords} // 0,
			$job->{parsingErrors} // 0,
			$job->{insertErrors} // 0,
			$job->{totalDuplicates} // 0,
			$job->{totalTimeSpent} // 0,
			$job->{fullUri} // 'N/A',
		) . "\n";
	}
}

__END__

=head1 NAME

neptune-loader-status.pl - Check Neptune bulk loader status

=head1 SYNOPSIS

neptune-loader-status.pl [options]

 Options:
   -e, --neptune-endpoint HOST   Neptune cluster endpoint (default: localhost)
	   --neptune-port PORT       Neptune port (default: 8182)
	   --ssl-verify / --no-ssl-verify   Verify SSL certificates (default: false for localhost)
   -l, --load-id ID             Specific load ID(s) to check (can specify multiple times)
								Default: fetch all recent load IDs
   -n, --limit N                Limit to first N jobs (default: all)
   -f, --format FORMAT          Output format: table, json, tsv (default: table)
   -j, --json                   Output as JSON (shortcut for --format json)
	   --tsv                    Output as TSV (shortcut for --format tsv)
	   --table                  Output as table (default)
   -h, --help                   Show this help message

=head1 DESCRIPTION

This script checks the status of Neptune bulk loader jobs. By default, it fetches
detailed status for all recent load jobs and displays them in a table.

You can filter to specific job IDs or limit the number of jobs fetched.

=head1 EXAMPLES

  # Check all recent load jobs (default - fetches details for each)
  neptune-loader-status.pl

  # Check only the 5 most recent jobs
  neptune-loader-status.pl --limit 5

  # Check specific load job(s)
  neptune-loader-status.pl --load-id ef5f3a23-ffe8-4d0a-83c7-e0f6aebc88cb

  # Check multiple specific jobs
  neptune-loader-status.pl \
	--load-id ef5f3a23-ffe8-4d0a-83c7-e0f6aebc88cb \
	--load-id 4732c556-b42f-4cc0-beef-8254ca585909

  # JSON output for all jobs
  neptune-loader-status.pl --json

  # TSV output for scripting
  neptune-loader-status.pl --tsv

  # Direct connection to Neptune (with SSL verification)
  neptune-loader-status.pl \
	-e my-neptune.cluster.amazonaws.com \
	--ssl-verify

=head1 OUTPUT

The script outputs JSON with loader status information:

Overall status (no --load-id):
{
  "status": "200 OK",
  "payload": {
	"overallStatus": {
	  "fullQueueSize": 0,
	  "runningJobs": 0,
	  "queuedJobs": 0,
	  "succeededJobs": 5,
	  "failedJobs": 0
	},
	"loadIds": [...]
  }
}

Specific job status (with --load-id):
{
  "status": "200 OK",
  "payload": {
	"overallStatus": {
	  "status": "LOAD_COMPLETED",
	  "totalRecords": 24540000,
	  "loadedRecords": 24540000,
	  "startTime": "2025-10-15T23:54:12.000Z"
	}
  }
}

=cut
