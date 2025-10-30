package Bio_Bricks::LakeFS;
# ABSTRACT: LakeFS client for BioBricks

use Bio_Bricks::Common::Setup;
use HTTP::Tiny;
use MIME::Base64;
use Bio_Bricks::LakeFS::Auth;

lazy auth => sub {
	Bio_Bricks::LakeFS::Auth->new;
}, isa => InstanceOf['Bio_Bricks::LakeFS::Auth'];

lazy _endpoint => method () {
	$self->auth->get_endpoint || croak "LakeFS endpoint not found in environment or config";
}, isa => Maybe[Str];

lazy _access_key_id => method () {
	$self->auth->get_access_key_id || croak "LakeFS access key ID not found in environment or config";
}, isa => Maybe[Str];

lazy _secret_access_key => method () {
	$self->auth->get_secret_access_key || croak "LakeFS secret access key not found in environment or config";
}, isa => Maybe[Str];

lazy http => method () {
	# Create basic auth header
	my $auth = encode_base64($self->_access_key_id . ':' . $self->_secret_access_key, '');

	return HTTP::Tiny->new(
		timeout => 300,
		verify_SSL => 1,
		default_headers => {
			'Authorization' => "Basic $auth",
			'Content-Type' => 'application/json',
			'Accept' => 'application/json',
		}
	);
};

lazy json => sub {
	JSON::PP->new->utf8->pretty;
};

method _request ($method, $path, $data = undef) {

	my $url = $self->_endpoint . '/api/v1' . $path;

	my %options;
	if ($data && ($method eq 'POST' || $method eq 'PUT' || $method eq 'PATCH')) {
		$options{content} = $self->json->encode($data);
	}

	my $response = $self->http->request($method, $url, \%options);

	unless ($response->{success}) {
		my $error = $response->{content} || $response->{reason};
		croak "LakeFS API error: $response->{status} - $error";
	}

	if ($response->{content} && $response->{headers}{'content-type'} =~ /json/) {
		return $self->json->decode($response->{content});
	}

	return $response->{content};
}

# Repository operations
method list_repositories ($params = undef) {
	$params ||= {};
	my $query = '';
	if ($params->{after}) {
		$query = "?after=$params->{after}";
	}
	if ($params->{amount}) {
		$query .= $query ? '&' : '?';
		$query .= "amount=$params->{amount}";
	}

	return $self->_request('GET', "/repositories$query");
}

method get_repository ($repository) {
	croak "Repository name required" unless $repository;
	return $self->_request('GET', "/repositories/$repository");
}

method create_repository ($repository, $storage_namespace, $default_branch = undef) {
	croak "Repository name required" unless $repository;
	croak "Storage namespace required" unless $storage_namespace;

	$default_branch ||= 'main';

	return $self->_request('POST', '/repositories', {
		name => $repository,
		storage_namespace => $storage_namespace,
		default_branch => $default_branch,
	});
}

method delete_repository ($repository) {
	croak "Repository name required" unless $repository;
	return $self->_request('DELETE', "/repositories/$repository");
}

# Branch operations
method list_branches ($repository, $params = undef) {
	croak "Repository name required" unless $repository;

	$params ||= {};
	my $query = '';
	if ($params->{after}) {
		$query = "?after=$params->{after}";
	}
	if ($params->{amount}) {
		$query .= $query ? '&' : '?';
		$query .= "amount=$params->{amount}";
	}

	return $self->_request('GET', "/repositories/$repository/branches$query");
}

method get_branch ($repository, $branch) {
	croak "Repository name required" unless $repository;
	croak "Branch name required" unless $branch;

	return $self->_request('GET', "/repositories/$repository/branches/$branch");
}

method create_branch ($repository, $branch, $source) {
	croak "Repository name required" unless $repository;
	croak "Branch name required" unless $branch;
	croak "Source reference required" unless $source;

	return $self->_request('POST', "/repositories/$repository/branches", {
		name => $branch,
		source => $source,
	});
}

method delete_branch ($repository, $branch) {
	croak "Repository name required" unless $repository;
	croak "Branch name required" unless $branch;

	return $self->_request('DELETE', "/repositories/$repository/branches/$branch");
}

