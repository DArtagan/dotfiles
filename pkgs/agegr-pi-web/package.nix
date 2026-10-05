{
  buildNpmPackage,
  fetchurl,
  lib,
  stdenv,
}:

# Browser UI for pi sessions (agegr/pi-web). Packaged from the npm release, which
# ships the prebuilt Next.js app: building from source fetches a Google font, which
# the sandbox blocks. The release has no lockfile, so this uses the repo's lockfile
# at the same tag, whose root dependencies match the release's.
let
  version = "0.10.0";
in
buildNpmPackage {
  pname = "agegr-pi-web";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@agegr/pi-web/-/pi-web-${version}.tgz";
    hash = "sha512-ePmDbLYBrPH5rLIk+0ia8yKMd0iMh/Zk9P5c3kvO1TzWGzwpIlB9fqSmLvBr6fteKjAfGYyzTnmdQNv1GzpcGQ==";
  };

  prePatch = ''
    cp ${
      fetchurl {
        url = "https://raw.githubusercontent.com/agegr/pi-web/v${version}/package-lock.json";
        hash = "sha256-46W3N3+W4v46Z8TJZBOWrRk0pDLkJKbNsxd5VWAQ+M0=";
      }
    } package-lock.json
    chmod u+w package-lock.json
  '';

  patches = [
    # Seven entries lack `integrity`, which fetchNpmDeps requires; hashes from the npm registry.
    ./lockfile-integrity.patch
  ];

  # v1 can't find the tarballs the lockfile lists twice (pi 1.0.0's packages, nested
  # under pi-coding-agent as well as at the top level).
  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-b5jPpRshUBAxZN/BUlvD7cbJX4qSuSs6EsJc6MzDylI=";

  npmInstallFlags = [ "--omit=dev" ];
  dontNpmBuild = true;
  # Already installed without dev dependencies, and `npm prune` crashes on the
  # lockfile's bundled dependencies ("The \"from\" argument must be of type string").
  dontNpmPrune = true;

  postInstall =
    let
      arch = if stdenv.hostPlatform.isAarch64 then "arm64" else "x64";
    in
    ''
      pkg=$out/lib/node_modules/@agegr/pi-web
      # npm pack leaves out the prebuilt app, though package.json `files` lists it.
      cp -r .next "$pkg/"
      rm -rf "$pkg/.next/cache"
      # Native binaries for other platforms (npm installs every esbuild from pi's
      # shrinkwrap), about 400 MB.
      find "$pkg/node_modules" -type d \( -path "*/@esbuild/*" -o -path "*/@next/swc-*" -o -path "*/@img/sharp-*" \) -prune |
        grep -Ev "/(linux-${arch}|swc-linux-${arch}-gnu|sharp-linux-${arch}|sharp-libvips-linux-${arch})$" |
        xargs rm -rf
    '';

  makeWrapperArgs = [
    "--set-default"
    "NEXT_TELEMETRY_DISABLED"
    "1"
  ];

  meta = {
    description = "Web UI for the pi coding agent";
    homepage = "https://github.com/agegr/pi-web";
    license = lib.licenses.mit;
    mainProgram = "pi-web";
  };
}
