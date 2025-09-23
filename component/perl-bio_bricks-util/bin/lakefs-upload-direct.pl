#!/usr/bin/env perl

use Bio_Bricks::Common::Setup ':base';

use Getopt::Long::Descriptive;
use Text::CSV;
use Data::Printer;
use MIME::Base64;
use IPC::Run;
use Term::ANSIColor;
use Number::Bytes::Human qw(format_bytes);
use Object::Util;
use failures qw(
	lakectl::command
	lakectl::not_found
	lakectl::exit_code
);
use lib '../perl-bio_bricks-lakefs/lib';
use Bio_Bricks::LakeFS::Repo;
use Bio_Bricks::LakeFS::Lakectl;

# Parse command-line options
my ($opt, $usage) = describe_options(
	'lakefs-upload-direct.pl %o',
	[ 'dry-run|n',       'perform a dry run (don\'t actually upload)' ],
	[ 'verbose|v',       'show verbose output' ],
	[ 'test-repo=s',     'only process the specified LakeFS repository' ],
	[ 'delete-branch|d', 'delete existing branch before creating (clean slate)' ],
	[],
	[ 'help|h',          'print usage message and exit', { shortcircuit => 1 } ],
);

print($usage->text), exit if $opt->help;

my $dry_run = $opt->dry_run;
my $verbose = $opt->verbose;
my $test_repo_only = $opt->test_repo;
my $delete_branch = $opt->delete_branch;

# Repository cache for object-oriented interface
my %repo_objects;

# LakeFS lakectl client
my $lakectl = Bio_Bricks::LakeFS::Lakectl->new(verbose => $verbose);

# Helper to get repository object
fun get_repo($repo_name) {
	return $repo_objects{$repo_name} //= Bio_Bricks::LakeFS::Repo->new(name => $repo_name);
}

# Helper functions for exception handling
fun format_failure_message($failure) {
	my $msg = $failure->msg;
	if ($failure->payload && ref $failure->payload eq 'HASH') {
		my $payload = $failure->payload;

		if ($payload->{stderr} && $payload->{stderr} =~ /\S/) {
			$msg .= "\nSTDERR: " . $payload->{stderr};
		}
		if ($payload->{stdout} && $payload->{stdout} =~ /\S/) {
			$msg .= "\nSTDOUT: " . $payload->{stdout};
		}
		if ($payload->{exit_code}) {
			$msg .= "\nExit code: " . $payload->{exit_code};
		}
		if ($payload->{command} && ref $payload->{command} eq 'ARRAY') {
			$msg .= "\nCommand: " . join(' ', @{$payload->{command}});
		}
	}
	return $msg;
}

fun warn_lakectl_exception($prefix, $exception, $color = 'red') {
	my $error_msg = $exception->$_isa('failure') && ref($exception) =~ /Bio_Bricks::LakeFS::Error/
				   ? format_failure_message($exception) : "$exception";
	warn colored("$prefix: $error_msg", $color);
}

# Read the filtered CSV file
my $csv_file = 'biobricks-rdf-scan-filtered.csv';
my $tsv_file = 'lakefs-repo-mappings.tsv';

# Read TSV mappings first to get lakefs repo names
my %mappings;
my $tsv = Text::CSV->new({ binary => 1, auto_diag => 1, sep_char => "\t" });
open my $tsv_fh, '<', $tsv_file or die "Cannot open $tsv_file: $!";

# Skip header
$tsv->getline($tsv_fh);

while (my $row = $tsv->getline($tsv_fh)) {
	my ($source_repo, $source_file, $lakefs_repo, $lakefs_path) = @$row;
	$mappings{$source_repo}{$source_file} = {
		lakefs_repo => $lakefs_repo,
		lakefs_path => $lakefs_path
	};
}
close $tsv_fh;

# Read the RDF scan CSV
my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
open my $fh, '<', $csv_file or die "Cannot open $csv_file: $!";

# Skip header
$csv->getline($fh);

# Process each row and collect data
my %repo_data;  # Group by lakefs_repo and revision

