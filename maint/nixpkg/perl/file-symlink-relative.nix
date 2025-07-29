{ perlPackages, fetchurl, lib, pkgs }:

perlPackages.buildPerlPackage {
	pname = "File-Symlink-Relative";
	version = "0.005";
	src = fetchurl {
		url = "mirror://cpan/authors/id/W/WY/WYANT/File-Symlink-Relative-0.005.tar.gz";
		hash = "sha256-lH6CthfIr6mpcK31gZ5QWhziqiEMQxsgN6WoigUm1nI=";
	};
	buildInputs = with perlPackages; [ Test2Suite pkgs.perlPackages.Test2ToolsLoadModule ];
	meta = {
		description = "Create relative symbolic links";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
