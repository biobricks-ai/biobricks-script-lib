{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Getopt-Long";
	version = "2.58";
	src = fetchurl {
		url = "mirror://cpan/authors/id/J/JV/JV/Getopt-Long-2.58.tar.gz";
		hash = "sha256-EwXtRuoh95QwTpeqPc06OFGQWXhenbdBXa8sIYUGxWk=";
	};
	meta = {
		description = "Module to handle parsing command line options";
	};
}
