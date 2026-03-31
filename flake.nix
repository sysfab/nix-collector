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
          appId = "sysfab.nix.collector";
          appName = "collector";
          shareDir = "$out/share/${appName}";
          appDir = "${shareDir}/${appName}";
          desktopFile = "${appId}.desktop";
          metainfoFile = "${appId}.metainfo.xml";
          schemaFile = "${appId}.gschema.xml";
          scalableIcon = "${appId}.svg";
          symbolicIcon = "${appId}-symbolic.svg";
          python = pkgs.python3;
          pythonPackages = pkgs.python3Packages;

          collector = pkgs.stdenv.mkDerivation {
            pname = appName;
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

              applicationsDir="$out/share/applications"
              metainfoDir="$out/share/metainfo"
              schemasDir="$out/share/glib-2.0/schemas"
              scalableIconsDir="$out/share/icons/hicolor/scalable/apps"
              symbolicIconsDir="$out/share/icons/hicolor/symbolic/apps"

              mkdir -p "$out/bin" "${shareDir}" "$applicationsDir" "$metainfoDir" "$schemasDir" "$scalableIconsDir" "$symbolicIconsDir"

              cp -r src "${appDir}"
              rm "${appDir}/collector.gresource.xml"
              cp collector.gresource "${shareDir}/collector.gresource"

              install -m755 src/collector "$out/bin/${appName}"

              install -m644 "data/${appId}.desktop.in" \
                "$applicationsDir/${desktopFile}"
              install -m644 "data/${appId}.metainfo.xml.in" \
                "$metainfoDir/${metainfoFile}"
              install -m644 "data/${appId}.gschema.xml" \
                "$schemasDir/${schemaFile}"

              install -m644 "data/icons/hicolor/scalable/apps/${scalableIcon}" \
                "$scalableIconsDir/${scalableIcon}"
              install -m644 "data/icons/hicolor/symbolic/apps/${symbolicIcon}" \
                "$symbolicIconsDir/${symbolicIcon}"

              for poFile in po/*.po; do
                lang="$(basename "$poFile" .po)"
                mkdir -p "$out/share/locale/$lang/LC_MESSAGES"
                msgfmt "$poFile" -o "$out/share/locale/$lang/LC_MESSAGES/${appName}.mo"
              done

              glib-compile-schemas "$schemasDir"

              runHook postInstall
            '';

            doInstallCheck = true;

            installCheckPhase = ''
              runHook preInstallCheck
              desktop-file-validate "$out/share/applications/${desktopFile}"
              appstreamcli validate --no-net --explain "$out/share/metainfo/${metainfoFile}"
              runHook postInstallCheck
            '';

            postFixup = ''
              wrapPythonPrograms
            '';

            meta = with pkgs.lib; {
              description = "Drag-and-drop helper built with GTK4 and Libadwaita";
              homepage = "https://github.com/sysfab/nix-collector";
              license = licenses.gpl3Plus;
              platforms = platforms.linux;
              mainProgram = appName;
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
