{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Env-Dot";
	version = "0.018";
	src = fetchurl {
		url = "mirror://cpan/authors/id/M/MI/MIKKOI/Env-Dot-0.018.tar.gz";
		hash = "sha256-hqbQlq8SwIbUTADOendED81f7izCpModunI+fgsHQDk=";
	};
	buildInputs = with perlPackages; [ TestScript ];
	meta = {
		homepage = "https://metacpan.org/release/Env-Dot";
		description = "Read environment variables from .env file";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
