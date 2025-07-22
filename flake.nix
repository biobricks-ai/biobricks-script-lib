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
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Python environment with biobricks package
        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          # Core biobricks Python dependencies
          # Note: The biobricks package may need to be packaged separately
          # For now, this provides the Python runtime environment
        ]);

        # Perl environment with standard modules
        perlEnv = pkgs.perl.withPackages (ps: with ps; [
          # All required Perl modules are part of the standard library
          # or come with the base perl installation
        ]);

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
          nix-qendpoint.packages.${system}.default

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

        # Overlay for other flakes to use
        overlays.default = final: prev: {
          biobricks-script-lib = {
            buildInputs = commonBuildInputs;
            pythonEnv = pythonEnv;
            perlEnv = perlEnv;
          };
        };
      }
    );
}
