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
  version = "2.15.0";

  rpiv-config = fetchurl {
    url = "https://registry.npmjs.org/@juicesharp/rpiv-config/-/rpiv-config-${version}.tgz";
    hash = "sha512-S2BAGX4dJjQ2AyNYOEjC6ha04p9f6CdEfmtxpdxzSKrfDMwqIvOjjO9HiHc1IPY7jDY1q2Q8cGCtpIZWV6Y8NQ==";
  };
in
stdenvNoCC.mkDerivation {
  pname = "rpiv-ask-user-question";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@juicesharp/rpiv-ask-user-question/-/rpiv-ask-user-question-${version}.tgz";
    hash = "sha512-Gm6de5IZF52BaSeh9dnDqJBn821Z5XfJkCmhkCmqTzvNv3SCpSv1mA4Gj5VBcfrSe+xTtWSVQzJwIqJFQHH3Lg==";
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
