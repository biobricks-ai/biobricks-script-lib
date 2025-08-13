package Bio_Bricks::Common::GitHub::URL;
# ABSTRACT: Parse GitHub URLs

use Bio_Bricks::Common::Setup;

ro url => ( isa => Str );

lazy is_valid => method() {
	return !! $self->_parsed->{valid};
}, ( isa => Bool );

lazy _parsed => method() {
	my $url = $self->url;
	my %parsed;

	# GitHub URL patterns:
	# https://github.com/{owner}/{repo}
	# https://github.com/{owner}/{repo}.git
	# https://github.com/{owner}/{repo}/tree/{branch}
	# https://github.com/{owner}/{repo}/tree/{branch}/{path/to/file}
	# https://github.com/{owner}/{repo}/blob/{branch}/{path/to/file}
	# https://github.com/{owner}/{repo}/commit/{sha}
	# https://github.com/{owner}/{repo}/releases/tag/{v1.0.0}
	# git@github.com:{owner}/{repo}.git
	# git://github.com/{owner}/{repo}.git

	if ($url =~ m{
			^
			https?://
			github\.com
			/
			([^/]+)
			/
			([^/]+?)
				(?:\.git)?
			(?:/(.*))?$}x
	) {
		$parsed{owner} = $1;
		$parsed{repo} = $2;
		my $rest = $3 || '';

		# Parse the rest of the URL
		if ($rest) {
			if ($rest =~ m{^(?:tree|blob)/([^/]+)(?:/(.*))?$}) {
				$parsed{ref} = $1;
				$parsed{path} = $2 if defined $2;
			} elsif ($rest =~ m{^commit/([a-f0-9]+)$}) {
				$parsed{ref} = $1;
			} elsif ($rest =~ m{^releases/tag/(.+)$}) {
				$parsed{ref} = $1;
			} elsif ($rest =~ m{^tags/(.+)$}) {
				$parsed{ref} = $1;
			}
		}

	} elsif ($url =~ m{^git\@github\.com:([^/]+)/([^/]+?)(?:\.git)?$}) {
		# SSH format: git@github.com:owner/repo.git
		$parsed{owner} = $1;
		$parsed{repo} = $2;

	} elsif ($url =~ m{^git://github\.com/([^/]+)/([^/]+?)(?:\.git)?$}) {
		# Git protocol: git://github.com/owner/repo.git
		$parsed{owner} = $1;
		$parsed{repo} = $2;

	} else {
		$parsed{valid} = 0;
		return \%parsed;
	}

	$parsed{valid} = 1;
	return \%parsed;
}, (
	isa => HashRef,
	handles_via => 'Hash',
	handles => {
		map {
			$_ => [ get => $_ ]
		} qw(owner repo ref path)
	},
);


method BUILD(@) {
	croak "Invalid GitHub URL" unless $self->is_valid;
};

method clone_url ($format = undef) {
	$format ||= 'https';

	my $owner = $self->owner;
	my $repo = $self->repo;

	if ($format eq 'https') {
		return "https://github.com/$owner/$repo.git";
	} elsif ($format eq 'ssh') {
		return "git\@github.com:$owner/$repo.git";
	} elsif ($format eq 'git') {
		return "git://github.com/$owner/$repo.git";
	} else {
		croak "Invalid format '$format'. Valid formats: https, ssh, git";
	}
}

method repo_web_url () {
	return "https://github.com/" . $self->owner . "/" . $self->repo;
}

method web_url () {
	my $url = "https://github.com/" . $self->owner . "/" . $self->repo;

	if ($self->ref) {
		$url .= "/tree/" . $self->ref;
		if ($self->path) {
			$url .= "/" . $self->path;
		}
	}

	return $url;
}

method api_url () {
	return "https://api.github.com/repos/" . $self->owner . "/" . $self->repo;
}

method raw_url ($ref = undef, $path = undef) {
	$ref ||= $self->ref || 'main';
	$path ||= $self->path;

	croak "Path is required for raw URL" unless $path;

	return "https://raw.githubusercontent.com/" . $self->owner . "/" . $self->repo . "/$ref/$path";
}

method to_hash () {

	return {
		url     => $self->url,
		owner   => $self->owner,
		repo    => $self->repo,
		ref     => $self->ref,
		path    => $self->path,
		valid   => $self->is_valid,
	};
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 SYNOPSIS

	use Bio_Bricks::Common::GitHubURL;

	# Parse a GitHub repository URL
	my $parser = Bio_Bricks::Common::GitHubURL->new(
		url => 'https://github.com/biobricks-ai/tox21'
	);

	print "Owner: ", $parser->owner, "\n";  # biobricks-ai
	print "Repo: ", $parser->repo, "\n";    # tox21

	# Parse a URL with branch and path
	my $parser2 = Bio_Bricks::Common::GitHubURL->new(
		url => 'https://github.com/biobricks-ai/tox21/tree/main/data/processed.parquet'
	);

	print "Ref: ", $parser2->ref, "\n";     # main
	print "Path: ", $parser2->path, "\n";   # data/processed.parquet

	# Generate different URL formats
	print "Clone URL (HTTPS): ", $parser->clone_url('https'), "\n";
	print "Clone URL (SSH): ", $parser->clone_url('ssh'), "\n";
	print "Web URL: ", $parser->web_url(1), "\n";
	print "API URL: ", $parser->api_url, "\n";

	# Check if URL is valid
	if ($parser->is_valid) {
		print "Valid GitHub URL\n";
	}

=head1 DESCRIPTION

This module provides functionality to parse GitHub URLs and extract components like
repository owner, repository name, branch/tag/commit reference, and file paths.
It supports various GitHub URL formats including HTTPS, SSH, and Git protocol URLs.

=head1 SUPPORTED URL FORMATS

=over 4

=item * C<https://github.com/owner/repo>

=item * C<https://github.com/owner/repo.git>

=item * C<https://github.com/owner/repo/tree/branch>

=item * C<https://github.com/owner/repo/tree/branch/path/to/file>

=item * C<https://github.com/owner/repo/blob/branch/path/to/file>

=item * C<https://github.com/owner/repo/commit/sha>

=item * C<https://github.com/owner/repo/releases/tag/v1.0.0>

=item * C<git@github.com:owner/repo.git>

=item * C<git://github.com/owner/repo.git>

=back

=attr url

The GitHub URL to parse (required).

=attr owner

The repository owner/organization name.

=attr repo

The repository name.

=attr ref

The branch, tag, or commit reference.

=attr path

The file or directory path within the repository.

=attr is_valid

Boolean indicating whether the URL is a valid GitHub URL.

=method new

	my $parser = Bio_Bricks::Common::GitHubURL->new(url => $github_url);

Creates a new GitHubURL parser instance.

=method clone_url

	my $clone_url = $parser->clone_url($format);

Returns a clone URL in the specified format ('https', 'ssh', or 'git').
Defaults to 'https'.

=method web_url

	my $web_url = $parser->web_url($include_ref_and_path);

Returns the web URL for viewing on GitHub. If C<$include_ref_and_path> is true,
includes the reference and path in the URL.

=method api_url

	my $api_url = $parser->api_url;

Returns the GitHub API URL for the repository.

=method raw_url

	my $raw_url = $parser->raw_url($ref, $path);

Returns the raw content URL for a file. Uses the parsed ref and path if not provided.

=method to_hash

	my $hash = $parser->to_hash;

Returns a hash reference with all parsed components.

=cut
