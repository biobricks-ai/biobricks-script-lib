{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlModule {
	pname = "MooseX-Getopt";
	version = "0.78";
	src = fetchurl {
		url = "mirror://cpan/authors/id/E/ET/ETHER/MooseX-Getopt-0.78.tar.gz";
		hash = "sha256-euiWIPOIJ9utIxOk5fc0BJlY9dYhK9Yqvby4rpNty8c=";
	};
	buildInputs = with perlPackages; [ ModuleBuildTiny ModuleRuntime PathTiny TestDeep TestFatal TestNeeds TestTrap TestWarnings ];
	propagatedBuildInputs = with perlPackages; [ GetoptLongDescriptive Moose MooseXRoleParameterized TryTiny namespaceautoclean ];
	meta = {
		homepage = "https://github.com/moose/MooseX-Getopt";
		description = "A Moose role for processing command line options";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
