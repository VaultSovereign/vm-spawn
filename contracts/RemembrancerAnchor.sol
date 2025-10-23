// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RemembrancerAnchor {
    event BatchAnchored(bytes32 indexed root, bytes32 indexed batchId, string memo);

    mapping(bytes32 => bool) public knownRoots;

    function anchor(bytes32 root, bytes32 batchId, string calldata memo, bool persist) external {
        emit BatchAnchored(root, batchId, memo);
        if (persist) {
            knownRoots[root] = true;
        }
    }
}
