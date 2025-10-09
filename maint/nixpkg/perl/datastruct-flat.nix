{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "DataStruct-Flat";
	version = "0.01";
	src = fetchurl {
		url = "mirror://cpan/authors/id/J/JL/JLMARTIN/DataStruct-Flat-0.01.tar.gz";
		hash = "sha256-b2TixvR15tCsahd68Gmg5ShfURHeWWUKv5Mx0iqcC7s=";
	};
	propagatedBuildInputs = with perlPackages; [ Moo ];
	meta = {
		description = "Convert a data structure into a one level list of keys and values";
		license = lib.licenses.asl20;
	};
}
