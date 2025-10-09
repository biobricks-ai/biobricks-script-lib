{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Mu";
	version = "1.191300";
	src = fetchurl {
		url = "mirror://cpan/authors/id/M/MI/MITHALDU/Mu-1.191300.tar.gz";
		hash = "sha256-bfBo0rm97zmtsCQgVN3GwxKMz1SrhXsbrW6138DQs+c=";
	};
	propagatedBuildInputs = with perlPackages; [ ImportInto Moo MooXShortHas strictures ];
	meta = {
		homepage = "https://github.com/wchristian/Mu";
		description = "Moo but with less typing";
		license = lib.licenses.unfreeRedistributable;
	};
}
