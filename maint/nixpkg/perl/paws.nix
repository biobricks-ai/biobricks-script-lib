{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlModule {
	pname = "Paws";
	version = "0.46";
	src = fetchurl {
		url = "mirror://cpan/authors/id/J/JR/JROBINSON/Paws-0.46.tar.gz";
		hash = "sha256-lh45QSi0w48OcRfLqAOg04UBYm/580uO4A+tmIbqTb8=";
	};
	buildInputs = with perlPackages; [ ClassUnload FileSlurper ModuleBuildTiny PathClass TestException TestTimer TestWarnings YAML ];
	propagatedBuildInputs = with perlPackages; [ ARGVStruct ConfigAWS DataCompare DataStructFlat DateTime DateTimeFormatISO8601 FileHomeDir IOSocketSSL JSONMaybeXS ModuleFind Moose MooseXClassAttribute MooseXGetopt NetAmazonSignatureV4 PathTiny StringCRC32 Throwable URI URITemplate URLEncode URLEncodeXS XMLSimple ];
	meta = {
		description = "A Perl SDK for AWS (Amazon Web Services) APIs";
		license = lib.licenses.asl20;
	};
	doCheck = false;
}
