#!/usr/bin/env perl

use Bio_Bricks::Common::Setup;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../../perl-bio_bricks-store-neptune/lib";

use Text::CSV;
use Getopt::Long;
use Pod::Usage;
use Path::Tiny;
use JSON::PP;
use Bio_Bricks::Common::Output qw(:basic output_header output_separator output_debug output_status);
use Bio_Bricks::Store::Neptune;
use Bio_Bricks::Store::Neptune::BulkLoader;
use Bio_Bricks::Store::Neptune::S3Staging;
use Bio_Bricks::Store::Neptune::LoadJob;
use Bio_Bricks::Store::Neptune::State;
use Bio_Bricks::Store::Neptune::LoaderCache;
use Log::Any::Adapter ('Screen');
use Log::Any qw($log);
use Carp qw(croak);

# Command line options
my %opts = (
	input => 'biobricks-rdf-scan-filtered.csv',  # Default to filtered CSV
	neptune_endpoint => undef,       # Neptune cluster endpoint
	neptune_port => 8182,           # Neptune port (default: 8182)
	region => 'us-east-1',          # AWS region
	ssl_verify => 1,                # Verify SSL certificates and hostname (disable for localhost tunnels)
	iam_role_arn => undef,          # IAM role for Neptune bulk loader
	fail_on_error => 1,             # Fail bulk load on any error
	parallelism => 'MEDIUM',        # Parallelism level (LOW, MEDIUM, HIGH, OVERSUBSCRIBE)
	update_single_cardinality => 0, # Update single cardinality properties
	queue_request => 0,             # Queue request if another load is running (default: FALSE)
	staging_s3_prefix => undef,     # S3 prefix for staging files with proper extensions
	aws_profile => undef,           # AWS profile for S3 operations
	graph_prefix => 'http://biobricks.ai/graph/',  # Graph URI prefix
	mode => 'queue',                # Loading mode: queue, wait, single
	wait_interval => 30,            # Seconds to wait between status checks (for wait mode)
	max_queue => 60,                # Maximum jobs to queue (Neptune limit ~64)
	state_file => 'neptune-load-state.json',  # File to track completed loads
	skip_completed => 1,            # Skip files that were successfully loaded
	dry_run => 0,                   # Don't actually load
	verbose => 0,                   # Verbose output
	max_files => 0,                 # Maximum number of files to process (0 = all)
	help => 0,
);

GetOptions(
	'input|i=s'            => \$opts{input},
	'neptune-endpoint|e=s' => \$opts{neptune_endpoint},
	'neptune-port=i'       => \$opts{neptune_port},
	'region=s'             => \$opts{region},
	'ssl-verify!'          => \$opts{ssl_verify},
	'iam-role|r=s'         => \$opts{iam_role_arn},
	'fail-on-error!'       => \$opts{fail_on_error},
	'parallelism=s'        => \$opts{parallelism},
	'update-single!'       => \$opts{update_single_cardinality},
	'queue-request!'       => \$opts{queue_request},
	'staging-s3-prefix=s'  => \$opts{staging_s3_prefix},
	'aws-profile=s'        => \$opts{aws_profile},
	'graph-prefix=s'       => \$opts{graph_prefix},
	'mode=s'               => \$opts{mode},
	'wait-interval=i'      => \$opts{wait_interval},
	'max-queue=i'          => \$opts{max_queue},
	'state-file=s'         => \$opts{state_file},
	'skip-completed!'      => \$opts{skip_completed},
	'dry-run|n'            => \$opts{dry_run},
	'verbose|v'            => \$opts{verbose},
	'max-files=i'          => \$opts{max_files},
	'help|h'               => \$opts{help},
) or pod2usage(2);

pod2usage(1) if $opts{help};
pod2usage("--neptune-endpoint is required") unless $opts{neptune_endpoint} || $opts{dry_run};
pod2usage("--iam-role is required") unless $opts{iam_role_arn} || $opts{dry_run};

