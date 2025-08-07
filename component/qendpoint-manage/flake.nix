{
	description = "qendpoint-manage - qEndpoint management tool";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
		flake-utils.url = "github:numtide/flake-utils";
		nix-qendpoint = {
			url = "github:insilica/nix-qendpoint";
			inputs.flake-utils.follows = "flake-utils";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = { self, nixpkgs, flake-utils, nix-qendpoint }:
		let
			# Map of Perl package names to their .nix file base names
			perlPackageMap = {
				LogAnyAdapterScreen   = "log-any-adapter-screen";
				TextTableTiny         = "text-table-tiny";
				StringTtyLength       = "string-ttylength";
				UnicodeEastAsianWidth = "unicode-eastasianwidth";
				SyntaxConstruct       = "syntax-construct";
				DockerNamesRandom     = "docker-names-random";
				GetoptLong            = "getopt-long";
				GetoptLongDescriptive = "getopt-long-descriptive";
				FileSymlinkRelative   = "file-symlink-relative";
				Test2ToolsLoadModule  = "test2-tools-loadmodule";
			};
		in {
			overlays.default = final: prev: {
				perlPackages = prev.perlPackages // (
					nixpkgs.lib.mapAttrs
						(name: nixFile: final.callPackage ../../maint/nixpkg/perl/${nixFile}.nix {})
						perlPackageMap
				);
			};
		} //
		flake-utils.lib.eachDefaultSystem (system:
			let
				pkgs = import nixpkgs {
					inherit system;
					overlays = [ self.overlays.default ];
				};

				# qendpoint-manage dependencies
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
					];

					# Native binary dependencies
					nativeDeps = [
						pkgs.curl                                # Used for SPARQL HTTP requests
						pkgs.coreutils                           # md5sum
						nix-qendpoint.packages.${system}.default # qendpoint.sh and qepSearch.sh
					];
				};

				# Perl environment with qendpoint-manage modules
				perlEnv = pkgs.perl.withPackages qendpointManage.perlModules;

				# qendpoint-manage build inputs
				qendpointManageBuildInputs = [
					# Perl environment
					perlEnv
				] ++ qendpointManage.nativeDeps;

			in {
				# Development shell for qendpoint-manage
				devShells.default = pkgs.mkShell {
					buildInputs = qendpointManageBuildInputs;

					env = {
						LC_ALL = "C.UTF-8";
					};

					shellHook = ''
						echo "qendpoint-manage development environment loaded"
						export PATH="${self}/bin:$PATH";
					'';
				};

				# Package for qendpoint-manage environment
				packages.default = pkgs.buildEnv {
					name = "qendpoint-manage-env";
					paths = qendpointManageBuildInputs;
				};

				# Make the build inputs available for other flakes
				packages.buildInputs = qendpointManageBuildInputs;

				# Export perlModules function for other flakes
				packages.perlModules = qendpointManage.perlModules;
			}
		);
}
