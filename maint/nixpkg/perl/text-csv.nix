{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Text-CSV";
	version = "2.06";
	src = fetchurl {
		url = "mirror://cpan/authors/id/I/IS/ISHIGAKI/Text-CSV-2.06.tar.gz";
		hash = "sha256-38rsklp4iwukHlG8bRbiGw6YtMevm3k5UJCt119eUG8=";
	};
	meta = {
		description = "Comma-separated values manipulator (using XS or PurePerl)";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
