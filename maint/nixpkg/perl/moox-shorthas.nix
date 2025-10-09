{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "MooX-ShortHas";
	version = "1.202040";
	src = fetchurl {
		url = "mirror://cpan/authors/id/M/MI/MITHALDU/MooX-ShortHas-1.202040.tar.gz";
		hash = "sha256-iUPL3M1P4MU/J+mK/PswakR5ERHlEj9pNsrLTYIn0fs=";
	};
	buildInputs = with perlPackages; [ TestFatal TestInDistDir ];
	propagatedBuildInputs = with perlPackages; [ Moo strictures ];
	meta = {
		homepage = "https://github.com/wchristian/MooX-ShortHas";
		description = "Shortcuts for common Moo has attribute configurations";
		license = lib.licenses.unfreeRedistributable;
	};
}
