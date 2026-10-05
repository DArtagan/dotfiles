{
  fetchurl,
  lib,
  stdenvNoCC,
}:

# Gives pi an `ask_user_question` tool: a tabbed dialog of up to four multiple-choice
# questions, for the model to ask rather than guess. pi loads it from the store path
# (settings.json `packages`). Built from the npm release, since the source lives in a
# monorepo (juicesharp/rpiv-mono). Its one runtime dependency is rpiv-config, at the
# matching release; pi supplies typebox and the @earendil-works/* modules, and the
# optional @juicesharp/rpiv-i18n (translated dialog chrome) is left out.
let
  version = "2.12.0";

  rpiv-config = fetchurl {
    url = "https://registry.npmjs.org/@juicesharp/rpiv-config/-/rpiv-config-${version}.tgz";
    hash = "sha512-eGjoCDCKz2JtKIUIpZ2y8CAVjxZYXCKa2D64ByozhkAWVblXsgyFLrQMk5k5Bv5RXRrA3GY66XNG5ExtEuGASA==";
  };
in
stdenvNoCC.mkDerivation {
  pname = "rpiv-ask-user-question";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@juicesharp/rpiv-ask-user-question/-/rpiv-ask-user-question-${version}.tgz";
    hash = "sha512-DilWc7u25SwnK6ytuAWOTerP0AmOEfK4HXpgS1oEzkgv9d5g5T+PbLG+zcLn18M3B/J3poMG14iydG5O6iBsnw==";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/node_modules/@juicesharp/rpiv-config
    cp -r . $out/
    tar xzf ${rpiv-config} --strip-components=1 -C $out/node_modules/@juicesharp/rpiv-config
    runHook postInstall
  '';

  meta = {
    description = "Structured questionnaire tool for the pi coding agent";
    homepage = "https://github.com/juicesharp/rpiv-mono/tree/main/packages/rpiv-ask-user-question";
    license = lib.licenses.mit;
  };
}
