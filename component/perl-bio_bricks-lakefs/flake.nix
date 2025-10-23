{
  description = "Bio_Bricks::LakeFS - LakeFS API client for Perl";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs-25_05.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-lakectl.follows = "nixpkgs-25_05";
    flake-utils.url = "github:numtide/flake-utils";
    perl-bio_bricks-common = {
      url = "path:../perl-bio_bricks-common";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, flake-utils, nixpkgs-25_05, nixpkgs-lakectl, perl-bio_bricks-common }:
    let
      perlPkgs = import ../../maint/nixpkg/perl-package.nix;
    in {
      overlays.default = perl-bio_bricks-common.overlays.default;
    } //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };

        # Import newer nixpkgs for lakectl
        pkgs-lakectl = import nixpkgs-lakectl {
          inherit system;
        };

        # Development mode flag
        isDevelopment = true;

        # Get perl-bio_bricks-common modules
        commonPerlModules = perl-bio_bricks-common.packages.${system}.perlModules;

        # Runtime dependencies from cpanfile
        runtimeDeps = with pkgs.perlPackages; [
          Carp
          FileWhich
          Moo
          HTTPTiny
          JSONPP
          MIMEBase64
          PathTiny
        ];

        # Test dependencies
        testDeps = with pkgs.perlPackages; [
          pkgs.perlPackages.TestSimple13
          pkgs.perlPackages.Test2Harness
        ];

        # Development dependencies
        devDeps = with pkgs.perlPackages; [
          CarpAlways
          DataPrinter
          DevelCover
          ModuleBuild
        ];

        # Perl dependencies for Bio_Bricks::LakeFS
        bioBricksLakeFS = {
          perlModules = ps: (commonPerlModules ps) ++ runtimeDeps ++ testDeps ++ pkgs.lib.optionals isDevelopment devDeps;
        };

        # Perl environment with all dependencies
        perlEnv = pkgs.perl.withPackages bioBricksLakeFS.perlModules;

        # Build inputs for development
        buildInputs = [
          perlEnv
          pkgs-lakectl.lakectl  # lakectl from newer nixpkgs
          pkgs.rclone           # rclone for S3 transfers via LakeFS
          pkgs.perl
        ];

      in {
        # Development shell
        devShells.default = pkgs.mkShell {
          inherit buildInputs;

          env = {
            LC_ALL = "C.UTF-8";
          };

          shellHook = ''
            echo "Bio_Bricks::LakeFS development environment"
            echo "Perl version: $(perl --version | head -n 2 | tail -n 1)"
            echo "lakectl: $(lakectl version 2>/dev/null || echo 'not found')"
            echo "rclone: $(rclone version 2>&1 | head -n 1 || echo 'not found')"
            echo ""
            echo "Available commands:"
            echo "  perl Build.PL       # Configure build"
            echo "  ./Build             # Build the module"
            echo "  ./Build test        # Run tests"
            echo "  ./Build testcover   # Run tests with coverage"
            echo "  prove -l t/         # Alternative test runner"
            echo ""
          '';
        };

        # Package for the Perl module
        packages.default = pkgs.perlPackages.buildPerlModule {
          pname = "Bio_Bricks-LakeFS";
          version = "0.1.0";

          src = ./.;

          buildInputs = [ pkgs.perlPackages.ModuleBuild ];
          propagatedBuildInputs = runtimeDeps ++ [ perl-bio_bricks-common.packages.${system}.default ];
          checkInputs = testDeps;

          doCheck = true;

          # Use yath for parallel testing
          checkPhase = ''
            runHook preCheck
            yath test -j4 t/
            runHook postCheck
          '';

          meta = with pkgs.lib; {
            description = "LakeFS API client for Perl";
            license = licenses.artistic1;
            maintainers = [ ];
            platforms = platforms.unix;
          };
        };

        # Export for other flakes
        packages.perlEnv = perlEnv;
        packages.buildInputs = buildInputs;
        packages.perlModules = bioBricksLakeFS.perlModules;
      }
    );
}