# Object operations
method list_objects ($repository, $ref, $params = undef) {
	croak "Repository name required" unless $repository;
	croak "Reference required" unless $ref;

	$params ||= {};
	my $query = "?";

	if ($params->{prefix}) {
		$query .= "prefix=$params->{prefix}&";
	}
	if ($params->{after}) {
		$query .= "after=$params->{after}&";
	}
	if ($params->{amount}) {
		$query .= "amount=$params->{amount}&";
	}
	if ($params->{delimiter}) {
		$query .= "delimiter=$params->{delimiter}&";
	}

	$query =~ s/&$//;  # Remove trailing &
	$query = '' if $query eq '?';  # Remove empty query

	return $self->_request('GET', "/repositories/$repository/refs/$ref/objects$query");
}

method get_object ($repository, $ref, $path) {
	croak "Repository name required" unless $repository;
	croak "Reference required" unless $ref;
	croak "Path required" unless $path;

	# URL encode the path
	$path =~ s/([^A-Za-z0-9\-_.~\/])/sprintf("%%%02X", ord($1))/eg;

	return $self->_request('GET', "/repositories/$repository/refs/$ref/objects?path=$path");
}

method upload_object ($repository, $branch, $path, $content) {
	croak "Repository name required" unless $repository;
	croak "Branch name required" unless $branch;
	croak "Path required" unless $path;
	croak "Content required" unless defined $content;

	# URL encode the path
	$path =~ s/([^A-Za-z0-9\-_.~\/])/sprintf("%%%02X", ord($1))/eg;

	my $url = $self->_endpoint . "/api/v1/repositories/$repository/branches/$branch/objects?path=$path";

	# For file upload, we need to send raw content with proper content-type
	my $response = $self->http->request('PUT', $url, {
		content => $content,
		headers => {
			'Authorization' => $self->http->default_headers->{'Authorization'},
			'Content-Type' => 'application/octet-stream',
		}
	});

	unless ($response->{success}) {
		my $error = $response->{content} || $response->{reason};
		croak "LakeFS API error: $response->{status} - $error";
	}

	return $response->{content};
}

method delete_object ($repository, $branch, $path) {
	croak "Repository name required" unless $repository;
	croak "Branch name required" unless $branch;
	croak "Path required" unless $path;

	# URL encode the path
	$path =~ s/([^A-Za-z0-9\-_.~\/])/sprintf("%%%02X", ord($1))/eg;

	return $self->_request('DELETE', "/repositories/$repository/branches/$branch/objects?path=$path");
}

# Commit operations
method commit ($repository, $branch, $message, $metadata = undef) {
	croak "Repository name required" unless $repository;
	croak "Branch name required" unless $branch;
	croak "Commit message required" unless $message;

	my $data = {
		message => $message,
	};

	if ($metadata) {
		$data->{metadata} = $metadata;
	}

	return $self->_request('POST', "/repositories/$repository/branches/$branch/commits", $data);
}

method list_commits ($repository, $ref, $params = undef) {
	croak "Repository name required" unless $repository;
	croak "Reference required" unless $ref;

	$params ||= {};
	my $query = '';
	if ($params->{after}) {
		$query = "?after=$params->{after}";
	}
	if ($params->{amount}) {
		$query .= $query ? '&' : '?';
		$query .= "amount=$params->{amount}";
	}

	return $self->_request('GET', "/repositories/$repository/refs/$ref/commits$query");
}

method get_commit ($repository, $commit_id) {
	croak "Repository name required" unless $repository;
	croak "Commit ID required" unless $commit_id;

	return $self->_request('GET', "/repositories/$repository/commits/$commit_id");
}

# Merge operations
method merge ($repository, $source_ref, $destination_branch, $message = undef) {
	croak "Repository name required" unless $repository;
	croak "Source reference required" unless $source_ref;
	croak "Destination branch required" unless $destination_branch;

	my $data = {
		source => $source_ref,
	};

	if ($message) {
		$data->{message} = $message;
	}

	return $self->_request('POST', "/repositories/$repository/branches/$destination_branch/merge", $data);
}