while (my $row = $csv->getline($fh)) {
	my ($repo, $type, $stage, $path, $s3, $rev) = @$row;

	# Skip if no mapping exists
	next unless exists $mappings{$repo} && exists $mappings{$repo}{$path};

	my $lakefs_repo = $mappings{$repo}{$path}{lakefs_repo};
	my $lakefs_path = $mappings{$repo}{$path}{lakefs_path};


	# Group by lakefs repo and revision
	push @{$repo_data{$lakefs_repo}{$rev}}, {
		source_repo => $repo,
		source_path => $path,
		source_stage => $stage,
		s3_uri => $s3,
		lakefs_path => $lakefs_path,
	};
}

close $fh;

# Stats
my $total_files = 0;
my $total_repos = 0;
my $total_branches = 0;
my $files_uploaded = 0;
my $files_failed = 0;

# Process each lakefs repo
for my $lakefs_repo (sort keys %repo_data) {
	# Test mode: Skip all repos except the specified one
	if ($test_repo_only) {
		next unless $lakefs_repo eq $test_repo_only;
	}

	$total_repos++;

	say colored("=" x 60, 'cyan');
	say colored("Repository: $lakefs_repo", 'cyan');
	say colored("=" x 60, 'cyan');

	# Get repository object (shared for all revisions)
	my $repo = get_repo($lakefs_repo);
	my $target_branch = $repo->branch('develop');

	# Process each revision for this repo
	for my $rev (sort keys %{$repo_data{$lakefs_repo}}) {
		my $branch = "rev-$rev";
		my $files = $repo_data{$lakefs_repo}{$rev};
		$total_branches++;

		# Build biobricks ref for this revision
		my $source_repo = $files->[0]{source_repo};
		my $github_url = "https://github.com/biobricks-ai/$source_repo";
		my $biobricks_ref = "${github_url}#${rev}";

		# Get branch object for this revision
		my $branch_obj = $repo->branch($branch);

		# Check if branch exists
		my $branch_exists = 0;
		if (!$dry_run) {
			try {
				my $branches = $lakectl->list_branches($repo, parse => 1);
				$branch_exists = 1 if grep { $_->{id} eq $branch } @$branches;
			} catch ($e) {
				warn_lakectl_exception("  Warning: Failed to list branches", $e, 'yellow');
			}
		}

		# Delete branch first if requested (clean slate)
		if ($delete_branch && $branch_exists) {
			say "\n" . colored("Deleting existing branch $branch for clean slate...", 'yellow');
			if ($dry_run) {
				say colored("  [DRY RUN] Would delete branch: @{[$branch_obj->lakefs_uri()]}", 'magenta');
			} else {
				try {
					$lakectl->delete_branch($branch_obj);
					say colored("  ✓ Branch deleted", 'green') if $verbose;
					$branch_exists = 0;  # Mark as no longer existing
				} catch ($e) {
					warn_lakectl_exception("  Failed to delete branch", $e);
					next;
				}
			}
		}

		# Create branch if it doesn't exist
		if ($branch_exists && !$delete_branch) {
			say "\n" . colored("Branch $branch already exists", 'cyan');
		} else {
			say "\n" . colored("Creating branch $branch...", 'yellow');
			if ($dry_run) {
				say colored("  [DRY RUN] Would create branch: @{[$branch_obj->lakefs_uri()]} from @{[$target_branch->lakefs_uri()]}", 'magenta');
			} else {
				try {
					$lakectl->create_branch($branch_obj, $target_branch);
					say colored("  ✓ Branch created from @{[$target_branch->lakefs_uri()]}", 'green') if $verbose;
				} catch ($e) {
					warn_lakectl_exception("  Failed to create branch", $e);
					next;
				}
			}
		}

		# Process each file in this revision
		my $all_files_match = 1;
		for my $file (@$files) {
			my $s3_uri = $file->{s3_uri};
			my $lakefs_path = $file->{lakefs_path};
			my $source_path = $file->{source_path};
			$total_files++;

			# Extract expected MD5 from S3 path
			my $expected_md5 = "";
			if ($s3_uri =~ m{/md5/([0-9a-f]{2})/([0-9a-f]{30,})}) {
				$expected_md5 = "$1$2";
			}

			my $lakefs_uri = "lakefs://$lakefs_repo/$branch/$source_path";

			if ($dry_run) {
				say colored("\n[DRY RUN] Would check/upload: $source_path", 'magenta');
				$files_uploaded++;
			} else {
				# Check if file already exists
				my $file_stat;
				my $file_exists = 0;
				my ($lakefs_checksum, $lakefs_size);

				try {
					$file_stat = $lakectl->stat($lakefs_uri);
					$file_exists = 1 if $file_stat && %$file_stat;
					$lakefs_checksum = $file_stat->{checksum} if $file_stat;
					$lakefs_size = $file_stat->{size} if $file_stat;
				} catch ($e) {
					# File doesn't exist or other error - this is expected for new uploads
					$file_exists = 0;
				}

				if ($file_exists && $lakefs_checksum && $lakefs_checksum eq $expected_md5) {
					# File exists with correct checksum
					say colored("\nVerifying existing file: $source_path", 'cyan');
					say "  Expected MD5: $expected_md5" if $verbose;
					say "  LakeFS MD5: $lakefs_checksum" if $verbose;
					say colored("  ✓ File exists with correct checksum (Size: " .
							  format_bytes($lakefs_size) . ")", 'green');
					$files_uploaded++;
				} else {
					# File doesn't exist, has wrong checksum, or we couldn't verify - upload it
					if ($file_exists && $lakefs_checksum && $lakefs_checksum ne $expected_md5) {
						say colored("\nRe-uploading $source_path (checksum mismatch)...", 'yellow');
						say "  Expected MD5: $expected_md5" if $verbose;
						say "  LakeFS MD5: $lakefs_checksum" if $verbose;
					} else {
						# File doesn't exist, upload it
						say colored("\nUploading $source_path...", 'yellow');
					}
					say "  Source: $s3_uri" if $verbose;
					say "  Destination: $lakefs_uri" if $verbose;
					say "  Expected MD5: $expected_md5" if $verbose;

					say "  Downloading from S3 and uploading to LakeFS..." if $verbose;

					my $success = IPC::Run::run(
						['aws', 's3', 'cp', $s3_uri, '-'],
						'|',
						['lakectl', 'fs', 'upload', '--source', '-', $lakefs_uri]
					);

					if (!$success) {
						warn colored("  ✗ Upload failed", 'red');
						$all_files_match = 0;
						$files_failed++;
						next;
					}

					# Verify checksum after upload
					say "  Verifying checksum..." if $verbose;
					try {
						$file_stat = $lakectl->stat($lakefs_uri);
						$lakefs_checksum = $file_stat->{checksum} if $file_stat;
						$lakefs_size = $file_stat->{size} if $file_stat;
					} catch ($e) {
						warn_lakectl_exception("    Warning: Failed to verify upload", $e, 'yellow');
						$lakefs_checksum = undef;
						$lakefs_size = undef;
					}

					if ($lakefs_checksum) {
						if ($lakefs_checksum eq $expected_md5) {
							say colored("  ✓ Uploaded successfully (MD5: $lakefs_checksum, Size: " .
									  format_bytes($lakefs_size) . ")", 'green');
							$files_uploaded++;
						} else {
							warn colored("  ✗ Checksum mismatch! Expected: $expected_md5, Got: $lakefs_checksum", 'red');
							$all_files_match = 0;
							$files_failed++;
						}
					} else {
						warn colored("  ⚠ Could not verify checksum", 'yellow');
						$all_files_match = 0;
						$files_uploaded++;
					}
				}
			}
		}

		# Check if we need to commit or if everything already matches
		my $should_commit = 1;  # Default to committing

		if ($branch_exists && $all_files_match && !$dry_run) {
			# All files exist with correct checksums, check for existing commit
			say colored("\nAll files exist with correct checksums, checking for existing commit...", 'cyan');

			# Get the log for this branch to find the relevant commit
			try {
				my $log_output = $lakectl->log($branch_obj, amount => 10);

				# Look for a commit with matching biobricks-ref
				if ($log_output =~ /ID:\s+(\S+).*?biobricks-ref\s*=\s*\Q$biobricks_ref\E/ms) {
					my $existing_commit = $1;
					say colored("  ✓ Found existing commit for $biobricks_ref", 'green');
					say colored("    Commit ID: $existing_commit", 'green');

					# Show the full commit details
					if ($verbose) {
						say "\n" . colored("Commit details:", 'cyan');
						my $detailed_log = $lakectl->log($branch_obj, amount => 1);
						say $detailed_log;
					}

					# Show diff between develop and this branch
					say "\n" . colored("Files in this branch (diff from @{[$target_branch->name]}):", 'cyan');
					my $diff_output = $lakectl->diff($target_branch, $branch_obj);
					if ($diff_output && $diff_output =~ /\S/) {
						say $diff_output;
					} else {
						say colored("  No differences from @{[$target_branch->name]} branch", 'yellow');
					}

					$should_commit = 0;  # Found existing commit, no need to commit
					next; # Skip to next revision
				} else {
					# Files match but no commit found - need to create commit
					say colored("  Files match but no commit found with biobricks-ref=$biobricks_ref", 'yellow');
					say colored("  Creating commit for existing files...", 'yellow');
				}
			} catch ($e) {
				warn_lakectl_exception("  Warning: Failed to check commit log", $e, 'yellow');
			}
		}

		# Commit if needed
		if ($should_commit) {
			say colored("\nCommitting changes...", 'yellow');

			# Build file metadata for JSON
			my @file_metadata;
			for my $file (@$files) {
				# Extract MD5 from S3 URI
				my $dvc_md5 = "";
				if ($file->{s3_uri} =~ m{/md5/([0-9a-f]{2})/([0-9a-f]{30,})}) {
					$dvc_md5 = "$1$2";
				}

				push @file_metadata, {
					path => $file->{source_path},
					dvc_stage => $file->{source_stage},
					dvc_md5 => $dvc_md5,
				};
			}

			# Generate JSON and Base64 encode it
			my $files_json = JSON::PP->new->canonical->encode(\@file_metadata);
			my $files_json_base64 = encode_base64($files_json, ''); # No line breaks

			# Commit message
			my $commit_message_title = "feat(data): Import RDF/HDT files from $biobricks_ref";

			my $commit_message_paras_joined = join "\n\n", $commit_message_title;

			if ($dry_run) {
				say colored("  [DRY RUN] Would commit with message: $commit_message_paras_joined", 'magenta');
				if ($verbose) {
					my $files_metadata_len = length($files_json_base64);
					print <<~EOF;
					  Metadata:
						source-repo-rev: $rev
						source-repo-url: $github_url
						source-commit-url: https://github.com/biobricks-ai/$source_repo/commit/$rev
						biobricks-ref: $biobricks_ref
						file-metadata-base64: <$files_metadata_len bytes>
					EOF
				}
			} else {
				say colored("  Commit with message: $commit_message_paras_joined", 'cyan');
				try {
					my $commit_output = $lakectl->commit(
						$branch_obj, $commit_message_paras_joined,
						metadata => {
							"source-repo-rev" => $rev,
							"source-repo-url" => $github_url,
							"source-commit-url" => "https://github.com/biobricks-ai/$source_repo/commit/$rev",
							"biobricks-ref" => $biobricks_ref,
							"file-metadata-base64" => $files_json_base64,
							#"lakefs-commit-seed" => "0",
						}
					);

					my $commit_id = '';
					if ($commit_output =~ /ID:\s+(\S+)/m) {
						$commit_id = $1;
					}
					say colored("  ✓ Committed successfully (ID: $commit_id)", 'green');
				} catch ($e) {
					warn_lakectl_exception("  ✗ Commit failed", $e);
				}
			}
		}
	}
}

# Print summary
say "\n" . colored("=" x 60, 'cyan');
say colored("Summary:", 'cyan');
say colored("=" x 60, 'cyan');
say "Total repositories processed: $total_repos";
say "Total branches created: $total_branches";
say "Total files: $total_files";
if (!$dry_run) {
	say colored("Files uploaded successfully: $files_uploaded", 'green');
	say colored("Files failed: $files_failed", 'red') if $files_failed > 0;
} else {
	say colored("DRY RUN - no files were actually uploaded", 'magenta');
}

# Generate merge commands
if (!$dry_run && $files_uploaded > 0) {
	say "\n" . colored("Optional: Merge branches to main:", 'yellow');
	for my $lakefs_repo (sort keys %repo_data) {
		next if $test_repo_only && $lakefs_repo ne $test_repo_only;
		my $repo = get_repo($lakefs_repo);
		my $target_branch = $repo->branch('develop');
		for my $rev (sort keys %{$repo_data{$lakefs_repo}}) {
			my $branch = "rev-$rev";
			my $branch_obj = $repo->branch($branch);
			say "  lakectl merge @{[$branch_obj->lakefs_uri()]} @{[$target_branch->lakefs_uri()]}";
		}
	}
}

