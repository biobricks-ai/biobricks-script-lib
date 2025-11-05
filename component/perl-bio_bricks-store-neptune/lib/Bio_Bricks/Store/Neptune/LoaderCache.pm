package Bio_Bricks::Store::Neptune::LoaderCache;
# ABSTRACT: CHI-based caching for Neptune loader job details

use Bio_Bricks::Common::Setup;
use Types::Path::Tiny qw(Path);
use File::HomeDir;
use CHI;

with qw(MooX::Log::Any);

=head1 NAME

Bio_Bricks::Store::Neptune::LoaderCache - CHI-based caching for Neptune loader job details

=head1 SYNOPSIS

	use Bio_Bricks::Store::Neptune::LoaderCache;

	my $cache = Bio_Bricks::Store::Neptune::LoaderCache->new(
		cache_dir => '/tmp/neptune-loader-cache',
		neptune   => $neptune_instance,
	);

	# Get cached job status (fetches from Neptune if not cached)
	my $job_status = $cache->get_job_status($load_id);

	# Cache is automatic:
	# - Completed jobs: cached forever
	# - Failed jobs: cached forever
	# - Active/queued jobs: cached for short time

=head1 DESCRIPTION

This module provides CHI-based caching for Neptune bulk loader job details.
Completed and failed load jobs are cached forever to avoid repeated API calls,
while active jobs are cached for a short time to allow status updates.

=cut

# Neptune client - required for fetching job details
ro neptune => (
	isa => InstanceOf['Bio_Bricks::Store::Neptune'],
	required => 1,
);

# Cache directory
ro cache_dir => (
	isa => Path,
	coerce => 1,
	default => sub {
		return path(
			File::HomeDir->my_data // path(File::HomeDir->my_home, '.local', 'share'),
			'bio_bricks-store-neptune',
			'loader-cache'
		);
	},
);

# CHI cache instance
lazy cache => method() {
	$self->cache_dir->mkpath unless $self->cache_dir->exists;

	return CHI->new(
		driver     => 'File',
		root_dir   => $self->cache_dir->stringify,
		namespace  => 'neptune_loader',
	);
};

# Cache expiration times (Enum[qw(now never)] | CHI::Types::Duration)
ro completed_ttl => (
	default => 'never',  # Never expire - end state
);

ro failed_ttl => (
	default => 'never',  # Never expire - end state
);

ro active_ttl => (
	default => 60,  # 1 minute for active/queued jobs
);

ro unknown_ttl => (
	default => 300,  # 5 minutes for unknown status
);

=head1 METHODS

=method get_job_status

Get job status from cache or fetch from Neptune if not cached.

	my $status = $cache->get_job_status($load_id);

	# With additional parameters
	my $status = $cache->get_job_status($load_id, {
		details => 1,
		errors  => 1,
		page    => 1,
		errorsPerPage => 20,
	});

Parameters:
- C<details> - Include extended information (default: 0)
- C<errors> - Include list of errors (default: 0)
- C<page> - Error result page number (default: 1)
- C<errorsPerPage> - Number of errors per page (default: 10)

Returns the full job status hashref, or undef if the job doesn't exist.

Note: Requests with errors=1 or details=1 are NOT cached, since they
may include dynamic error information.

=cut

method get_job_status(Str $load_id, Maybe[HashRef] $params = undef) {
	# Don't cache requests with details or errors
	my $use_cache = !($params && ($params->{details} || $params->{errors}));

	my $cache_key = "job:$load_id";

	# Try cache first (only for basic status)
	if ($use_cache) {
		my $cached = $self->cache->get($cache_key);
		if ($cached) {
			$self->log->debug("Cache hit for load ID", { load_id => $load_id });
			return $cached;
		}
	}

	# Cache miss or uncacheable request - fetch from Neptune
	$self->log->debug("Cache miss for load ID", { load_id => $load_id, params => $params });

	my $job_status = do {
		try {
			$self->neptune->get_loader_status($load_id, $params);
		} catch ($e) {
			$self->log->error("Failed to fetch job status", { load_id => $load_id, error => $e });
			return undef;
		}
	};

	return unless $job_status;

	# Cache the result with appropriate TTL based on status (only basic requests)
	if ($use_cache) {
		$self->_cache_job_status($load_id, $job_status);
	}

	return $job_status;
}

=method get_all_load_ids

Get list of all load IDs from Neptune (with optional caching).

	my @load_ids = $cache->get_all_load_ids();

	# With parameters
	my @load_ids = $cache->get_all_load_ids({
		limit => 50,
		includeQueuedLoads => 0,
	});

Parameters:
- C<limit> - Maximum number of load IDs to return (1-100, default: 100)
- C<includeQueuedLoads> - Include queued loads (default: 1)

=cut

