// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IDataTypes.sol";

/// @title Voting
/// @notice Shared vote tracking and quorum helpers for governance and milestone flows.
library Voting {
    error AlreadyVoted();
    error InvalidChoice();
    error InvalidThreshold();
    error NoChoicesProvided();

    struct Tally {
        mapping(uint8 => uint256) counts;
        uint256 totalCast;
    }

    function castVote(
        mapping(address => uint8) storage votes,
        Tally storage tally,
        address voter,
        uint8 choice
    ) internal {
        if (choice == 0) revert InvalidChoice();
        if (votes[voter] != 0) revert AlreadyVoted();

        votes[voter] = choice;
        tally.counts[choice] += 1;
        tally.totalCast += 1;
    }

    function hasVoted(mapping(address => uint8) storage votes, address voter) internal view returns (bool) {
        return votes[voter] != 0;
    }

    function getVoteCount(Tally storage tally, uint8 choice) internal view returns (uint256) {
        return tally.counts[choice];
    }

    function getVoteCounts(Tally storage tally, uint8[] memory choices) internal view returns (uint256[] memory counts) {
        if (choices.length == 0) revert NoChoicesProvided();

        counts = new uint256[](choices.length);
        for (uint256 i = 0; i < choices.length; i++) {
            counts[i] = tally.counts[choices[i]];
        }
    }

    function meetsThreshold(
        uint256 supportingVotes,
        uint256 totalEligible,
        uint256 thresholdBps
    ) internal pure returns (bool) {
        if (thresholdBps > 10_000) revert InvalidThreshold();
        if (totalEligible == 0) return false;
        return supportingVotes * 10_000 >= totalEligible * thresholdBps;
    }

    function hasSignatureQuorum(uint256 signatureCount, uint256 required) internal pure returns (bool) {
        return required > 0 && signatureCount >= required;
    }

    function getResult(
        Tally storage tally,
        uint256 totalEligible,
        uint256 thresholdBps,
        uint8 approveChoice,
        uint8 rejectChoice,
        uint8 disputeChoice
    ) internal view returns (IDataTypes.VoteOutcome) {
        if (meetsThreshold(tally.counts[disputeChoice], totalEligible, thresholdBps)) {
            return IDataTypes.VoteOutcome.DISPUTED;
        }
        if (meetsThreshold(tally.counts[approveChoice], totalEligible, thresholdBps)) {
            return IDataTypes.VoteOutcome.APPROVED;
        }
        if (meetsThreshold(tally.counts[rejectChoice], totalEligible, thresholdBps)) {
            return IDataTypes.VoteOutcome.REJECTED;
        }
        return IDataTypes.VoteOutcome.PENDING;
    }

    function getWinningChoice(Tally storage tally, uint8[] memory choices) internal view returns (uint8 winner) {
        if (choices.length == 0) revert NoChoicesProvided();

        uint256 highestCount;
        for (uint256 i = 0; i < choices.length; i++) {
            uint256 count = tally.counts[choices[i]];
            if (count > highestCount) {
                highestCount = count;
                winner = choices[i];
            }
        }
    }
}
