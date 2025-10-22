package vm.admission

# Schemas map is provided via Harbinger config data injection.

default allow = false

allow {
  input.jcs == true
  input.event.schema == data.schemas[input.event["event:type"]]
  valid_ts
  valid_sig
}

# Only authorized actors may change cadence config
allow {
  input.event.type == "governance.cadence.set"
  some a
  a := input.event.actor
  a == data.governance.admin  # load from data or tags
}

valid_ts {
  now := time.now_ns() / 1000000000
  abs(now - input.event.timestamp) <= 300
}

valid_sig {
  some s
  s := input.event.signatures[_]
  s.alg == "Ed25519" or s.alg == "secp256k1"
}
