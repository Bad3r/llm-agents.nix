{
  lib,
  python3,
  fetchFromGitHub,
}:

let
  # nixpkgs still ships mcp 1.x, which lacks the MCPServer API spec-kit uses.
  # 2.2.0 is the newest release that accepts the httpx2 from nixpkgs.
  mcpVersion = "2.2.0";
  mcpSrc = fetchFromGitHub {
    owner = "modelcontextprotocol";
    repo = "python-sdk";
    tag = "v${mcpVersion}";
    hash = "sha256-nnpNXnQiFSGx5KQBDXHCOH0wE3cznlmI6s7vtchcj3A=";
  };
  mcpMeta = python3.pkgs.mcp.meta // {
    changelog = "https://github.com/modelcontextprotocol/python-sdk/releases/tag/v${mcpVersion}";
  };

  mcp-types = python3.pkgs.buildPythonPackage {
    pname = "mcp-types";
    version = mcpVersion;
    src = mcpSrc;
    sourceRoot = "${mcpSrc.name}/src/mcp-types";
    pyproject = true;
    build-system = with python3.pkgs; [
      hatchling
      uv-dynamic-versioning
    ];
    dependencies = with python3.pkgs; [
      pydantic
      typing-extensions
    ];
    pythonImportsCheck = [ "mcp_types" ];
    meta = mcpMeta // {
      description = "Model Context Protocol wire types";
    };
  };

  mcp = python3.pkgs.buildPythonPackage {
    pname = "mcp";
    version = mcpVersion;
    src = mcpSrc;
    pyproject = true;
    build-system = with python3.pkgs; [
      hatchling
      uv-dynamic-versioning
    ];
    dependencies =
      with python3.pkgs;
      [
        anyio
        httpx2
        jsonschema
        mcp-types
        opentelemetry-api
        pydantic
        pyjwt
        python-multipart
        sse-starlette
        starlette
        typing-extensions
        typing-inspection
        uvicorn
      ]
      ++ pyjwt.optional-dependencies.crypto;
    pythonImportsCheck = [ "mcp.server" ];
    meta = mcpMeta;
  };
in
python3.pkgs.buildPythonApplication rec {
  pname = "spec-kit";
  version = "1.2.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "github";
    repo = "spec-kit";
    tag = "v${version}";
    hash = "sha256-wBQ16H/fYJoKJjC1yHxMsEDBJK7pmNhLeFsP6CH35Gw=";
  };

  build-system = with python3.pkgs; [
    hatchling
  ];

  dependencies = with python3.pkgs; [
    typer
    rich
    httpx
    socksio
    platformdirs
    readchar
    truststore
    pyyaml
    packaging
    pathspec
    json5
    mcp # the let binding above, not python3.pkgs.mcp
    pydantic
  ];

  pythonImportsCheck = [ "specify_cli" ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Specify CLI, part of GitHub Spec Kit. A tool to bootstrap your projects for Spec-Driven Development (SDD)";
    homepage = "https://github.com/github/spec-kit";
    changelog = "https://github.com/github/spec-kit/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    mainProgram = "specify";
  };
}
