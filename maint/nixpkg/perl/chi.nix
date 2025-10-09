{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "CHI";
	version = "0.61";
	src = fetchurl {
		url = "mirror://cpan/authors/id/A/AS/ASB/CHI-0.61.tar.gz";
		hash = "sha256-WDVFyeUxK7QZOrFt6fVf+PS0p97RKM7o3SywIdRni1s=";
	};
	buildInputs = with perlPackages; [ CacheCache ModuleMask TestClass TestDeep TestException TestWarn TimeDate ];
	propagatedBuildInputs = with perlPackages; [ CarpAssert ClassLoad DataUUID DigestJHash HashMoreUtils JSONMaybeXS ListMoreUtils LogAny Moo MooXTypesMooseLike MooXTypesMooseLikeNumeric StringRewritePrefix TaskWeaken TimeDuration TimeDurationParse TryTiny ];
	meta = {
		description = "Unified cache handling interface";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
