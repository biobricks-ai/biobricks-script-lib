{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlModule {
	pname = "URI-s3";
	version = "0.2";
	src = fetchurl {
		url = "mirror://cpan/authors/id/K/KA/KARUPA/URI-s3-v0.2.tar.gz";
		hash = "sha256-g+V7nc+q2RIMKREbup+h0HgcX7Rxyr3DvFbDdCcNkQo=";
	};
	buildInputs = with perlPackages; [ ModuleBuildTiny ];
	propagatedBuildInputs = with perlPackages; [ URI ];
	meta = {
		homepage = "https://github.com/karupanerura/URI-s3";
		description = "S3 URI scheme";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