method get_all_load_ids(Maybe[HashRef] $params = undef) {
	my $cache_key = 'all_load_ids';

	# Add params to cache key if specified
	if ($params && %$params) {
		my $params_str = join('_', map { "$_=$params->{$_}" } sort keys %$params);
		$cache_key .= ":$params_str";
	}

	# Short cache for load ID list (30 seconds)
	my $cached = $self->cache->get($cache_key);
	if ($cached) {
		$self->log->debug("Cache hit for all load IDs", { params => $params });
		return @$cached;
	}

	# Fetch from Neptune
	my $status = do {
		try {
			$self->neptune->get_loader_status(undef, $params);
		} catch ($e) {
			$self->log->error("Failed to fetch load IDs", { error => $e });
			return;
		}
	};

	return unless $status;

	my @load_ids = @{$status->{payload}{loadIds} // []};

	# Cache for short time (load ID list changes frequently)
	$self->cache->set($cache_key, \@load_ids, 30);

	return @load_ids;
}

=method get_loader_queue

Get a hashref of S3 URI => job details for all recent loads.

	my $queue = $cache->get_loader_queue();
	# Returns: { 's3://...' => [{ load_id => ..., status => ... }] }

This is optimized for the upload script's use case of checking if a file
is already in the loader queue.

=cut

method get_loader_queue() {
	my @load_ids = $self->get_all_load_ids();
	return {} unless @load_ids;

	my $loader_queue = {};
	my $found_count = 0;

	for my $load_id (@load_ids) {
		my $job_status = $self->get_job_status($load_id);
		next unless $job_status;

		my $overall = $job_status->{payload}{overallStatus};
		next unless $overall;

		my $s3_uri = $overall->{fullUri};
		my $status_val = $overall->{status} // 'UNKNOWN';

		if ($s3_uri) {
			# Track all jobs for this S3 URI
			$loader_queue->{$s3_uri} ||= [];
			push @{$loader_queue->{$s3_uri}}, {
				load_id    => $load_id,
				status     => $status_val,
				source_uri => $s3_uri,
			};
			$found_count++;
		}
	}

	$self->log->info("Built loader queue from cache", {
		load_ids => scalar(@load_ids),
		jobs_with_uri => $found_count,
	});

	return $loader_queue;
}

=method clear_cache

Clear all cached data.

	$cache->clear_cache();

=cut

method clear_cache() {
	$self->cache->clear();
	$self->log->info("Cleared all cached data");
	return 1;
}

=method clear_job

Clear cached data for a specific job.

	$cache->clear_job($load_id);

=cut

method clear_job(Str $load_id) {
	my $cache_key = "job:$load_id";
	$self->cache->remove($cache_key);
	$self->log->debug("Cleared cache for job", { load_id => $load_id });
	return 1;
}

=method get_cache_stats

Get cache statistics.

	my $stats = $cache->get_cache_stats();

=cut

method get_cache_stats() {
	return {
		cache_dir => $self->cache_dir->stringify,
		# CHI File driver doesn't provide detailed stats, but we can check directory
		exists    => $self->cache_dir->exists,
		size      => $self->cache_dir->exists ? $self->cache_dir->child('neptune_loader')->size : 0,
	};
}

# Internal method to cache job status with appropriate TTL
method _cache_job_status(Str $load_id, HashRef $job_status) {
	my $cache_key = "job:$load_id";

	# Determine TTL based on job status
	my $overall_status = $job_status->{payload}{overallStatus}{status} // 'UNKNOWN';
	my $ttl = $self->_get_ttl_for_status($overall_status);

	# Cache with appropriate expiration
	$self->cache->set($cache_key, $job_status, $ttl);
	$self->log->debug("Cached job", { load_id => $load_id, status => $overall_status, ttl => $ttl });

	return 1;
}

# Internal method to get TTL based on status
method _get_ttl_for_status(Str $status) {
	return $self->completed_ttl if $status eq 'LOAD_COMPLETED';
	return $self->failed_ttl    if $status =~ /FAILED/;
	return $self->active_ttl    if $status eq 'LOAD_IN_PROGRESS' || $status eq 'LOAD_IN_QUEUE';
	return $self->unknown_ttl;
}

1;

__END__

=head1 CACHING STRATEGY

The module uses different cache expiration times based on job status:

=over 4

=item * B<Completed jobs> - Never expire (cached forever)

Once a load job completes, its status will never change, so we can cache it indefinitely.

=item * B<Failed jobs> - Never expire (cached forever)

Failed jobs are also an end state that won't change, so we cache them indefinitely.

=item * B<Active/Queued jobs> - 1 minute TTL

Jobs that are running or queued may change status frequently, so we cache them briefly.

=item * B<Unknown status> - 5 minute TTL

Jobs with unknown or unexpected status get a medium cache time.

=back

=head1 CACHE STORAGE

The cache uses CHI's File driver, storing data in JSON format on disk.
The default location is in a temporary directory, but you can specify
a persistent location via the C<cache_dir> parameter.

=head1 SEE ALSO

L<Bio_Bricks::Store::Neptune>
L<CHI>

=cut
