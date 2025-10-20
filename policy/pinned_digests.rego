package vaultmesh.policy

deny[msg] {
  input.dockerfile.base.tag != ""
  not contains(input.dockerfile.base.tag, "@sha256:")
  msg := sprintf("Base image must be pinned by digest, not tag: %v", [input.dockerfile.base.tag])
}

