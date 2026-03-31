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

            dontConfigure = true;

            preBuild = ''
              glib-compile-resources \
                src/collector.gresource.xml \
                --sourcedir=src \
                --target=collector.gresource
            '';

            nativeBuildInputs = with pkgs; [
              appstream
              desktop-file-utils
              gettext
              gobject-introspection
              glib
              libxml2
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

            installPhase = ''
              runHook preInstall

              mkdir -p "$out/bin"
              mkdir -p "$out/share/collector"
              mkdir -p "$out/share/applications"
              mkdir -p "$out/share/metainfo"
              mkdir -p "$out/share/glib-2.0/schemas"
              mkdir -p "$out/share/icons/hicolor/scalable/apps"
              mkdir -p "$out/share/icons/hicolor/symbolic/apps"

              cp -r src "$out/share/collector/collector"
              rm "$out/share/collector/collector/collector.gresource.xml"
              cp collector.gresource "$out/share/collector/collector.gresource"

              install -m755 src/collector "$out/bin/collector"

              install -m644 data/sysfab.nix.collector.desktop.in \
                "$out/share/applications/sysfab.nix.collector.desktop"
              install -m644 data/sysfab.nix.collector.metainfo.xml.in \
                "$out/share/metainfo/sysfab.nix.collector.metainfo.xml"
              install -m644 data/sysfab.nix.collector.gschema.xml \
                "$out/share/glib-2.0/schemas/sysfab.nix.collector.gschema.xml"

              install -m644 data/icons/hicolor/scalable/apps/sysfab.nix.collector.svg \
                "$out/share/icons/hicolor/scalable/apps/sysfab.nix.collector.svg"
              install -m644 data/icons/hicolor/symbolic/apps/sysfab.nix.collector-symbolic.svg \
                "$out/share/icons/hicolor/symbolic/apps/sysfab.nix.collector-symbolic.svg"

              for poFile in po/*.po; do
                lang="$(basename "$poFile" .po)"
                mkdir -p "$out/share/locale/$lang/LC_MESSAGES"
                msgfmt "$poFile" -o "$out/share/locale/$lang/LC_MESSAGES/collector.mo"
              done

              glib-compile-schemas "$out/share/glib-2.0/schemas"

              runHook postInstall
            '';

            doInstallCheck = true;

            installCheckPhase = ''
              runHook preInstallCheck
              desktop-file-validate "$out/share/applications/sysfab.nix.collector.desktop"
              appstreamcli validate --no-net --explain "$out/share/metainfo/sysfab.nix.collector.metainfo.xml"
              runHook postInstallCheck
            '';

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
