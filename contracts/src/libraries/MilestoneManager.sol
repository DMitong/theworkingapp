// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IDataTypes.sol";

/// @title MilestoneManager
/// @notice Shared helpers for sequential milestone workflows.
library MilestoneManager {
    error MilestonesAlreadyInitialized();
    error NoMilestonesProvided();
    error InvalidMilestoneIndex();
    error InvalidMilestoneValue();
    error OutOfOrderMilestone(uint8 expected, uint8 received);
    error MilestoneNotPending();
    error MilestoneNotUnderReview();
    error DuplicateSignature(address signer);

    function initializeMilestones(
        IDataTypes.MilestoneDefinition[] storage self,
        IDataTypes.MilestoneDefinition[] memory definitions
    ) internal returns (uint256 totalValue) {
        if (self.length != 0) revert MilestonesAlreadyInitialized();
        if (definitions.length == 0) revert NoMilestonesProvided();

        for (uint256 i = 0; i < definitions.length; i++) {
            if (definitions[i].value == 0) revert InvalidMilestoneValue();
            self.push(definitions[i]);
            totalValue += definitions[i].value;
        }
    }

    function claimMilestone(
        IDataTypes.MilestoneDefinition[] storage self,
        uint8 currentMilestoneIndex,
        uint8 milestoneIndex,
        string memory ipfsEvidence
    ) internal {
        if (milestoneIndex >= self.length) revert InvalidMilestoneIndex();
        if (milestoneIndex != currentMilestoneIndex) {
            revert OutOfOrderMilestone(currentMilestoneIndex, milestoneIndex);
        }

        IDataTypes.MilestoneDefinition storage milestone = self[milestoneIndex];
        if (
            milestone.state != IDataTypes.MilestoneState.PENDING &&
            milestone.state != IDataTypes.MilestoneState.REJECTED
        ) {
            revert MilestoneNotPending();
        }

        milestone.ipfsEvidence = ipfsEvidence;
        milestone.state = IDataTypes.MilestoneState.UNDER_REVIEW;
        milestone.signaturesReceived = 0;
    }

    function signMilestone(
        IDataTypes.MilestoneDefinition[] storage self,
        mapping(uint8 => mapping(address => bool)) storage signatures,
        uint8 milestoneIndex,
        address signer
    ) internal returns (uint8 signaturesReceived) {
        if (milestoneIndex >= self.length) revert InvalidMilestoneIndex();

        IDataTypes.MilestoneDefinition storage milestone = self[milestoneIndex];
        if (milestone.state != IDataTypes.MilestoneState.UNDER_REVIEW) {
            revert MilestoneNotUnderReview();
        }
        if (signatures[milestoneIndex][signer]) revert DuplicateSignature(signer);

        signatures[milestoneIndex][signer] = true;
        milestone.signaturesReceived += 1;
        signaturesReceived = milestone.signaturesReceived;
    }

    function completeMilestone(
        IDataTypes.MilestoneDefinition[] storage self,
        uint8 milestoneIndex
    ) internal returns (bool allPaid) {
        if (milestoneIndex >= self.length) revert InvalidMilestoneIndex();

        IDataTypes.MilestoneDefinition storage milestone = self[milestoneIndex];
        if (milestone.state != IDataTypes.MilestoneState.UNDER_REVIEW) {
            revert MilestoneNotUnderReview();
        }

        milestone.state = IDataTypes.MilestoneState.PAID;
        allPaid = isAllMilestonesPaid(self);
    }

    function rejectMilestone(
        IDataTypes.MilestoneDefinition[] storage self,
        uint8 milestoneIndex
    ) internal returns (uint8 rejectionCount) {
        if (milestoneIndex >= self.length) revert InvalidMilestoneIndex();

        IDataTypes.MilestoneDefinition storage milestone = self[milestoneIndex];
        if (milestone.state != IDataTypes.MilestoneState.UNDER_REVIEW) {
            revert MilestoneNotUnderReview();
        }

        milestone.state = IDataTypes.MilestoneState.REJECTED;
        milestone.rejectionCount += 1;
        milestone.signaturesReceived = 0;
        rejectionCount = milestone.rejectionCount;
    }

    function getRemainingEscrow(
        IDataTypes.MilestoneDefinition[] storage self,
        uint8 currentMilestoneIndex
    ) internal view returns (uint256 remaining) {
        for (uint256 i = currentMilestoneIndex; i < self.length; i++) {
            if (self[i].state != IDataTypes.MilestoneState.PAID) {
                remaining += self[i].value;
            }
        }
    }

    function isAllMilestonesPaid(IDataTypes.MilestoneDefinition[] storage self) internal view returns (bool) {
        for (uint256 i = 0; i < self.length; i++) {
            if (self[i].state != IDataTypes.MilestoneState.PAID) {
                return false;
            }
        }
        return true;
    }
}
