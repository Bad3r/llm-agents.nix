{ lib, aperant }:
lib.warnOnInstantiate "'auto-claude' has been renamed to 'aperant'. Please update your references." aperant
// {
  passthru.hideFromDocs = true;
}
