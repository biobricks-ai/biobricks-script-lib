package Bio_Bricks::QEndpoint::GraphSet {
	use Class::Tiny qw(name hdt_files created_at), {
		dir => sub { $Bio_Bricks::QEndpoint::App::CONFIG_DIR->child('graph-set', shift->name) }
	};
	use Log::Any '$log';
	use Path::Tiny qw(path);
	use IPC::Run qw(run);
	use POSIX qw(strftime);
	use File::Symlink::Relative qw(symlink_r);

	my $json = JSON::MaybeXS->new->utf8(1)->canonical(1);

	sub config_file { shift->dir->child('graph-set.json') }
	sub hdt_store_dir { shift->dir }  # HDT files directly in graph-set dir

	sub load {
		my ($class, $name) = @_;
		my $self = $class->new(name => $name);
		return $self unless $self->config_file->exists;

		my $data = $json->decode($self->config_file->slurp_raw);
		return $class->new(%$data, name => $name, dir => $self->dir);
	}

	sub save {
		my $self = shift;
		$self->dir->mkpath;
		$self->config_file->spew_raw($json->encode({
			_version   => $Bio_Bricks::QEndpoint::App::SCHEMA_VERSION,
			created_at => $self->created_at,
			hdt_files  => $self->hdt_files
		}));
	}

	sub exists { shift->config_file->exists }

	sub get_graph_set_name {
		my ($class, $hdt_file_abs, $md5_hash) = @_;
		my $cleaned_path = path($hdt_file_abs)->basename;
		$cleaned_path =~ s/[^a-zA-Z0-9._-]/_/g;
		return "${cleaned_path}_md5-${md5_hash}";
	}

	sub create_graph_set {
		my ($class, $hdt_file_abs, $md5_hash) = @_;

		my $graph_set_name = $class->get_graph_set_name($hdt_file_abs, $md5_hash);
		my $graph_set = $class->load($graph_set_name);

		if ($graph_set->exists) {
			$log->info("Using existing graph-set: @{[ $graph_set->dir ]}");
			return $graph_set->dir;
		}

		# Create graph-set directory and symlink
		$graph_set->dir->mkpath;
		my $hdt_symlink = $graph_set->dir->child('index_dev.hdt');
		$hdt_symlink->remove if $hdt_symlink->exists;  # Remove if exists
		symlink_r($hdt_file_abs, $hdt_symlink) or die "Failed to create symlink: $!";

		# Run indexing (this creates index_dev.hdt.index.v1-1)
		$log->info("Running HDT indexing for graph-set...");
		my $in = '';  # Empty input
		my ($stdout, $stderr) = ('', '');

		# Run with output going to both console and variables
		my $qepSearch = 'qepSearch.sh';
		my $qepSearch_prefix = "[$qepSearch] ";
		my $mk_prefixer = sub {
			my ($collect, $prefix, $fh) = @_;
			return sub {
				my $output = $_[0];
				my $prefixed = $output =~ s/^/$prefix/mgr;
				print $fh $prefixed;
				$$collect .= $output;
			};
		};
		my $success = run [$qepSearch, $hdt_symlink],
			\$in,
			'>', $mk_prefixer->(\$stdout, $qepSearch_prefix, \*STDOUT),
			'2>', $mk_prefixer->(\$stderr, $qepSearch_prefix, \*STDERR);

		die "Error: Failed to index HDT file\n$stderr" unless $success;
		$log->info("Graph-set indexing complete.");

		# Save graph-set configuration
		$graph_set->created_at(strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()));
		$graph_set->hdt_files([{
			path    => $hdt_file_abs,
			md5     => $md5_hash,
			symlink => "$hdt_symlink"
		}]);
		$graph_set->save;

		$log->info("Graph-set created: @{[ $graph_set->dir ]}");
		return $graph_set->dir;
	}
}

1;
