{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Getopt-Long-Descriptive";
	version = "0.116";
	src = fetchurl {
		url = "mirror://cpan/authors/id/R/RJ/RJBS/Getopt-Long-Descriptive-0.116.tar.gz";
		hash = "sha256-k72IFzybmcM4CFqKcCIuuxwOutXF/q4fdCl0pMKcgso=";
	};
	buildInputs = with perlPackages; [ CPANMetaCheck TestFatal TestWarnings ];
	propagatedBuildInputs = with perlPackages; [ ParamsValidate SubExporter GetoptLong ];
	meta = {
		homepage = "https://github.com/rjbs/Getopt-Long-Descriptive";
		description = "Getopt::Long, but simpler and more powerful";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
