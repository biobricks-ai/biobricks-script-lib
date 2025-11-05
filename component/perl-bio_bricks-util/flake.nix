{
  description = "Bio_Bricks::Util - Utility scripts for BioBricks operations";

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
    perl-bio_bricks-store-neptune = {
      url = "path:../perl-bio_bricks-store-neptune";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.perl-bio_bricks-common.follows = "perl-bio_bricks-common";
    };
  };

  outputs = { self, nixpkgs, flake-utils, nixpkgs-25_05, nixpkgs-lakectl, perl-bio_bricks-common, perl-bio_bricks-store-neptune }:
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

        # Depend on other components. Need to rebuild if these are changed
        # during development.
        commonModule = perl-bio_bricks-common.packages.${system}.default;
        neptuneModule = perl-bio_bricks-store-neptune.packages.${system}.default;

        # Runtime dependencies (from script inspection)
        runtimeDeps = with pkgs.perlPackages; [
          GetoptLongDescriptive
          TextCSV
          DataPrinter
          JSONPP
          MIMEBase64
          IPCRun
          TermANSIColor
          NumberBytesHuman

          pkgs.perlPackages.failures
          pkgs.perlPackages.ObjectUtil
        ];

        # Test dependencies
        testDeps = with pkgs.perlPackages; [
          TestMore
          TestException
        ];

        # Development dependencies
        devDeps = with pkgs.perlPackages; [
          CarpAlways
        ];

        # Perl dependencies for Bio_Bricks::Util
        bioBricksUtil = {
          perlModules = ps: [
            commonModule
            neptuneModule
          ] ++ runtimeDeps ++ testDeps ++ pkgs.lib.optionals isDevelopment devDeps;
        };

        # Perl environment with all dependencies
        perlEnv = pkgs.perl.withPackages bioBricksUtil.perlModules;

        # Build inputs for development
        buildInputs = [
          perlEnv
          pkgs-lakectl.lakectl  # lakectl from newer nixpkgs
          pkgs.rclone           # rclone for data transfers
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
            echo "Bio_Bricks::Util development environment"
            echo "Perl version: $(perl --version | head -n 2 | tail -n 1)"
            echo ""
            echo "Utility scripts for BioBricks operations:"
            echo "  - lakefs-upload-direct.pl"
            echo "  - scan-biobricks-rdf.pl"
            echo "  - upload-biobricks-rdf-to-neptune.pl"
            echo "  - upload-rdf-to-lakefs.pl"
            echo ""
          '';
        };

        # Export environment
        packages.default = pkgs.buildEnv {
          name = "biobricks-util";
          paths = buildInputs;
        };

        # Export for other flakes
        packages.perlEnv = perlEnv;
        packages.buildInputs = buildInputs;
        packages.perlModules = bioBricksUtil.perlModules;
      }
    );
}
