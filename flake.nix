{
	description = "BioBricks Script Library - Common dependencies for BioBricks projects";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
		flake-utils.url = "github:numtide/flake-utils";
		hdt-cpp = {
			url = "github:insilica/nix-hdt";
			inputs.flake-utils.follows = "flake-utils";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		hdt-java = {
			url = "github:insilica/nix-hdt-java";
			inputs.flake-utils.follows = "flake-utils";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		nix-qendpoint = {
			url = "github:insilica/nix-qendpoint";
			inputs.flake-utils.follows = "flake-utils";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = { self, nixpkgs, flake-utils, hdt-cpp, hdt-java, nix-qendpoint }:
		{
			overlays.default = final: prev: {
				perlPackages = prev.perlPackages // {
					LogAnyAdapterScreen = final.callPackage ./maint/nixpkg/perl/log-any-adapter-screen.nix {};
					TextTableTiny = final.callPackage ./maint/nixpkg/perl/text-table-tiny.nix {};
					StringTtyLength = final.callPackage ./maint/nixpkg/perl/string-ttylength.nix {};
					UnicodeEastAsianWidth = final.callPackage ./maint/nixpkg/perl/unicode-eastasianwidth.nix {};
					SyntaxConstruct = final.callPackage ./maint/nixpkg/perl/syntax-construct.nix {};
					DockerNamesRandom = final.callPackage ./maint/nixpkg/perl/docker-names-random.nix {};
					GetoptLong = final.callPackage ./maint/nixpkg/perl/getopt-long.nix {};
					GetoptLongDescriptive = final.callPackage ./maint/nixpkg/perl/getopt-long-descriptive.nix {};
					FileSymlinkRelative = final.callPackage ./maint/nixpkg/perl/file-symlink-relative.nix {};
					Test2ToolsLoadModule = final.callPackage ./maint/nixpkg/perl/test2-tools-loadmodule.nix {};
				};
			};
		} //
		flake-utils.lib.eachDefaultSystem (system:
			let
				pkgs = import nixpkgs {
					inherit system;
					overlays = [ self.overlays.default ];
				};

				# Path to activate script
				activateScript = "${self}/activate.sh";

				# Python environment with biobricks package
				pythonEnv = pkgs.python3.withPackages (ps: with ps; [
					# Core biobricks Python dependencies
					# Note: The biobricks package may need to be packaged separately
					# For now, this provides the Python runtime environment
				]);

				# qendpoint-manage dependencies record
				qendpointManage = {
					# Perl module dependencies
					perlModules = ps: with ps; [
						ClassTiny
						PathTiny
						JSONMaybeXS
						FileWhich
						CaptureTiny
						IPCRun
						ShellConfigGenerate
						pkgs.perlPackages.GetoptLong
						pkgs.perlPackages.GetoptLongDescriptive
						PodUsage
						LogAny
						ProcProcessTable
						pkgs.perlPackages.SyntaxConstruct
						pkgs.perlPackages.TextTableTiny
						pkgs.perlPackages.StringTtyLength
						pkgs.perlPackages.UnicodeEastAsianWidth
						pkgs.perlPackages.LogAnyAdapterScreen
						pkgs.perlPackages.DockerNamesRandom
						ListUtilsBy
						TestTCP
						pkgs.perlPackages.FileSymlinkRelative
						# All other required Perl modules are part of the standard library
						# or come with the base perl installation
					];

					# Native binary dependencies
					nativeDeps = [
						pkgs.curl  # Used for SPARQL HTTP requests
						nix-qendpoint.packages.${system}.default  # qendpoint.sh and qepSearch.sh
					];
				};

				# Perl environment with qendpoint-manage modules
				perlEnv = pkgs.perl.withPackages qendpointManage.perlModules;

				# Common development environment for biobricks-script-lib
				commonBuildInputs = [
					# Core system tools
					pkgs.bash
					pkgs.coreutils # wc, split
					pkgs.findutils
					pkgs.gnugrep
					pkgs.gnused
					pkgs.gawk
					pkgs.util-linux
					pkgs.which

					# Language runtimes
					pythonEnv
					perlEnv
					pkgs.jre_headless  # Java runtime for HDT operations

					# HDT tools
					hdt-cpp.packages.${system}.default
					hdt-java.packages.${system}.default

					# qendpoint-manage native dependencies
				] ++ qendpointManage.nativeDeps ++ [

					# Build tools
					pkgs.gnumake

					# Process management
					pkgs.psmisc

					# Note: GNU Parallel is vendored in vendor/parallel/ because
					# nixpkgs parallel-full doesn't include parsort which is needed
					# by biobricks-script-lib. The vendored version is added to PATH
					# by activate.sh
				];

			in {
				# Default development shell
				devShells.default = pkgs.mkShell {
					buildInputs = commonBuildInputs;

					shellHook = ''
						# Activate biobricks-script-lib environment if activate.sh exists
						if [ -f ./activate.sh ]; then
							eval $(./activate.sh)
						fi

						echo "BioBricks Script Library environment loaded"
					'';
				};

				# Package that other flakes can use to get the dependencies
				packages.default = pkgs.buildEnv {
					name = "biobricks-script-lib-env";
					paths = commonBuildInputs;
				};

				# Make the build inputs available for other flakes to import
				packages.buildInputs = commonBuildInputs;

				# Make activate script available for other flakes
				packages.activateScript = activateScript;
			}
		);
}
