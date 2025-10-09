{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Test2-Harness";
	version = "1.000161";
	src = fetchurl {
		url = "mirror://cpan/authors/id/E/EX/EXODIST/Test2-Harness-1.000161.tar.gz";
		hash = "sha256-SXO3mx7tUwVxXuc9itySNtp5XH1AkNg7FQ6hMc1ltBQ=";
	};
	propagatedBuildInputs = with perlPackages; [ TestSimple13 DataUUID Importer LongJump ScopeGuard Test2PluginMemUsage Test2PluginUUID YAMLTiny gotofile ];
	meta = {
		description = "A new and improved test harness with better Test2 integration";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
	doCheck = false;
}
