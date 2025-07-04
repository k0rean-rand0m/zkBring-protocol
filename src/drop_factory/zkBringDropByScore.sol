// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IzkBringRegistry} from "../registry/IzkBringRegistry.sol";
import {zkBringDropBase} from "./zkBringDropBase.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract zkBringDropByScore is zkBringDropBase {
    uint256 public immutable scoreThreshold;

    constructor(
        uint256 scoreThreshold_,
        IzkBringRegistry registry_,
        address creator_,
        IERC20 token_,
        uint256 amount_,
        uint256 maxClaims_,
        uint256 expiration_,
        string memory metadataIpfsHash_,
        IERC20 bringToken_
    )
        zkBringDropBase(
            registry_,
            creator_,
            token_,
            amount_,
            maxClaims_,
            expiration_,
            metadataIpfsHash_,
            bringToken_
        )
    {
        scoreThreshold = scoreThreshold_;
    }

    function claim(IzkBringRegistry.VerificationProof[] calldata proofs) public {
        require(proofs.length != scoreThreshold, "Wrong amount of proofs provided");
        require(claims < maxClaims, "All claims exhausted");
        for (uint256 i; i < proofs.length; i++) {
            // TODO fix context - there should be 1 drop contract per verification
            registry.validateProof(0, proofs[i]);
        }
        claims++;
        require(
            token.transfer(msg.sender, amount),
            "Token transfer failed"
        );
    }
}
