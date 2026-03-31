{
  description = "Nix flake for the Collector app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f system (import nixpkgs { inherit system; }));
    in
    {
      packages = forAllSystems (system: pkgs:
        let
          python = pkgs.python3;
          pythonPackages = pkgs.python3Packages;

          collector = pkgs.stdenv.mkDerivation {
            pname = "collector";
            version = "1.0.3";
            src = ./.;

            nativeBuildInputs = with pkgs; [
              appstream
              desktop-file-utils
              gettext
              gobject-introspection
              glib
              meson
              ninja
              pkg-config
              python
              pythonPackages.wrapPython
              wrapGAppsHook4
            ];

            buildInputs = with pkgs; [
              gtk4
              libadwaita
            ];

            propagatedBuildInputs = with pythonPackages; [
              pillow
              pygobject3
              requests
            ];

            postFixup = ''
              wrapPythonPrograms
            '';

            meta = with pkgs.lib; {
              description = "Drag-and-drop helper built with GTK4 and Libadwaita";
              homepage = "https://github.com/mijorus/collector";
              license = licenses.gpl3Plus;
              platforms = platforms.linux;
              mainProgram = "collector";
            };
          };
        in
        {
          default = collector;
          collector = collector;
        });

      apps = forAllSystems (system: pkgs:
        let
          collector = self.packages.${system}.collector;
        in
        {
          default = {
            type = "app";
            program = "${collector}/bin/collector";
          };

          collector = {
            type = "app";
            program = "${collector}/bin/collector";
          };
        });
    };
}
