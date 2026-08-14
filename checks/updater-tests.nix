# Run the updater library's stdlib unittest modules under the flake check.
# Discovery picks up every scripts/updater/*_test.py, so new tests are free.
{
  pkgs,
  flake,
}:
pkgs.runCommand "updater-tests-check"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    cp -r ${flake}/scripts scripts
    chmod -R +w scripts
    cd scripts
    export HOME=$TMPDIR
    export PYTHONDONTWRITEBYTECODE=1
    python3 -m unittest discover -s updater -p '*_test.py' -t . -v
    touch $out
  ''