# Diff operations
method diff ($repository, $left_ref, $right_ref, $params = undef) {
	croak "Repository name required" unless $repository;
	croak "Left reference required" unless $left_ref;
	croak "Right reference required" unless $right_ref;

	$params ||= {};
	my $query = '';
	if ($params->{after}) {
		$query = "?after=$params->{after}";
	}
	if ($params->{amount}) {
		$query .= $query ? '&' : '?';
		$query .= "amount=$params->{amount}";
	}
	if ($params->{prefix}) {
		$query .= $query ? '&' : '?';
		$query .= "prefix=$params->{prefix}";
	}
	if ($params->{delimiter}) {
		$query .= $query ? '&' : '?';
		$query .= "delimiter=$params->{delimiter}";
	}

	return $self->_request('GET', "/repositories/$repository/refs/$left_ref/diff/$right_ref$query");
}

1;

__END__

=head1 NAME

Bio_Bricks::LakeFS - LakeFS client for BioBricks

=head1 SYNOPSIS

	use Bio_Bricks::LakeFS;

	# Create client (uses environment variables or config files)
	my $lakefs = Bio_Bricks::LakeFS->new();

	# Repository operations
	my $repos = $lakefs->list_repositories();
	my $repo = $lakefs->get_repository('my-repo');
	$lakefs->create_repository('new-repo', 's3://my-bucket/path', 'main');

	# Branch operations
	my $branches = $lakefs->list_branches('my-repo');
	$lakefs->create_branch('my-repo', 'feature-branch', 'main');

	# Object operations
	my $objects = $lakefs->list_objects('my-repo', 'main', params => { prefix => 'data/' });
	my $content = $lakefs->get_object('my-repo', 'main', 'data/file.parquet');
	$lakefs->upload_object('my-repo', 'branch', 'data/new.txt', "content");

	# Commit changes
	$lakefs->commit('my-repo', 'branch', 'Added new data files');

	# Merge branches
	$lakefs->merge('my-repo', 'feature-branch', 'main', 'Merge feature');

=head1 DESCRIPTION

LakeFS client for managing data versioning in BioBricks. Provides a Perl
interface to the LakeFS API for repository, branch, object, and commit
operations.

Credentials are automatically detected from multiple sources via
L<Bio_Bricks::LakeFS::Auth>. See L</ENVIRONMENT VARIABLES> for configuration.

=head1 ENVIRONMENT VARIABLES

=over 4

=item C<LAKEFS_ENDPOINT>

LakeFS server endpoint URL

=item C<LAKEFS_ACCESS_KEY_ID>

LakeFS access key ID for authentication

=item C<LAKEFS_SECRET_ACCESS_KEY>

LakeFS secret access key for authentication

=back

=head1 METHODS

=head2 Repository Operations

=over 4

=item list_repositories($params)

List all repositories

=item get_repository($repository)

Get repository metadata

=item create_repository($repository, $storage_namespace, $default_branch)

Create a new repository

=item delete_repository($repository)

Delete a repository

=back

=head2 Branch Operations

=over 4

=item list_branches($repository, $params)

List branches in a repository

=item get_branch($repository, $branch)

Get branch information

=item create_branch($repository, $branch, $source)

Create a new branch from source

=item delete_branch($repository, $branch)

Delete a branch

=back

=head2 Object Operations

=over 4

=item list_objects($repository, $ref, $params)

List objects in a repository

=item get_object($repository, $ref, $path)

Get object content

=item upload_object($repository, $branch, $path, $content)

Upload an object

=item delete_object($repository, $branch, $path)

Delete an object

=back

=head2 Commit Operations

=over 4

=item commit($repository, $branch, $message, $metadata)

Create a commit

=item list_commits($repository, $ref, $params)

List commits

=item get_commit($repository, $commit_id)

Get commit details

=back

=head2 Other Operations

=over 4

=item merge($repository, $source_ref, $destination_branch, $message)

Merge branches

=item diff($repository, $left_ref, $right_ref, $params)

Get diff between references

=back

=cut
