{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "MooX-Log-Any";
	version = "0.004004";
	src = fetchurl {
		url = "mirror://cpan/authors/id/C/CA/CAZADOR/MooX-Log-Any-0.004004.tar.gz";
		hash = "sha256-Khr6DzpBHiipJYzKvixbXWR6vCny+/W+n/ryKG6DBTQ=";
	};
	propagatedBuildInputs = with perlPackages; [ LogAny Moo ];
	meta = {
		homepage = "https://github.com/cazador481/MooX-Log-Any";
		description = "Role to add Log::Any";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
