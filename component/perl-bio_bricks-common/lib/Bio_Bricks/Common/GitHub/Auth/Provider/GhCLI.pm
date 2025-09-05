package Bio_Bricks::Common::GitHub::Auth::Provider::GhCLI;
# ABSTRACT: GitHub CLI provider for GitHub authentication

use Bio_Bricks::Common::Setup ':class';
use IPC::Run3;
use File::Which qw(which);

with 'Bio_Bricks::Common::GitHub::Auth::Provider';

has '+source_type' => (
	default => 'gh_cli',
);

has '+name' => (
	default => 'gh_cli',
);

method valid () {
	return $self->_has_gh_cli;
}

method get_token () {
	return unless $self->valid;

	my ($stdout, $stderr, $exit_code);

	try {
		IPC::Run3::run3(['gh', 'auth', 'token'], \undef, \$stdout, \$stderr);
		$exit_code = $? >> 8;
	} catch ($e) {
		return;
	}

	return if $exit_code && $exit_code != 0;

	if ($stdout) {
		chomp $stdout;
		$stdout =~ s/^\s+|\s+$//g;
		return $stdout if $stdout && $stdout =~ /^[a-zA-Z0-9_]+$/;
	}

	return;
}

method _has_gh_cli () {
	return defined which('gh');
}

1;
