{
  buildNpmPackage,
  fetchurl,
  lib,
  nodejs,
  runtimeShell,
  stdenv,
}:

# Browser UI for pi sessions (agegr/pi-web). Packaged from the npm release, which
# ships the prebuilt Next.js app: building from source fetches a Google font, which
# the sandbox blocks. The release has no lockfile, so this uses the repo's lockfile
# at the same tag, whose root dependencies match the release's.
let
  version = "0.12.1";
in
buildNpmPackage {
  pname = "agegr-pi-web";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@agegr/pi-web/-/pi-web-${version}.tgz";
    hash = "sha512-LKBAOeV4D4Vs0WuVz1JD303wMdIaClCM2m4TwmO9vwYIagFmSHOMuBhR+CdweRVntpXSbOFI2x0m8twzxRcvwg==";
  };

  prePatch = ''
    cp ${
      fetchurl {
        url = "https://raw.githubusercontent.com/agegr/pi-web/v${version}/package-lock.json";
        hash = "sha256-sH3u69Ethgr1PGSCE/u9mQScAWsLH3qAstp4NXAJc+s=";
      }
    } package-lock.json
    chmod u+w package-lock.json
  '';

  # v1 can't find the tarballs the lockfile lists twice (pi 1.0.0's packages, nested
  # under pi-coding-agent as well as at the top level).
  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-8CeCo/o4pslL1bqu1DFsH++1YYY66F1WZyBfoCDqVz4=";

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
      # Native binaries for other platforms, if any: pi up to 1.0 had npm install every
      # esbuild from its shrinkwrap, about 400 MB.
      find "$pkg/node_modules" -type d \( -path "*/@esbuild/*" -o -path "*/@next/swc-*" -o -path "*/@img/sharp-*" \) -prune |
        { grep -Ev "/(linux-${arch}|swc-linux-${arch}-gnu|sharp-linux-${arch}|sharp-libvips-linux-${arch})$" || true; } |
        xargs -r rm -rf
      # In place of the usual wrapper, so pi-web can rotate its preview-mode secrets;
      # see pi-web.sh.
      rm $out/bin/pi-web
      substitute ${./pi-web.sh} $out/bin/pi-web \
        --subst-var-by shell ${runtimeShell} \
        --subst-var-by pkg "$pkg" \
        --subst-var-by node ${lib.getExe nodejs}
      chmod +x $out/bin/pi-web
    '';

  meta = {
    description = "Web UI for the pi coding agent";
    homepage = "https://github.com/agegr/pi-web";
    license = lib.licenses.mit;
    mainProgram = "pi-web";
  };
}
