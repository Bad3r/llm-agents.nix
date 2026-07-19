{ lib, forgecode }:
lib.warnOnInstantiate "'forge' has been renamed to 'forgecode'. Please update your references." forgecode
// {
  passthru.hideFromDocs = true;
}
