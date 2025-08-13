{
  description = "Bio_Bricks::Common - Perl library for BioBricks core functionality";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      perlPkgs = import ../../maint/nixpkg/perl-package.nix;
    in {
      overlays.default = perlPkgs.mkPerlPackagesOverlay nixpkgs;
    } //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };

        # Development mode flag
        isDevelopment = true;  # Set to false for production builds

        # Runtime dependencies
        runtimeDeps = with pkgs.perlPackages; [
          aliased
          IPCRun
          IPCRun3
          Moo
          namespaceautoclean
          PathTiny
          YAMLLibYAML  # YAML::XS

          pkgs.perlPackages.DevelStrictMode
          pkgs.perlPackages.EnvDot
          pkgs.perlPackages.ExporterTiny
          pkgs.perlPackages.failures
          pkgs.perlPackages.FeatureCompatTry
          pkgs.perlPackages.FileWhich
          pkgs.perlPackages.FunctionParameters
          pkgs.perlPackages.ImportInto
          pkgs.perlPackages.kura
          pkgs.perlPackages.LogAnyAdapterScreen
          pkgs.perlPackages.MooXLogAny
          pkgs.perlPackages.MooXShortHas
          pkgs.perlPackages.MooXStruct
          pkgs.perlPackages.MooXTypeTiny
          pkgs.perlPackages.Mu
          pkgs.perlPackages.namespaceclean
          pkgs.perlPackages.NumberBytesHuman
          pkgs.perlPackages.ObjectUtil
          pkgs.perlPackages.Paws
          pkgs.perlPackages.PerlXMaybe
          pkgs.perlPackages.Pithub
          pkgs.perlPackages.results
          pkgs.perlPackages.ReturnType
          pkgs.perlPackages.ReturnTypeLexical
          pkgs.perlPackages.SubHandlesVia
          pkgs.perlPackages.TextCSV
          pkgs.perlPackages.TextCSV_XS
          pkgs.perlPackages.TextTableTiny
          pkgs.perlPackages.TypesPathTiny
          pkgs.perlPackages.TypeTiny
          pkgs.perlPackages.URIs3
          pkgs.perlPackages.WithRoles
        ];

        # Test dependencies
        testDeps = with pkgs.perlPackages; [
          pkgs.perlPackages.TestSimple13
          pkgs.perlPackages.Test2Harness
        ];

        # Development dependencies - only in dev mode
        devDeps = with pkgs.perlPackages; [
          CarpAlways
          DataPrinter
          DevelCover
          ModuleBuild

          pkgs.perlPackages.Test2Harness
        ];

        # Perl dependencies for Bio_Bricks::Common
        bioBricksCommon = {
          # Perl module dependencies - reuse package definitions
          perlModules = ps: runtimeDeps ++ testDeps ++ pkgs.lib.optionals isDevelopment devDeps;
        };

        # Perl environment with all dependencies
        perlEnv = pkgs.perl.withPackages bioBricksCommon.perlModules;

        # Build inputs for development
        buildInputs = [
          perlEnv
          pkgs.perl  # For bare perl commands
        ];

      in {
        # Development shell
        devShells.default = pkgs.mkShell {
          inherit buildInputs;

          env = {
                  LC_ALL = "C.UTF-8";
          };

          shellHook = ''
            echo "Bio_Bricks::Common development environment"
            echo "Perl version: $(perl --version | head -n 2 | tail -n 1)"
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
          pname = "Bio_Bricks-Common";
          version = "0.1.0";

          src = ./.;

          # Use Module::Build
          buildInputs = [ pkgs.perlPackages.ModuleBuild ];

          propagatedBuildInputs = runtimeDeps;

          checkInputs = testDeps;

          # Enable tests
          doCheck = true;

          # Use yath for parallel testing
          checkPhase = ''
            runHook preCheck
            yath test -j4 t/
            runHook postCheck
          '';

          meta = with pkgs.lib; {
            description = "Perl library for BioBricks DVC/S3 path resolution";
            license = licenses.artistic1;
            maintainers = [ ];
            platforms = platforms.unix;
          };
        };

        # Make perl environment available for other flakes
        packages.perlEnv = perlEnv;

        # Export build inputs for other flakes to use
        packages.buildInputs = buildInputs;

        # Export perlModules function for other flakes
        packages.perlModules = bioBricksCommon.perlModules;
      }
    );
}
