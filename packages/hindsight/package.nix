{
  lib,
  flake,
  python3Packages,
  fetchFromGitHub,
  fetchPypi,
  rustPlatform,
}:
let
  toktok-rs = python3Packages.buildPythonPackage rec {
    pname = "toktok-rs";
    version = "0.1.4";
    pyproject = true;

    src = fetchPypi {
      pname = "toktok_rs";
      inherit version;
      hash = "sha256-VmlGDK4Mdlxhg6ZIrrDxK7YnQ/HfRQ+QqwUeYq+DxCY=";
    };

    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit pname version src;
      hash = "sha256-N6dunFUwDgTIk8ecvaBv+HR1tQo0bZUn9bJz2ht360c=";
    };

    nativeBuildInputs = with rustPlatform; [
      cargoSetupHook
      maturinBuildHook
    ];

    pythonImportsCheck = [ "toktok" ];

    meta = with lib; {
      description = "Fast, exact BPE tokenizer for OpenAI encodings — Rust core, tiktoken-identical ids";
      homepage = "https://github.com/vectorize-io/toktok";
      license = licenses.mit;
      maintainers = with flake.lib.maintainers; [ wanderer ];
    };
  };

  github-copilot-sdk = python3Packages.buildPythonPackage rec {
    pname = "github-copilot-sdk";
    version = "1.0.13";

    format = "wheel";

    # PyPI has no sdist, and the version is only injected at publish time.
    src = fetchPypi {
      pname = "github_copilot_sdk";
      inherit version format;
      dist = "py3";
      python = "py3";
      hash = "sha256-lB3VtVzzK6Vcc8ZRBSpKUrJZtHDGi/amrD0kDCNUAsk=";
    };

    dependencies = with python3Packages; [
      python-dateutil
      pydantic
      httpx
    ];

    pythonImportsCheck = [ "copilot" ];

    meta = with lib; {
      description = "Python SDK for GitHub Copilot CLI";
      homepage = "https://github.com/github/copilot-sdk";
      license = licenses.mit;
      maintainers = with flake.lib.maintainers; [ wanderer ];
    };
  };
in
python3Packages.buildPythonApplication rec {
  pname = "hindsight";
  version = "0.10.1";

  src = fetchFromGitHub {
    owner = "vectorize-io";
    repo = "hindsight";
    tag = "v${version}";
    hash = "sha256-/qafCyuk4Vrum19AoNRtbTo+eBGP90XzNdH/LBHO4Ig=";
  };

  sourceRoot = "${src.name}/hindsight-api-slim";
  pyproject = true;

  build-system = [ python3Packages.hatchling ];

  dependencies =
    with python3Packages;
    [
      asyncpg
      python-dotenv
      openai
      pydantic
      rich
      fastapi
      uvicorn
      wsproto
      sqlalchemy
      alembic
      pgvector
      greenlet
      psycopg2
      toktok-rs
      httpx
      pyjwt
      fastmcp
      python-dateutil
      opentelemetry-api
      opentelemetry-sdk
      opentelemetry-instrumentation-fastapi
      opentelemetry-exporter-prometheus
      opentelemetry-exporter-otlp-proto-http
      opentelemetry-semantic-conventions
      dateparser
      regex
      google-genai
      google-auth
      anthropic
      typer
      cohere
      litellm
      markitdown
      obstore
      uvloop
      pyasn1
      urllib3
      protobuf
      pillow
      cryptography
      filelock
      authlib
      orjson
      python-multipart
      aiohttp
      pygments
      boto3
      json-repair
      claude-agent-sdk
      github-copilot-sdk
      croniter
      numpy
    ]
    ++ fastapi.optional-dependencies.standard
    ++ lib.concatMap (extra: markitdown.optional-dependencies.${extra}) [
      "pdf"
      "docx"
      "pptx"
      "xlsx"
      "xls"
    ];

  # The default embeddings and reranker providers run locally and need these.
  # Left out of the default build to keep torch out of the closure; without
  # them set HINDSIGHT_API_{EMBEDDINGS,RERANKER}_PROVIDER to a remote provider.
  # flashrank, an alternative reranker, is not in nixpkgs.
  optional-dependencies.local-ml = with python3Packages; [
    sentence-transformers
    transformers
    tokenizers
    torch
    einops
    safetensors
  ];

  # nixpkgs lags slightly behind these floors.
  pythonRelaxDeps = [
    "boto3"
    "greenlet"
    "json-repair"
    # Capped on macOS only because newer releases ship no wheels there.
    "litellm"
    "opentelemetry-api"
    "opentelemetry-exporter-otlp-proto-http"
    "opentelemetry-exporter-prometheus"
    "opentelemetry-instrumentation-fastapi"
    "opentelemetry-sdk"
    "opentelemetry-semantic-conventions"
    "regex"
  ];

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'psycopg2-binary' 'psycopg2'
  '';

  # The tests need a PostgreSQL container.
  doCheck = false;

  pythonImportsCheck = [ "hindsight_api.main" ];

  passthru.category = "AI Assistants";

  meta = with lib; {
    description = "Agent memory server that learns from past interactions";
    homepage = "https://github.com/vectorize-io/hindsight";
    changelog = "https://github.com/vectorize-io/hindsight/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ wanderer ];
    mainProgram = "hindsight-api";
  };
}
