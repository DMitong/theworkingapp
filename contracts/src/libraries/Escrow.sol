// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IDataTypes.sol";

/// @title Escrow
/// @notice Shared escrow accounting primitives for project and bounty contracts.
library Escrow {
    using SafeERC20 for IERC20;

    error EscrowFrozen();
    error InvalidToken();
    error InvalidRecipient();
    error ZeroAmount();
    error InsufficientMilestoneBalance(uint256 available, uint256 requested);
    error NoEscrowBalance();

    struct Ledger {
        uint256 totalDeposited;
        uint256 totalReleased;
        uint256 disputeHold;
        bool frozen;
        mapping(uint8 => uint256) milestoneBalances;
    }

    function initializeMilestoneBalances(
        Ledger storage self,
        IDataTypes.MilestoneDefinition[] storage milestones
    ) internal {
        for (uint8 i = 0; i < milestones.length; i++) {
            self.milestoneBalances[i] = milestones[i].value;
        }
    }

    function initializeMilestoneBalance(Ledger storage self, uint8 milestoneIndex, uint256 amount) internal {
        self.milestoneBalances[milestoneIndex] = amount;
    }

    function deposit(Ledger storage self, uint256 amount, address token) internal {
        if (self.frozen) revert EscrowFrozen();
        if (token == address(0)) revert InvalidToken();
        if (amount == 0) revert ZeroAmount();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        self.totalDeposited += amount;
    }

    function releaseMilestone(
        Ledger storage self,
        uint8 milestoneIndex,
        address recipient,
        uint256 amount,
        address token
    ) internal {
        if (self.frozen) revert EscrowFrozen();
        if (recipient == address(0)) revert InvalidRecipient();
        if (token == address(0)) revert InvalidToken();
        if (amount == 0) revert ZeroAmount();

        uint256 available = self.milestoneBalances[milestoneIndex];
        if (available < amount) {
            revert InsufficientMilestoneBalance(available, amount);
        }

        self.milestoneBalances[milestoneIndex] = available - amount;
        self.totalReleased += amount;
        IERC20(token).safeTransfer(recipient, amount);
    }

    function freeze(Ledger storage self) internal {
        self.frozen = true;
        self.disputeHold = remainingBalance(self);
    }

    function unfreeze(Ledger storage self) internal {
        self.frozen = false;
        self.disputeHold = 0;
    }

    function releaseAll(Ledger storage self, address recipient, address token) internal returns (uint256 amount) {
        if (self.frozen) revert EscrowFrozen();
        if (recipient == address(0)) revert InvalidRecipient();
        if (token == address(0)) revert InvalidToken();

        amount = remainingBalance(self);
        if (amount == 0) revert NoEscrowBalance();

        self.totalReleased += amount;
        IERC20(token).safeTransfer(recipient, amount);
    }

    function refundAll(Ledger storage self, address funder, address token) internal returns (uint256 amount) {
        amount = releaseAll(self, funder, token);
    }

    function getMilestoneBalance(Ledger storage self, uint8 milestoneIndex) internal view returns (uint256) {
        return self.milestoneBalances[milestoneIndex];
    }

    function remainingBalance(Ledger storage self) internal view returns (uint256) {
        return self.totalDeposited - self.totalReleased;
    }
}
