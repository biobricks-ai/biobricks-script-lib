{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "URL-Encode";
	version = "0.03";
	src = fetchurl {
		url = "mirror://cpan/authors/id/C/CH/CHANSEN/URL-Encode-0.03.tar.gz";
		hash = "sha256-cpXX8HeWsXkTHZwPIwpu/6VtIE3i+Nxy8uCcYUWMjuY=";
	};
	meta = {
		description = "Encoding and decoding of C<application/x-www-form-urlencoded> encoding";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
