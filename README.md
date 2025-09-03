# biobricks-script-lib

A library of shared scripts for use in brick data processing.

## Usage

Recommended usage as git submodule:

```shell
git submodule add https://github.com/biobricks-ai/biobricks-script-lib.git vendor/biobricks-script-lib
```

Set up environment:

```shell
# Get local path
localpath=$(pwd)
echo "Local path: $localpath"

eval $( $localpath/vendor/biobricks-script-lib/activate.sh )
```

When using `git clone`, be sure to use get all submodules:

```shell
git clone --recurse-submodules git@github.com:biobricks-ai/my-brick.git
```

or with an already cloned repo:

```shell
git submodule update --init --recursive
```

## Nix Flake Usage

There are two approaches to use `biobricks-script-lib` as a Nix flake:

```nix
{
	inputs = {
		### Standard imports:
		# NOTE: Update version as needed.
		nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
		flake-utils.url = "github:numtide/flake-utils";

		### Approach 1: Remote Repository (Recommended) {{{
		###
		### Import the flake directly from GitHub:

		biobricks-script-lib = {
			url = "github:biobricks-ai/biobricks-script-lib";
			inputs.nixpkgs.follows = "nixpkgs";
			inputs.flake-utils.follows = "flake-utils";
		};

		### }}}

		### Approach 2: Git Submodule {{{
		###
		### If you need to use a local vendored copy.

		# Required for Nix 2.27.0+ when using git submodules
		self.submodules = true;

		biobricks-script-lib = {
			url = "path:./vendor/biobricks-script-lib";
			inputs.nixpkgs.follows = "nixpkgs";
			inputs.flake-utils.follows = "flake-utils";
			# Override nested component to prevent path resolution issues
			inputs.qendpoint-manage.url = "path:./vendor/biobricks-script-lib/component/qendpoint-manage";
		};

		### }}}

	};

	outputs = { self, nixpkgs, flake-utils, biobricks-script-lib }:
		flake-utils.lib.eachDefaultSystem (system:
			with import nixpkgs { inherit system; }; {
				devShells.default = mkShell {
					buildInputs = [
						# Project-specific dependencies
					] ++ biobricks-script-lib.packages.${system}.buildInputs;

					shellHook = ''
						# Inherit the complete shellHook from biobricks-script-lib
						${biobricks-script-lib.devShells.${system}.default.shellHook or ""}

						# Add any project-specific setup here
					'';
				};
			});
}
```

This provides all required dependencies (HDT tools, Python, Perl, Java runtime, etc.) without manual installation.

Note: The `self.submodules = true` declaration requires Nix 2.27.0 or later.
See the [Nix 2.27.0 release notes](https://discourse.nixos.org/t/nix-2-27-0-released/62003) for details.
