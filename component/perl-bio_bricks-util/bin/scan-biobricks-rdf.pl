#!/usr/bin/env perl

use Bio_Bricks::Common::Setup ':base';

use FindBin;
use lib "$FindBin::Bin/../lib";

use Bio_Bricks::Common::GitHub::Pithub;
use Bio_Bricks::Common::DVC::LockParser;
use Bio_Bricks::Common::DVC::Iterator;
use Bio_Bricks::Common::DVC::Storage::S3;
use Bio_Bricks::Common::Config;
use Bio_Bricks::Common::AWS::Paws;
use MIME::Base64;
use Text::CSV;
use Log::Any::Adapter ('Screen');
use Log::Any qw($log);
use MooX::Struct
	RDFEntry => [
		'repo',
		'type',
		'stage',
		'path',
		's3',
		'rev',
		to_csv_row => sub {
			my $self = shift;
			return [$self->repo, $self->type, $self->stage, $self->path, $self->s3, $self->rev];
		}
	];

# RDF file extensions pattern
my $rdf_pattern = qr/\.(hdt|nt|ttl|rdf|owl|n3|jsonld|nq|trig)(?:\.(?:gz|bz2|xz))?$/i;

fun main() {
	my $org = 'biobricks-ai';
	my $output_file = 'biobricks-rdf-scan.csv';

	# Initialize CSV output
	my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });

	# Open output file
	open my $fh, '>', $output_file or die "Cannot open $output_file: $!";
	$csv->say($fh, [qw(repo type stage path s3 rev)]);

	# Initialize GitHub client
	my $pithub = Bio_Bricks::Common::GitHub::Pithub->new;

	# Initialize S3 storage
	my $config = Bio_Bricks::Common::Config->new;
	my $paws = Bio_Bricks::Common::AWS::Paws->new(region => $config->aws_region);
	my $dvc_storage = Bio_Bricks::Common::DVC::Storage::S3->new(
		base_uri => $config->s3_uri
	);

	# Get all repositories from organization (public and private)
	# Using auto-pagination to get ALL repositories
	$log->info("Fetching repositories from organization: $org");
	$pithub->auto_pagination(1);
	my $repos_result = $pithub->repos(auto_pagination => 1)->list(
		org => $org,
		type => 'all',
	);

	unless ($repos_result->success) {
		die "Failed to get repositories: " . $repos_result->response->status_line;
	}

	# With auto_pagination, we need to iterate through ALL results
	my @repos;
	while (my $row = $repos_result->next) {
		push @repos, $row;
	}

	$log->info("Found " . scalar(@repos) . " repositories in $org");

	# Process each repository
	for my $repo (@repos) {
		my $repo_name = $repo->{name};
		my $repo_type = $repo->{visibility} // ($repo->{private} ? 'private' : 'public');
		$log->info("Processing repository: $repo_name ($repo_type)");

		try {
			process_repository($pithub, $dvc_storage, $csv, $fh, $org, $repo_name, $repo_type);
		} catch ($e) {
			$log->error("Error processing $repo_name: $e");
		}
	}

	close $fh;
	say "RDF scan complete. Results written to $output_file";
}

fun process_repository($pithub, $dvc_storage, $csv, $fh, $org, $repo_name, $repo_type) {

	# Try to fetch dvc.lock file
	$log->debug("Fetching dvc.lock for $repo_name");
	my $content_result = $pithub->repos->contents->get(
		user => $org,
		repo => $repo_name,
		path => 'dvc.lock'
	);

	unless ($content_result->success) {
		$log->debug("No dvc.lock found in $repo_name");
		return;
	}

	my $file_data = $content_result->content;
	my $decoded_content = decode_base64($file_data->{content});

	# Get the commit that last modified dvc.lock
	my $rev = get_last_commit_for_file($pithub, $org, $repo_name, 'dvc.lock');
	return unless $rev;

	# Parse DVC lock file
	my $dvc_lock;
	try {
		$dvc_lock = Bio_Bricks::Common::DVC::LockParser->parse_string($decoded_content);
	} catch ($e) {
		$log->warn("Failed to parse dvc.lock in $repo_name: $e");
		return;
	}

	$log->debug("Found " . scalar(@{$dvc_lock->STAGE_NAMES}) . " stages in $repo_name");

	# Process each stage's outputs
	for my $stage_name (@{$dvc_lock->STAGE_NAMES}) {
		my $stage = $dvc_lock->get_stage($stage_name);

		for my $output (@{$stage->outs}) {
			try {
				process_output($dvc_storage, $csv, $fh, $repo_name, $repo_type, $stage_name, $output, $rev);
			} catch ($e) {
				$log->warn("Error processing output in $repo_name/$stage_name: $e");
			}
		}
	}
}

fun process_output($dvc_storage, $csv, $fh, $repo_name, $repo_type, $stage_name, $output, $rev) {

	# Create iterator for this output
	my $iterator = Bio_Bricks::Common::DVC::Iterator->new(
		storage => $dvc_storage,
		output => $output,
		recurse => 1,  # Recursively expand directories
	);

	# Process all files in the output
	while (my $item = $iterator->()) {
		if ($item->is_err()) {
			$log->debug("Iterator error in $repo_name/$stage_name: " . $item->unwrap_err());
			next;
		}

		my $file_item = $item->unwrap();
		my $file_path = $file_item->path;
		$log->trace("Checking file: $file_path");

		# Check if this is an RDF file
		next unless $file_path =~ $rdf_pattern;

		# Get S3 URI
		my $s3_uri = $file_item->uri->as_string;

		$log->info("Found RDF file in $repo_name: $file_path");

		# Create RDF entry struct
		my $entry = RDFEntry->new(
			repo  => $repo_name,
			type  => $repo_type,
			stage => $stage_name,
			path  => $file_path,
			s3    => $s3_uri,
			rev   => $rev
		);

		# Output CSV row
		$csv->say($fh, $entry->to_csv_row);
	}
}

fun get_last_commit_for_file($pithub, $org, $repo_name, $file_path) {

	# Get commits for the specific file
	my $commits_result = $pithub->repos->commits(
		user => $org,
		repo => $repo_name,
		auto_pagination => 0,
		per_page => 1
	)->list(
		params => { path => $file_path }
	);

	unless ($commits_result->success) {
		$log->debug("Failed to get commits for $file_path in $repo_name: " . $commits_result->response->status_line);
		return undef;
	}

	my $commits = $commits_result->content;
	return undef unless @$commits;

	# Return the SHA of the most recent commit that modified this file
	return $commits->[0]->{sha};
}

# Check for AWS authentication
try {
	my $config = Bio_Bricks::Common::Config->new;
	my $paws = Bio_Bricks::Common::AWS::Paws->new(region => $config->aws_region);
	$paws->validate_authentication;
	$config->validate_s3_config;
} catch ($e) {
	die "AWS configuration error: $e\n" .
		"Please set up AWS credentials and BIOBRICKS_S3_URI environment variable.\n";
}

main();
