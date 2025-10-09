{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Module-Mask";
	version = "0.06";
	src = fetchurl {
		url = "mirror://cpan/authors/id/M/MA/MATTLAW/Module-Mask-0.06.tar.gz";
		hash = "sha256-LXP4H/Icn6KBAnkeVG/yVxZLMCX3gyVEyCI/uHwefnc=";
	};
	propagatedBuildInputs = with perlPackages; [ ModuleUtil ];
	meta = {
		description = "Pretend certain modules are not installed";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
