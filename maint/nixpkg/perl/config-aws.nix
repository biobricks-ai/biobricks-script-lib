{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlModule {
	pname = "Config-AWS";
	version = "0.12";
	src = fetchurl {
		url = "mirror://cpan/authors/id/J/JJ/JJATRIA/Config-AWS-0.12.tar.gz";
		hash = "sha256-FQnRvzi/cpHuouXEj83GvSWQS8h6tstv/qZANkewa1o=";
	};
	buildInputs = with perlPackages; [ ModuleBuildTiny ];
	propagatedBuildInputs = with perlPackages; [ ExporterTiny PathTiny RefUtil ];
	meta = {
		description = "Parse AWS config files";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
	doCheck = false;
}
