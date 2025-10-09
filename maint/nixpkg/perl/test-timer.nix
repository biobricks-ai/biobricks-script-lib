{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Test-Timer";
	version = "2.12";
	src = fetchurl {
		url = "mirror://cpan/authors/id/J/JO/JONASBN/Test-Timer-2.12.tar.gz";
		hash = "sha256-6xtcGZeTzBxZGj0f5dFcFv2lOXVbptXdITjVY4gh8vw=";
	};
	buildInputs = with perlPackages; [ PodCoverageTrustPod TestFatal TestKwalitee TestPod TestPodCoverage ];
	propagatedBuildInputs = with perlPackages; [ Error ];
	meta = {
		homepage = "https://jonasbn.github.io/perl-test-timer/";
		description = "Test module to test/assert response times";
		license = lib.licenses.artistic2;
	};
}
