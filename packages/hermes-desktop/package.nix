{
  lib,
  hermes-one,
}:
lib.warnOnInstantiate "'hermes-desktop' has been renamed to 'hermes-one'. Please update your references." hermes-one
// {
  passthru.hideFromDocs = true;
}
