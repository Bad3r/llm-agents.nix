{
  mkPackagesFor,
}:
# Builds the packages/ tree against the consumer's `final`, so dependencies
# are shared with their system. Unlike the flake packages, the binary cache
# only hits when the consumer's nixpkgs revision matches ours.
final: _prev: {
  llm-agents = mkPackagesFor final;
}
