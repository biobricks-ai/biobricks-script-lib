{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Net-Amazon-Signature-V4";
	version = "0.22";
	src = fetchurl {
		url = "mirror://cpan/authors/id/D/DB/DBOOK/Net-Amazon-Signature-V4-0.22.tar.gz";
		hash = "sha256-Ui/qJmyLMabD3n475dtxWXIDhxSgI5v7vh/MrU0GXP4=";
	};
	buildInputs = with perlPackages; [ FileSlurper HTTPMessage ];
	propagatedBuildInputs = with perlPackages; [ URI ];
	meta = {
		description = "Implements the Amazon Web Services signature version 4, AWS4-HMAC-SHA256";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
