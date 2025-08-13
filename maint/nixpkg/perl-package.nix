## DO NOT EDIT DIRECTLY
##
## Generated from <maint/nixpkg/perl-package.nix.tt2>.
##
## To regenerate:
##   tpage --define perl_dir=maint/nixpkg/perl \
##         maint/nixpkg/perl-package.nix.tt2 > maint/nixpkg/perl-package.nix

let
  # Centralized Perl package mappings for all components
  # Maps Perl package names to their .nix file base names in maint/nixpkg/perl/

  # sorted map
  perlPackageMap = {
    ARGVStruct              = "argv-struct";
    CacheCache              = "cache-cache";
    CarpAlways              = "carp-always";
    CHI                     = "chi";
    ConfigAWS               = "config-aws";
    DataPrinter             = "data-printer";
    DataStructFlat          = "datastruct-flat";
    DevelCover              = "devel-cover";
    DevelStrictMode         = "devel-strictmode";
    DockerNamesRandom       = "docker-names-random";
    EnvDot                  = "env-dot";
    ExporterTiny            = "exporter-tiny";
    failures                = "failures";
    FeatureCompatTry        = "feature-compat-try";
    FileSymlinkRelative     = "file-symlink-relative";
    FindBinlibs             = "findbin-libs";
    FunctionParameters      = "function-parameters";
    GetoptLong              = "getopt-long";
    GetoptLongDescriptive   = "getopt-long-descriptive";
    HashFieldHash           = "hash-fieldhash";
    HTTPTiny                = "http-tiny";
    ImportInto              = "import-into";
    IPCRun                  = "ipc-run";
    kura                    = "kura";
    libprojectroot          = "lib-projectroot";
    ListMoreUtils           = "list-moreutils";
    LogAnyAdapterScreen     = "log-any-adapter-screen";
    ModuleMask              = "module-mask";
    ModulePluggable         = "module-pluggable";
    MooseXClassAttribute    = "moosex-classattribute";
    MooXLogAny              = "moox-log-any";
    MooXShortHas            = "moox-shorthas";
    MooXStruct              = "moox-struct";
    MooXTraits              = "moox-traits";
    MooXTypeTiny            = "moox-typetiny";
    Mu                      = "mu";
    namespaceclean          = "namespace-clean";
    NetAmazonSignatureV4    = "net-amazon-signature-v4";
    NumberBytesHuman        = "number-bytes-human";
    ObjectID                = "object-id";
    ObjectUtil              = "object-util";
    Paws                    = "paws";
    PerlXMaybe              = "perlx-maybe";
    Pithub                  = "pithub";
    results                 = "results";
    ReturnType              = "return-type";
    ReturnTypeLexical       = "return-type-lexical";
    RoleHooks               = "role-hooks";
    StringTtyLength         = "string-ttylength";
    SubHandlesVia           = "sub-handlesvia";
    SyntaxConstruct         = "syntax-construct";
    TermTable               = "term-table";
    Test2Harness            = "test2-harness";
    Test2ToolsLoadModule    = "test2-tools-loadmodule";
    TestHarness             = "test-harness";
    TestSimple13            = "test-simple";
    TestTimer               = "test-timer";
    TextCSV                 = "text-csv";
    TextCSV_XS              = "text-csv_xs";
    TextTableTiny           = "text-table-tiny";
    TypeAPI                 = "type-api";
    TypesPathTiny           = "types-path-tiny";
    TypeTiny                = "type-tiny";
    UnicodeEastAsianWidth   = "unicode-eastasianwidth";
    URIs3                   = "uri-s3";
    URLEncode               = "url-encode";
    URLEncodeXS             = "url-encode-xs";
    WithRoles               = "with-roles";
  };
in {
  inherit perlPackageMap;

  # Function to create the overlay using the centralized package map
  mkPerlPackagesOverlay = nixpkgs: final: prev: {
    perlPackages = prev.perlPackages // (
      nixpkgs.lib.mapAttrs
        (name: nixFile: final.callPackage ./perl/${nixFile}.nix {})
        perlPackageMap
    );
  };
}
