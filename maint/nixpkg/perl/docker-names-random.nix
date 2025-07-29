{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Docker-Names-Random";
	version = "0.0.2";
	src = fetchurl {
		url = "mirror://cpan/authors/id/M/MI/MIKKOI/Docker-Names-Random-0.0.2.tar.gz";
		hash = "sha256-706jo86I4v1xzkrIQE6sj810JA2PXeeVORrpxcxY0mk=";
	};
	buildInputs = with perlPackages; [ LogAny Test2Suite ];
	propagatedBuildInputs = with perlPackages; [ YAMLPP ];
	meta = {
		homepage = "https://metacpan.org/release/Docker::Names::Random";
		description = "Create random strings like Docker does for container names";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
