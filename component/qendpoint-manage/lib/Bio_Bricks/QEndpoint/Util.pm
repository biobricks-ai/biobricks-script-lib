package Bio_Bricks::QEndpoint::Util {
	use strict;
	use warnings;
	use feature qw(say signatures postderef);
	use File::Which qw(which);
	use Path::Tiny qw(path);
	use Capture::Tiny qw(capture);
	use Net::EmptyPort qw(empty_port check_port);
	use Docker::Names::Random;

	sub check_command {
		my $cmd = shift;
		return defined which($cmd);
	}

	sub find_free_port {
		return empty_port();
	}

	sub is_port_free {
		my $port = shift;
		return !check_port($port);
	}

	sub generate_instance_id {
		my $dnr = Docker::Names::Random->new();

		my $instances_dir = $Bio_Bricks::QEndpoint::App::CONFIG_DIR->child('instance');
		$instances_dir->mkpath;

		# Try to get a unique name
		for my $attempt (1..10) {
			my $nice_name = $dnr->docker_name();
			$nice_name =~ s/_/-/g;

			# After some attempts, enable timestamp suffix flag
			my $use_suffix = $attempt > 5;
			if ($use_suffix) {
				my $timestamp = time();
				my $random = int(rand(1000));
				$nice_name = sprintf("%s_%d_%03d", $nice_name, $timestamp, $random);
			}

			# Create temporary directory in instances dir
			my $temp_dir = Path::Tiny->tempdir(
				DIR     => $instances_dir,
				CLEANUP => 0
			);

			my $target_dir = $instances_dir->child($nice_name);

			# Try atomic move (rename(2) on same filesystem)
			if (eval { $temp_dir->move($target_dir); 1 }) {
				return $nice_name;
			}

			# Move failed (name collision), cleanup and try again
			$temp_dir->remove_tree if $temp_dir->exists;
		}

		die "Could not generate unique instance name after 10 attempts";
	}

	sub md5_file {
		my $file = shift;
		my $file_path = path($file);

		# Use md5sum from coreutils (guaranteed in Nix environment)
		my ($stdout, $stderr, $exit) = capture { system('md5sum', $file_path) };
		die "md5sum failed: $stderr" if $exit;
		return (split /\s+/, $stdout)[0];
	}
}

1;
