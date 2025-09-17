package Bio_Bricks::Common::DVC::Schema;

use Bio_Bricks::Common::Setup;

package Bio_Bricks::Common::DVC::Schema::Types {
	use Exporter 'import';
	use Types::Standard qw(InstanceOf HashRef);

	use kura Data => (InstanceOf['Bio_Bricks::Common::DVC::Schema::Data'])->plus_coercions(
			HashRef, sub { Bio_Bricks::Common::DVC::Schema::Data->new($_) }
	);

	use kura Output => (InstanceOf['Bio_Bricks::Common::DVC::Schema::Output'])->plus_coercions(
			HashRef, sub { Bio_Bricks::Common::DVC::Schema::Output->new($_) }
	);

	use kura Dependency => (InstanceOf['Bio_Bricks::Common::DVC::Schema::Dependency'])->plus_coercions(
			HashRef, sub { Bio_Bricks::Common::DVC::Schema::Dependency->new($_) }
	);

	use kura Stage => (InstanceOf['Bio_Bricks::Common::DVC::Schema::Stage'])->plus_coercions(
			HashRef, sub { Bio_Bricks::Common::DVC::Schema::Stage->new($_) }
	);

	use kura LockFile => (InstanceOf['Bio_Bricks::Common::DVC::Schema::LockFile'])->plus_coercions(
			HashRef, sub { Bio_Bricks::Common::DVC::Schema::LockFile->new($_) }
	);
};

# Base class for DVC schema objects
package Bio_Bricks::Common::DVC::Schema::Base {
	use Bio_Bricks::Common::Setup;
}

# Data object - represents file/directory with metadata
package Bio_Bricks::Common::DVC::Schema::Data {
	use Bio_Bricks::Common::Setup;

	extends 'Bio_Bricks::Common::DVC::Schema::Base';

	ro path     => isa => Maybe[Str];
	ro size     => isa => Maybe[Int], required => 0;
	ro nfiles   => isa => Maybe[Int], required => 0;

	ro hash     => isa => Maybe[Str], required => 0;
	ro md5      => isa => Maybe[Str], required => 0;
	ro checksum => isa => Maybe[Str], required => 0;
	ro etag     => isa => Maybe[Str], required => 0;

	# Computed attributes
	lazy EFFECTIVE_HASH => method () {
		# In DVC, when hash is "md5", it means look at the md5 field
		if ($self->hash && $self->hash eq 'md5') {
			return $self->md5;
		}
		return $self->md5 || $self->hash || $self->checksum || $self->etag;
	};

	lazy IS_DIRECTORY => method () {
		my $hash = $self->EFFECTIVE_HASH;
		return $hash && $hash =~ /\.dir$/;
	};
}

# Output object - extends Data with output-specific features
package Bio_Bricks::Common::DVC::Schema::Output {
	use Bio_Bricks::Common::Setup;

	extends 'Bio_Bricks::Common::DVC::Schema::Data';

	ro cache      => isa => Maybe[Bool],    required => 0;
	ro persist    => isa => Maybe[Bool],    required => 0;
	ro checkpoint => isa => Maybe[Bool],    required => 0;
	ro metric     => isa => Maybe[HashRef], required => 0;
	ro plot       => isa => Maybe[HashRef], required => 0;
	ro remote     => isa => Maybe[Str],     required => 0;
	ro push       => isa => Maybe[Bool],    required => 0;
}

# Dependency object - extends Data with dependency-specific features
package Bio_Bricks::Common::DVC::Schema::Dependency {
	use Bio_Bricks::Common::Setup;

	extends 'Bio_Bricks::Common::DVC::Schema::Data';

	ro repo      => isa => Maybe[Str];
	ro rev       => isa => Maybe[Str];
	ro rev_lock  => isa => Maybe[Str];
	ro url       => isa => Maybe[Str];
	ro update    => isa => Maybe[Bool];
}

# Stage object
package Bio_Bricks::Common::DVC::Schema::Stage {
	use Bio_Bricks::Common::Setup;
	use Bio_Bricks::Common::DVC::Schema::Types qw(Data Output);

	extends 'Bio_Bricks::Common::DVC::Schema::Base';

	ro cmd     => isa => Maybe[Str],       required => 0;
	ro wdir    => isa => Maybe[Str],       required => 0;
	ro deps    => isa => ArrayRef[Data],   coerce => 1,   default => sub { [] };
	ro outs    => isa => ArrayRef[Output], coerce => 1,   default => sub { [] };
	ro params  => isa => Maybe[HashRef],   required => 0;
	ro metrics => isa => Maybe[HashRef],   required => 0;
	ro plots   => isa => Maybe[HashRef],   required => 0;
	ro frozen  => isa => Maybe[Bool],      required => 0;

	ro NAME    => isa => Str       ,       required => 1;
}

# LockFile object - represents the entire DVC lock file
package Bio_Bricks::Common::DVC::Schema::LockFile {
	use Bio_Bricks::Common::Setup;
	use Bio_Bricks::Common::DVC::Schema::Types qw(Stage);

	extends 'Bio_Bricks::Common::DVC::Schema::Base';

	ro schema => isa => Maybe[Str], default => '2.0';
	ro stages => isa => HashRef[Stage], coerce => 1, default => sub { {} };

	# Handle stages with name assignment during construction
	around BUILDARGS => fun ($orig, $class, @args) {
		my $args = @args == 1 && ref $args[0] eq 'HASH' ? $args[0] : {@args};

		if ($args->{stages}) {
			my %processed_stages;
			for my $name (keys %{$args->{stages}}) {
				my $stage_data = {%{$args->{stages}{$name}}};
				$stage_data->{NAME} = $name;
				$processed_stages{$name} = $stage_data;
			}
			$args->{stages} = \%processed_stages;
		}

		return $class->$orig($args);
	};

	# Helper attributes
	lazy STAGE_NAMES => method () {
		return [keys %{$self->stages}];
	};

	lazy OUTPUTS => method () {
		my @outputs;

		for my $stage (values %{$self->stages}) {
			push @outputs, @{$stage->outs};
		}

		return \@outputs;
	};

	method get_stage ($stage_name) {
		return $self->stages->{$stage_name};
	}
}


1;
