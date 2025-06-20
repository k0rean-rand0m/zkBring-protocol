// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./Events.sol";
import {IzkBringRegistry} from "./IzkBringRegistry.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {ISemaphore} from "semaphore-protocol/interfaces/ISemaphore.sol";
import {Ownable2Step} from "openzeppelin/access/Ownable2Step.sol";

contract zkBringRegistry is IzkBringRegistry, Ownable2Step {
    using ECDSA for bytes32;

    ISemaphore public immutable SEMAPHORE;
    address public TLSNVerifier;
    mapping(uint256 verifivationId => uint256 semaphoreGroupId) private _semaphoreGroupIds;
    mapping(bytes32 nullifier => bool isConsumed) private _nonceUsed;

    constructor(ISemaphore semaphore_, address TLSNVerifier_) {
        SEMAPHORE = semaphore_;
        TLSNVerifier = TLSNVerifier_;
        SEMAPHORE.createGroup(); // We create an empty Semaphore group to drop groupId: 0
    }

    function joinGroup(
        TLSNVerifierMessage memory verifierMessage_,
        bytes memory signature_
    ) public {
        bytes32 r; bytes32 s; uint8 v;
        assembly {
            r := mload(add(signature_, 0x20))
            s := mload(add(signature_, 0x40))
            v := byte(0, mload(add(signature_, 0x60)))
        }
        joinGroup(verifierMessage_, v, r, s);
    }

    function joinGroup(
        TLSNVerifierMessage memory verifierMessage_,
        uint8 v, bytes32 r, bytes32 s
    ) public {
        uint256 semaphoreGroupId = _semaphoreGroupIds[verifierMessage_.verificationId];
        bytes32 nonce = keccak256(
            abi.encode(
                verifierMessage_.registry,
                verifierMessage_.verificationId,
                verifierMessage_.idHash
            )
        );

        require(semaphoreGroupId != 0, "Verification doesn't exist");
        require(verifierMessage_.registry == address(this), "Wrong Verifier message");
        require(!_nonceUsed[nonce], "Nonce is used");

        (address signer,) = keccak256(
            abi.encode(verifierMessage_)
        ).toEthSignedMessageHash().tryRecover(v, r, s);

        require(signer == TLSNVerifier, "Invalid TLSN Verifier signature");

        SEMAPHORE.addMember(semaphoreGroupId, verifierMessage_.semaphoreIdentityCommitment);
        _nonceUsed[nonce] = true;
        emit Verified(verifierMessage_.verificationId, verifierMessage_.semaphoreIdentityCommitment);
    }

    // @notice Validates Semaphore proof
    // @dev `context_` parameter here is concatenated with sender address
    function validateProof(
        uint256 verificationId_,
        uint256 context_,
        SemaphoreProof calldata proof_
    ) public {
        uint256 semaphoreGroupId = _semaphoreGroupIds[verificationId_];
        require(semaphoreGroupId != 0, "Verification doesn't exist");

        ISemaphore.SemaphoreProof memory proof = ISemaphore.SemaphoreProof(
            proof_.merkleTreeDepth,
            proof_.merkleTreeRoot,
            proof_.nullifier,
            proof_.message,
            uint256(keccak256(abi.encode(msg.sender, context_))),
            proof_.points
        );
        SEMAPHORE.validateProof(semaphoreGroupId, proof);
        emit Proved(verificationId_);
    }

    // ONLY OWNER //

    function newVerification(
        uint256 verificationId
    ) public onlyOwner {
        require(_semaphoreGroupIds[verificationId] == 0, "Verification exists");
        _semaphoreGroupIds[verificationId] = SEMAPHORE.createGroup();
        emit VerificationCreated(verificationId);
    }

    // TODO: Suspend verification

    function setVerifier(
        address TLSNVerifier_
    ) public onlyOwner {
        TLSNVerifier = TLSNVerifier_;
        emit TLSNVerifierSet(TLSNVerifier_);
    }
}
