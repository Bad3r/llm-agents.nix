{ lib, antigravity-cli }:
lib.warnOnInstantiate "'antigravity' has been renamed to 'antigravity-cli'. Please update your references." antigravity-cli
// {
  passthru.hideFromDocs = true;
}
