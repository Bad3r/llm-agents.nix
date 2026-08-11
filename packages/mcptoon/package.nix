{
  lib,
  python3,
  fetchFromGitHub,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "mcptoon";
  version = "0.1.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "activeing123";
    repo = "mcptoon";
    tag = "v${version}";
    hash = "sha256-JoN3YmBVstzIFF5pxizwrSdSqPO5jlD1Qz0avU3PMgo=";
  };

  build-system = with python3.pkgs; [
    setuptools
  ];

  pythonImportsCheck = [ "mcptoon" ];

  nativeCheckInputs = with python3.pkgs; [
    pytestCheckHook
  ];

  # config.py creates ~/.config/mcptoon at import time; the tests
  # import it, so they need a writable HOME.
  preCheck = ''
    export HOME=$TMPDIR
  '';

  passthru.category = "Utilities";

  meta = with lib; {
    description = "Token-efficient MCP CLI client that converts tool discovery and results to compact TOON output";
    homepage = "https://github.com/activeing123/mcptoon";
    changelog = "https://github.com/activeing123/mcptoon/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ zimbatm ];
    mainProgram = "mcptoon";
    platforms = platforms.all;
  };
}
