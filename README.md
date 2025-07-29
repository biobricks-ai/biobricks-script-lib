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

When using Nix, you can import the flake directly from the vendored path:

```nix
{
	inputs = {
		# Required for Nix 2.27.0+ when using git submodules
		self.submodules = true;

		biobricks-script-lib.url = "path:./vendor/biobricks-script-lib";
	};

	outputs = { self, nixpkgs, flake-utils, biobricks-script-lib }:
		flake-utils.lib.eachDefaultSystem (system:
			with import nixpkgs { inherit system; }; {
				devShells.default = mkShell {
					buildInputs = [
						# Project-specific dependencies
					] ++ biobricks-script-lib.packages.${system}.buildInputs;

					shellHook = ''
						# Activate biobricks-script-lib environment
						eval $(${biobricks-script-lib.packages.${system}.activateScript})
					'';
				};
			});
}
```

This provides all required dependencies (HDT tools, Python, Perl, Java runtime, etc.) without manual installation.

Note: The `self.submodules = true` declaration requires Nix 2.27.0 or later.
See the [Nix 2.27.0 release notes](https://discourse.nixos.org/t/nix-2-27-0-released/62003) for details.
