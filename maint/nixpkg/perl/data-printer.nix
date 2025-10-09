{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Data-Printer";
	version = "1.002001";
	src = fetchurl {
		url = "mirror://cpan/authors/id/G/GA/GARU/Data-Printer-1.002001.tar.gz";
		hash = "sha256-liktKe34XsoQckoA4K9QnECxe5tWOMADMtcDWZtvO3Q=";
	};
	meta = {
		description = "Colored & full-featured pretty print of Perl data structures and objects";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
