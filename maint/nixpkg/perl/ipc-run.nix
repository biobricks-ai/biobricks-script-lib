{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "IPC-Run";
	version = "20250809.0";
	src = fetchurl {
		url = "mirror://cpan/authors/id/N/NJ/NJM/IPC-Run-20250809.0.tar.gz";
		hash = "sha256-sehaMEBXhu2DeLaN1XFZMVrX3cClXkMqqe7KYWbKU/4=";
	};
	buildInputs = with perlPackages; [ Readonly ];
	propagatedBuildInputs = with perlPackages; [ IOTty ];
	meta = {
		description = "System() and background procs w/ piping, redirs, ptys (Unix, Win32)";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
