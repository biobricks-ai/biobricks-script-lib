package Bio_Bricks::QEndpoint::Instance {
	use strict;
	use warnings;
	use feature qw(say signatures postderef);
	use Class::Tiny qw(instance_id hdt_file hdt_md5 graph_set_dir port pid started_at status), {
		dir => sub { $Bio_Bricks::QEndpoint::App::CONFIG_DIR->child('instance', shift->instance_id) }
	};

	use Log::Any '$log';

	use Path::Tiny qw(path);
	use Capture::Tiny qw(capture);

	use POSIX qw(strftime);
	use Proc::ProcessTable;
	use File::Symlink::Relative qw(symlink_r);

	use Bio_Bricks::QEndpoint::GraphSet;
	use Bio_Bricks::QEndpoint::Util;

	my $json = JSON::MaybeXS->new->utf8(1)->canonical(1);

	sub config_file { shift->dir->child('instance.json') }
	sub qendpoint_dir { shift->dir->child('qendpoint') }
	sub hdt_store_dir { shift->qendpoint_dir->child('hdt-store') }
	sub log_file { shift->dir->child('qendpoint.log') }
	sub err_file { shift->dir->child('qendpoint.err') }
	sub repo_model_file { shift->dir->child('repo_model.ttl') }

	sub is_running {
		my $pid = shift->pid // return 0;
		return kill(0, $pid);
	}

	sub stop {
		my $self = shift;

		if ($self->is_running) {
			$log->info("Stopping qendpoint instance @{[ $self->instance_id
				]} (PID: @{[ $self->pid
				]}, Port: @{[ $self->port ]})");

			# Kill process group to ensure all child processes are terminated
			kill 'TERM', -$self->pid;

			# Wait for graceful shutdown
			my $attempts = 0;
			while ($self->is_running && $attempts < 10) {
				sleep 1;
				$attempts++;
			}

			# Force kill process group if necessary
			if ($self->is_running) {
				$log->warn("Force killing process group @{[ $self->pid ]}");
				kill 'KILL', -$self->pid;
			}

			$log->info("Instance stopped");
		} else {
			$log->warn("Process @{[ $self->pid ]} was already dead");
		}

		# Update status to stopped and save
		$self->status('stopped');
		$self->save;
	}

	sub is_process_valid {
		my $self = shift;
		my $pid = $self->pid // return 0;

		# First check if PID exists
		return 0 unless kill(0, $pid);

		# Then verify it's actually a qendpoint-manage process by checking $0 pattern
		my $pt = Proc::ProcessTable->new;

		for my $p (@{$pt->table}) {
			next unless $p->pid == $pid;
			# Try to match both the custom $0 pattern and the original script name
			return 1 if $p->cmndline =~ /\b\Q$Bio_Bricks::QEndpoint::App::PROCESS_SENTINEL\E\b:?/;
			last;
		}

		return 0;  # PID was reused for different process
	}


	sub load {
		my ($class, $instance_id) = @_;
		my $self = $class->new(instance_id => $instance_id);
		return $self unless $self->config_file->exists;

		my $data = $json->decode($self->config_file->slurp_raw);
		return $class->new(%$data, instance_id => $instance_id);
	}

	sub save {
		my $self = shift;
		$self->dir->mkpath;
		$self->config_file->spew_raw($json->encode({
			_version      => $Bio_Bricks::QEndpoint::App::SCHEMA_VERSION,
			instance_id   => $self->instance_id,
			hdt_file      => $self->hdt_file,
			hdt_md5       => $self->hdt_md5,
			graph_set_dir => $self->graph_set_dir,
			port          => $self->port,
			pid           => $self->pid,
			started_at    => $self->started_at,
			status        => $self->status
		}));
	}

	sub endpoint_url {
		my $self = shift;
		return "http://localhost:@{[ $self->port ]}/api/endpoint/sparql";
	}

	sub TO_JSON {
		my $self = shift;

		# Determine actual status based on process state
		my $actual_status = $self->status // 'unknown';
		if ($actual_status eq 'running' && !$self->is_running) {
			$actual_status = 'stopped';
		}

		return {
			instance_id   => $self->instance_id,
			hdt_file      => $self->hdt_file,
			hdt_md5       => $self->hdt_md5,
			graph_set_dir => $self->graph_set_dir,
			port          => $self->is_running ? $self->port : undef,
			pid           => $self->is_running ? $self->pid : undef,
			started_at    => $self->started_at,
			status        => $actual_status,
			directory     => $self->dir->stringify,
			endpoint      => $self->is_running ? $self->endpoint_url : undef
		};
	}

	sub create_instance {
		my ($class, $hdt_file) = @_;

		my $hdt_path = path($hdt_file);
		die "Error: HDT file not found: $hdt_file\n" unless $hdt_path->exists;

		my $hdt_file_abs = $hdt_path->realpath->stringify;
		my $md5_hash = Bio_Bricks::QEndpoint::Util::md5_file($hdt_file_abs);

		# Check if this HDT file is already being served by a running instance
		my @instances = $class->list_all;
		for my $instance (@instances) {
			next unless $instance->hdt_file eq $hdt_file_abs && $instance->is_running;
			$log->warn("HDT file is already being served by a running instance");
			$log->info("  HDT file: $hdt_file_abs");
			$log->info("  Instance ID: @{[ $instance->instance_id ]}");
			$log->info("  Port: @{[ $instance->port ]}");
			$log->info("  PID: @{[ $instance->pid ]}");
			return;
		}

		# Check for existing stopped instance for this HDT file
		my $existing_instance;
		for my $instance (@instances) {
			next unless $instance->hdt_file eq $hdt_file_abs && !$instance->is_running;
			$existing_instance = $instance;
			$log->info("Found existing stopped instance: @{[ $instance->instance_id ]}");
			last;
		}

		# Check required commands
		die "Error: qendpoint.sh not found in PATH\n" unless Bio_Bricks::QEndpoint::Util::check_command('qendpoint.sh');
		die "Error: qepSearch.sh not found in PATH\n" unless Bio_Bricks::QEndpoint::Util::check_command('qepSearch.sh');

		# Set up or reuse graph-set (this handles indexing)
		my $graph_set_dir = Bio_Bricks::QEndpoint::GraphSet->create_graph_set($hdt_file_abs, $md5_hash);

		# Reuse existing instance or create new one
		my $instance;
		if ($existing_instance) {
			# Verify the graph-set matches
			if ($existing_instance->graph_set_dir ne "$graph_set_dir") {
				$log->warn("Graph-set directory mismatch for existing instance, updating...");
				$log->info("  Old: @{[ $existing_instance->graph_set_dir ]}");
				$log->info("  New: $graph_set_dir");
			}

			# Reuse existing instance with fresh runtime settings
			$instance = $existing_instance;
			$instance->graph_set_dir("$graph_set_dir");

			# Try to reuse the previous port if it's free, otherwise find a new one.
			#
			# NOTE: For better atomicity, one could bind to the port here and hold it
			# until the new server starts, preventing race conditions with other processes.
			my $previous_port = $instance->port;
			if ($previous_port && Bio_Bricks::QEndpoint::Util::is_port_free($previous_port)) {
				$log->info("Reusing previous port: $previous_port");
			} else {
				$instance->port(Bio_Bricks::QEndpoint::Util::find_free_port());
				$log->info("Previous port unavailable, using new port: @{[ $instance->port ]}");
			}

			$instance->started_at(strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()));
			$instance->status('starting');
			# Keep existing instance_id, hdt_file, hdt_md5

			$log->info("Restarting existing instance: @{[ $instance->instance_id ]}");
		} else {
			# Create completely new instance
			my $instance_id = Bio_Bricks::QEndpoint::Util::generate_instance_id();
			$instance = $class->new(
				instance_id   => $instance_id,
				hdt_file      => $hdt_file_abs,
				hdt_md5       => $md5_hash,
				graph_set_dir => "$graph_set_dir",
				port          => Bio_Bricks::QEndpoint::Util::find_free_port(),
				started_at    => strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()),
				status        => 'starting'
			);

			$log->info("Creating new instance: @{[ $instance->instance_id ]}");
		}

		# Create instance directory structure
		$instance->hdt_store_dir->mkpath;

		# Create symlinks to individual files in the graph-set
		my $graph_set_hdt = path($graph_set_dir)->child('index_dev.hdt');
		my $graph_set_index = path($graph_set_dir)->child('index_dev.hdt.index.v1-1');

		my $hdt_link = $instance->hdt_store_dir->child('index_dev.hdt');
		$hdt_link->remove if $hdt_link->exists;
		symlink_r($graph_set_hdt, $hdt_link) or die "Failed to create HDT symlink: $!";

		# Only create index symlink if it exists (indexing might have just completed)
		if ($graph_set_index->exists) {
			my $index_link = $instance->hdt_store_dir->child('index_dev.hdt.index.v1-1');
			$index_link->remove if $index_link->exists;
			symlink_r($graph_set_index, $index_link) or die "Failed to create index symlink: $!";
		}

		# Create repo_model.ttl with port configuration
		$instance->repo_model_file->spew_utf8(sprintf(
			"\@prefix mdlc: <http://the-qa-company.com/modelcompiler/> .\n\n"
			. "# Describe the endpoint server port\n"
			. "mdlc:main mdlc:serverPort %d .\n",
			$instance->port
		));

		$ENV{JAVA_OPTIONS} = join ' ', qw(
			-Dspring.autoconfigure.exclude=org.springframework.boot.autoconfigure.http.client.HttpClientAutoConfiguration
			-Dspring.devtools.restart.enabled=false
		);

		# Start qendpoint as daemon
		$log->info("Starting qendpoint instance @{[ $instance->instance_id ]} on port @{[ $instance->port ]}...");
		$log->info("HDT file: $hdt_file_abs");
		$log->info("Graph-set: $graph_set_dir");
		$log->info("Instance: @{[ $instance->dir ]}");
		$log->info("Logs: @{[ $instance->log_file ]}");

		# Fork and start qendpoint
		my $pid = fork;
		if (!defined $pid) {
			die "Failed to fork: $!\n";
		} elsif ($pid == 0) {
			# Child process - become process group leader
			setpgrp(0, 0) or die "Cannot setpgrp: $!\n";

			chdir $instance->dir or die "Cannot chdir to @{[ $instance->dir ]}: $!\n";
			open STDOUT, '>', $instance->log_file->stringify or die "Cannot redirect stdout: $!\n";
			open STDERR, '>', $instance->err_file->stringify or die "Cannot redirect stderr: $!\n";

			# Set process name for identification
			$0 = "$Bio_Bricks::QEndpoint::App::PROCESS_SENTINEL: @{[ $instance->instance_id ]}";

			# Use system instead of exec to maintain process control
			0 == system('qendpoint.sh') or die "Cannot run qendpoint.sh\n";
			exit;
		}

		# Update instance with PID and save
		$instance->pid($pid);
		$instance->status('running');

		# Wait a moment to check if process started successfully
		sleep 2;
		unless ($instance->is_running) {
			die "Error: Failed to start qendpoint process\nCheck error log: @{[ $instance->err_file ]}\n";
		}

		# Save configuration
		$instance->save;

		$log->info("Qendpoint started successfully!");
		say "Instance ID: @{[ $instance->instance_id ]}";
		say "Port: @{[ $instance->port ]}";
		say "PID: @{[ $instance->pid ]}";
		$log->debug("  Instance directory: @{[ $instance->dir ]}");
		$log->debug("  Graph-set directory: $graph_set_dir");

		return $instance;
	}

	sub list_all {
		my ($class) = @_;
		my $instances_dir = $Bio_Bricks::QEndpoint::App::CONFIG_DIR->child('instance');
		return () unless $instances_dir->exists;

		my @instances;
		for my $instance_dir ($instances_dir->children) {
			next unless $instance_dir->is_dir;
			my $instance_id = $instance_dir->basename;
			my $instance = $class->load($instance_id);
			push @instances, $instance if $instance->config_file->exists;
		}

		return @instances;
	}

	sub find_instance {
		my ($class, $identifier) = @_;

		# Get all instances
		my @instances = $class->list_all;

		# First check if it's an instance ID
		for my $instance (@instances) {
			return $instance if $instance->instance_id eq $identifier;
		}

		# Then check if it's an HDT file path
		my $hdt_path_abs = eval { realpath($identifier) } || $identifier;
		for my $instance (@instances) {
			return $instance if $instance->hdt_file eq $hdt_path_abs || $instance->hdt_file eq $identifier;
		}

		return undef;
	}
}

1;
