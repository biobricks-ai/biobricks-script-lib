use Module::Build;

my $class = Module::Build->subclass(
	code => q{
		sub ACTION_testcover {
			my $self = shift;

			# Run tests with coverage for lib/ only
			$self->depends_on('code');

			# Clear any existing coverage data
			system('cover', '-delete');

			# Run tests with coverage, excluding bin/ and site_perl
			local $ENV{HARNESS_PERL_SWITCHES} = '-MDevel::Cover=-coverage,statement,branch,condition,subroutine,-ignore,^bin/,-ignore,site_perl';
			$self->depends_on('test');

			# Generate text summary report
			system('cover', '-report', 'text');
		}
	},
);

$class->new(
	module_name => 'Bio_Bricks::LakeFS',
	dist_abstract => 'LakeFS client for BioBricks',
	dist_version => '0.1.0',
	recursive_test_files => 1,
)->create_build_script;