# Validate parallelism option
my %valid_parallelism = map { $_ => 1 } qw(LOW MEDIUM HIGH OVERSUBSCRIBE);
pod2usage("Invalid parallelism: $opts{parallelism}")
	unless $valid_parallelism{$opts{parallelism}};

# Validate mode option
my %valid_modes = map { $_ => 1 } qw(queue wait single);
pod2usage("Invalid mode: $opts{mode}. Use: queue, wait, or single")
	unless $valid_modes{$opts{mode}};



fun check_queue_status($neptune) {

	output_info("Checking Neptune loader queue status...");

	my $queue_status = $neptune->get_queue_status();
	return unless %$queue_status;

	output_info("Queue Status:");
	output_info("  Total Jobs: "   . ($queue_status->{total_jobs}     // 0));
	output_info("  Running: "      . ($queue_status->{running_jobs}   // 0));
	output_info("  Queued: "       . ($queue_status->{queued_jobs}    // 0));
	output_info("  Succeeded: "    . ($queue_status->{succeeded_jobs} // 0));
	output_error("  Failed: "      . ($queue_status->{failed_jobs}    // 0)) if $queue_status->{failed_jobs};

	if ($queue_status->{recent_loads}) {
		output_info("  Recent load IDs: " . scalar(@{$queue_status->{recent_loads}}));
	}

	return $queue_status;
}


fun check_already_in_loader_queue($source_uri, $loader_queue, $staging, $file_path) {

	return 0 unless $loader_queue && %$loader_queue;

	# Check both the original source URI and the potential staged URI
	my @uris_to_check = ($source_uri);

	# If staging is configured and this file would be staged, also check staged URI
	if ($staging && $file_path && $staging->needs_staging(source_uri => $source_uri, file_path => $file_path)) {
		my $staged_uri = $staging->build_staging_uri(source_uri => $source_uri, file_path => $file_path);
		push @uris_to_check, $staged_uri;
	}

	# Check each URI
	for my $uri (@uris_to_check) {
		my $jobs = $loader_queue->{$uri};
		next unless $jobs && @$jobs;

		# Check if ANY job for this S3 URI has a target status
		for my $job (@$jobs) {
			my $status = $job->{status};
			if ($status eq 'LOAD_IN_QUEUE' || $status eq 'LOAD_IN_PROGRESS' || $status eq 'LOAD_COMPLETED') {
				return ($status, $job->{load_id}, $jobs);
			}
		}
	}

	return 0;
}

fun start_bulk_load($staging, $source_uri, $file_path, $format, $graph_uri, $metadata, $loader_queue) {

	output_warning("Starting Neptune bulk load:");
	output_info("  Source: $source_uri");
	output_info("  File: $file_path");
	output_info("  Format: $format");
	output_info("  Graph: "  . ($graph_uri // 'default'));
	output_debug("  Repo: "  . $metadata->{repo})  if $opts{verbose};
	output_debug("  Stage: " . $metadata->{stage}) if $opts{verbose};
	output_debug("  Rev: "   . $metadata->{rev})   if $opts{verbose};

	# Check if already in Neptune loader queue
	my ($existing_status, $existing_load_id, $all_jobs) = check_already_in_loader_queue($source_uri, $loader_queue, $staging, $file_path);
	if ($existing_status) {
		my $prefix = $opts{dry_run} ? "[DRY RUN] " : "";
		output_info("  ${prefix}Skipping - already in loader queue with status: $existing_status");
		if ($opts{verbose}) {
			output_info("  Matched Load ID: $existing_load_id");
			if ($all_jobs && @$all_jobs > 1) {
				output_info("  Total jobs for this S3 URI: " . scalar(@$all_jobs));
				output_info("  All job details: " . JSON::PP->new->canonical->encode($all_jobs));
			} else {
				output_info("  Job details: " . JSON::PP->new->canonical->encode($all_jobs->[0]));
			}
		}
		return undef;
	}

	if ($opts{dry_run}) {
		output_warning("  [DRY RUN] Would start bulk load");
		if ($opts{verbose} && $staging) {
			my $request = $staging->bulk_loader->build_load_request(
				source_uri => $source_uri,
				format     => $format,
				graph_uri  => $graph_uri,
			);
			output_warning("  Request:");
			say JSON::PP->new->pretty->canonical->encode($request);

			# Show if staging would be needed
			if ($staging->needs_staging(source_uri => $source_uri, file_path => $file_path)) {
				my $staged_uri = $staging->build_staging_uri(source_uri => $source_uri, file_path => $file_path);
				output_warning("  Would stage to: $staged_uri");
			}
		}
		return 'dry-run-load-id';
	}

	my $load_id;
	try {
		$load_id = $staging->load_file(
			source_uri => $source_uri,
			file_path  => $file_path,
			format     => $format,
			graph_uri  => $graph_uri,
		);
	} catch ($e) {
		output_error("  Failed to start load: $e");
		return undef;
	}

	output_success("  Load started with ID: $load_id");
	return $load_id;
}

fun main() {
	# Initialize Neptune components
	my $neptune;
	my $loader;
	my $staging;
	my $state;
	my $loader_cache;

	# Always create neptune and loader (even in dry-run for verbose output)
	$neptune = Bio_Bricks::Store::Neptune->new(
		endpoint   => $opts{neptune_endpoint} // 'localhost',
		port       => $opts{neptune_port},
		region     => $opts{region},
		ssl_verify => $opts{ssl_verify},
	);

	# Create loader cache for tracking completed jobs
	$loader_cache = Bio_Bricks::Store::Neptune::LoaderCache->new(
		neptune => $neptune,
	);

	$loader = Bio_Bricks::Store::Neptune::BulkLoader->new(
		neptune => $neptune,
		iam_role => $opts{iam_role_arn} // 'arn:aws:iam::000000000000:role/DryRun',
		region => $opts{region},
		fail_on_error => $opts{fail_on_error},
		parallelism => $opts{parallelism},
		update_single_cardinality => $opts{update_single_cardinality},
		queue_request => $opts{queue_request},
	);

	# Create S3 staging wrapper
	$staging = Bio_Bricks::Store::Neptune::S3Staging->new(
		bulk_loader => $loader,
		maybe staging_s3_prefix => $opts{staging_s3_prefix},
		maybe aws_profile => $opts{aws_profile},
	);

	if (!$opts{dry_run}) {
		$state = Bio_Bricks::Store::Neptune::State->new(
			file_path => $opts{state_file},
			neptune => $neptune,
		);

		# Show existing state summary
		my $summary = $state->summary();
		if (%$summary) {
			output_info("Loaded state from " . $state->file_path);
			for my $status (sort keys %$summary) {
				my $count = $summary->{$status};
				output_status($status, "$count");
			}

			# Update job statuses from Neptune
			my @active_jobs = $state->get_active_jobs();
			if (@active_jobs) {
				output_debug("Updating status for " . scalar(@active_jobs) . " active jobs...");
				$state->update_job_statuses();
			}
		}
	}

	# Check current queue status
	my $queue_status = {};
	my $loader_queue = {};  # Hash of S3 URI => job details for skip checking

	if (!$opts{dry_run} && $opts{neptune_endpoint}) {
		$queue_status = check_queue_status($neptune) || {};

		# Warn if queue is full
		if (($queue_status->{queued_jobs} // 0) >= 60) {
			output_error("\n⚠ WARNING: Neptune queue is nearly full!");
			output_warning("  Consider waiting for jobs to complete before submitting more.");
		}
	}

	# Fetch loader queue if skip_completed is enabled
	if ($opts{skip_completed} && $opts{neptune_endpoint}) {
		output_info("Fetching Neptune loader queue...");
		$loader_queue = $loader_cache->get_loader_queue();
	}

	# Parse the biobricks RDF scan CSV
	my $csv = Text::CSV->new({ binary => 1 });

	open my $fh, '<', $opts{input}
		or die "Cannot open $opts{input}: $!\n";

	# Read header
	my $header = $csv->getline($fh);
	die "Failed to read CSV header\n" unless $header;

	# Expected columns: repo,type,stage,path,s3,rev
	my @files_to_load;
	my $skip_count = 0;
	my $hdt_count = 0;
	my $completed_count = 0;
	my $line_num = 1;

	output_info("Reading $opts{input}...");

	while (my $row = $csv->getline($fh)) {
		$line_num++;

		my ($repo, $type, $stage, $path, $s3_uri, $rev) = @$row;

		# Skip if no S3 URI
		next unless $s3_uri;

		# Detect format from path using BulkLoader module
		my $format;
		if (!$opts{dry_run}) {
			$format = $loader->detect_format($path);
		} else {
			# Simple detection for dry run
			$format = $path =~ /\.hdt$/i ? 'unsupported' :
					  $path =~ /\.nt$/i ? 'ntriples' :
					  $path =~ /\.nq$/i ? 'nquads' :
					  $path =~ /\.ttl$/i ? 'turtle' :
					  $path =~ /\.(rdf|xml|owl)$/i ? 'rdfxml' : 'ntriples';
		}

		# Skip HDT files (they have non-HDT alternatives)
		if ($format eq 'unsupported' || $path =~ /\.hdt$/i) {
			output_warning("  Skipping HDT file: $repo/$path") if $opts{verbose};
			$hdt_count++;
			next;
		}

		# Create graph URI based on repo and stage
		my $graph_uri = $opts{graph_prefix} . "$repo/$stage";

		my $file_info = {
			repo => $repo,
			type => $type,
			stage => $stage,
			path => $path,
			s3_uri => $s3_uri,
			format => $format,
			graph_uri => $graph_uri,
			rev => $rev,
		};

		# Check if already completed
		if ($opts{skip_completed} && !$opts{dry_run}) {
			if ($state->is_already_loaded($file_info->{s3_uri}, $file_info->{graph_uri})) {
				output_success("  Already completed: $repo/$path") if $opts{verbose};
				$completed_count++;
				next;
			}
		}

		push @files_to_load, $file_info;

		# Apply max_files limit if set
		last if $opts{max_files} > 0 && @files_to_load >= $opts{max_files};
	}

	close $fh;

	output_header("File Analysis");
	output_success("  Files to process: " . scalar(@files_to_load));
	output_warning("  HDT files skipped: $hdt_count") if $hdt_count > 0;
	output_info("  Previously completed: $completed_count") if $completed_count > 0;

	if ($opts{verbose}) {
		# Show format breakdown
		my %format_counts;
		$format_counts{$_->{format}}++ for @files_to_load;
		output_header("Formats");
		for my $format (sort keys %format_counts) {
			output_info("  $format: $format_counts{$format}");
		}

		# Show repo breakdown
		my %repo_counts;
		$repo_counts{$_->{repo}}++ for @files_to_load;
		output_header("Repositories");
		for my $repo (sort keys %repo_counts) {
			output_info("  $repo: $repo_counts{$repo}");
		}
	}

	# Process each file
	output_separator(60);
	my $load_count = 0;
	my $failed_count = 0;
	my $skipped_count = 0;
	my $queued_count = 0;
	my @load_results;

	# Neptune typically allows only 1 active load at a time
	# Additional loads will be queued (max ~64 in queue)
	output_warning("Note: Neptune processes one bulk load at a time. Additional jobs will queue.");
	output_warning("      Consider using --max-files to limit the number of jobs submitted.\n");

	for my $file (@files_to_load) {
		my $file_num = $load_count + $failed_count + $skipped_count + 1;
		output_warning("\n[$file_num/" . scalar(@files_to_load) . "] $file->{repo}/$file->{path}");

		# Check if we should wait before submitting more
		if ($load_count > 0 && !$opts{dry_run}) {
			# After first successful load, warn about queueing
			if ($load_count == 1) {
				output_warning("  ⚠ This job will be queued. Neptune processes loads sequentially.");
			}

			# Prevent overwhelming the queue (Neptune typically has a ~64 job queue limit)
			if ($queued_count >= 60) {
				output_error("  ⚠ Approaching Neptune queue limit. Stopping submissions.");
				output_error("  Monitor existing jobs and run again to continue.");
				last;
			}
			$queued_count++;
		}

		# Start bulk load (automatically staging if needed)
		my $load_id = start_bulk_load(
			$staging,
			$file->{s3_uri},
			$file->{path},
			$file->{format},
			$file->{graph_uri},
			{
				repo => $file->{repo},
				stage => $file->{stage},
				rev => $file->{rev},
			},
			$loader_queue
		);

		if ($load_id) {
			push @load_results, {
				id => $load_id,
				file => $file->{path},
				repo => $file->{repo},
				graph => $file->{graph_uri},
				s3_uri => $file->{s3_uri},
			};
			$load_count++;

			# Save to state file
			if (!$opts{dry_run}) {
				my $load_job = Bio_Bricks::Store::Neptune::LoadJob->new(
					load_id => $load_id,
					source_uri => $file->{s3_uri},
					graph_uri => $file->{graph_uri},
					format => $file->{format},
					file_path => $file->{path},
					repo => $file->{repo},
					stage => $file->{stage},
					neptune => $neptune,
				);
				$state->add_job($load_job);
			}
		} else {
			# Check if it was skipped due to being in queue or an actual failure
			my ($existing_status) = check_already_in_loader_queue($file->{s3_uri}, $loader_queue, $staging, $file->{path});
			if ($existing_status) {
				$skipped_count++;
			} else {
				$failed_count++;
			}
		}

		# Small delay between API requests (not between loads, since they queue)
		sleep 0.5 unless $opts{dry_run};
	}

	# Summary
	output_separator(60);
	output_header("Neptune Bulk Load Summary");
	output_success("  Files submitted: $load_count");
	output_info("  Files skipped (already in queue): $skipped_count") if $skipped_count > 0;
	output_error("  Files failed: $failed_count") if $failed_count > 0;

	if (@load_results && !$opts{dry_run}) {
		output_info("\nLoad Jobs Started:");
		for my $load (@load_results) {
			output_info("  $load->{id} - $load->{repo}/$load->{file}");
		}

		output_warning("\nMonitor load status:");
		output_info("  Endpoint: https://$opts{neptune_endpoint}:$opts{neptune_port}/loader");

		output_warning("\nCheck individual load status:");
		for my $load (@load_results[0..2]) {  # Show first 3 examples
			last unless $load;
			output_info("  curl https://$opts{neptune_endpoint}:$opts{neptune_port}/loader?loadId=$load->{id}");
		}
		output_info("  ...") if @load_results > 3;

		output_warning("\nCheck all loads:");
		output_info("  curl https://$opts{neptune_endpoint}:$opts{neptune_port}/loader");
	}

	if ($opts{dry_run}) {
		output_warning("\n[DRY RUN] No actual loads were performed");
		output_warning("Remove --dry-run to actually load data into Neptune");
	}
}

main();

__END__

=head1 NAME

upload-biobricks-rdf-to-neptune.pl - Bulk load BioBricks RDF files into AWS Neptune

=head1 SYNOPSIS

upload-biobricks-rdf-to-neptune.pl [options]

 Options:
   -i, --input FILE              Input CSV file (default: biobricks-rdf-scan-filtered.csv)
   -e, --neptune-endpoint HOST   Neptune cluster endpoint (required)
	   --neptune-port PORT       Neptune port (default: 8182)
	   --region REGION           AWS region (default: us-east-1)
	   --ssl-verify / --no-ssl-verify   Verify SSL certificates (default: true)
										Use --no-ssl-verify for localhost tunnels
   -r, --iam-role ARN           IAM role for Neptune bulk loader (required)
	   --fail-on-error          Fail bulk load on any error (default: true)
	   --parallelism LEVEL      Parallelism (LOW, MEDIUM, HIGH, OVERSUBSCRIBE)
	   --update-single          Update single cardinality properties
	   --queue-request          Queue load if another is running (allows up to 64 queued)
	   --staging-s3-prefix PREFIX  S3 prefix for staging files (s3://bucket/prefix or bucket/prefix)
	   --aws-profile PROFILE    AWS profile for S3 operations
	   --graph-prefix PREFIX    Graph URI prefix (default: http://biobricks.ai/graph/)
	   --max-files N            Maximum number of files to process (0 = all)
   -n, --dry-run                Don't actually load
   -v, --verbose                Verbose output
   -h, --help                   Show this help message

=head1 DESCRIPTION

This script bulk loads BioBricks RDF files directly into AWS Neptune from their
existing S3 locations. It reads the biobricks-rdf-scan CSV file and processes
non-HDT RDF files using Neptune's bulk loader.

The script:
- Uses S3 URIs directly (no copying needed)
- Automatically detects RDF format from file extensions
- Skips HDT files (non-HDT alternatives exist for all data)
- Creates named graphs based on repo and stage
- Initiates Neptune bulk load jobs

=head1 REQUIREMENTS

The IAM role specified must have:
- Read access to the source S3 bucket(s)
- Read/write access to the staging S3 location (if using --staging-s3-prefix)
- Neptune bulk loader permissions

Neptune cluster must be accessible from where this script runs.

=head1 CSV FORMAT

The input CSV (biobricks-rdf-scan-filtered.csv) has columns:
  - repo: Repository name (e.g., mesh-kg, biobricks-okg)
  - type: Access type (public/private)
  - stage: DVC stage (build, download, rml, etc.)
  - path: File path in the repo
  - s3: S3 URI for the file
  - rev: Git revision

=head1 EXAMPLES

  # Load all non-HDT files
  upload-biobricks-rdf-to-neptune.pl \
	-e my-neptune.cluster.amazonaws.com \
	-r arn:aws:iam::123456789012:role/NeptuneLoadFromS3

  # Connect through localhost tunnel (SSM/SSH port forwarding)
  upload-biobricks-rdf-to-neptune.pl \
	-e localhost \
	-r arn:aws:iam::123456789012:role/NeptuneLoadFromS3 \
	--no-ssl-verify

  # Dry run to see what would be loaded
  upload-biobricks-rdf-to-neptune.pl \
	-e my-neptune.cluster.amazonaws.com \
	-r arn:aws:iam::123456789012:role/NeptuneLoadFromS3 \
	--dry-run --verbose

  # Process only first 5 files for testing
  upload-biobricks-rdf-to-neptune.pl \
	-e my-neptune.cluster.amazonaws.com \
	-r arn:aws:iam::123456789012:role/NeptuneLoadFromS3 \
	--max-files 5

  # Use high parallelism for faster loading
  upload-biobricks-rdf-to-neptune.pl \
	-e my-neptune.cluster.amazonaws.com \
	-r arn:aws:iam::123456789012:role/NeptuneLoadFromS3 \
	--parallelism HIGH

  # Queue multiple loads (allows up to 64 queued jobs)
  upload-biobricks-rdf-to-neptune.pl \
	-e my-neptune.cluster.amazonaws.com \
	-r arn:aws:iam::123456789012:role/NeptuneLoadFromS3 \
	--queue-request \
	--max-files 10

=head1 NOTES

Neptune supports: N-Triples (.nt), N-Quads (.nq), RDF/XML (.rdf, .xml, .owl), Turtle (.ttl)

Compression: Neptune supports .gz and .bz2 compressed files (single UTF-8 encoded files only)
IMPORTANT: Neptune requires S3 URIs to have proper extensions (.gz, .bz2) to detect compression.
Content-addressable URIs (like DVC) don't preserve extensions, so use --staging-s3-prefix to
automatically copy files with proper extensions before loading.

S3 Staging: When --staging-s3-prefix is set, compressed files without proper extensions
in their S3 URI will be automatically copied to the staging location with the correct extension.
Example with --staging-s3-prefix=s3://my-bucket/neptune-staging:
  Source: s3://source-bucket/.../md5/85/...5683a1
  Staged: s3://my-bucket/neptune-staging/.../md5/85/...5683a1.nt.gz

Automatically skipped files:
- HDT files (.hdt) - BioBricks data has non-HDT alternatives

Files are organized into named graphs: <graph-prefix>/<repo>/<stage>
Example: http://biobricks.ai/graph/mesh-kg/build

=cut
