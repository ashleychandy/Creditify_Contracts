// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ITransferStrategyBase} from "../interfaces/ITransferStrategyBase.sol";
import {SafeERC20} from "../../dependencies/openzeppelin/contracts/SafeERC20.sol";
import {IERC20} from "../../dependencies/openzeppelin/contracts/IERC20.sol";

abstract contract TransferStrategyBase is ITransferStrategyBase {
    using SafeERC20 for IERC20;

    address internal immutable INCENTIVES_CONTROLLER;
    address internal immutable REWARDS_ADMIN;

    constructor(address incentivesController, address rewardsAdmin) {
        INCENTIVES_CONTROLLER = incentivesController;
        REWARDS_ADMIN = rewardsAdmin;
    }

    modifier onlyIncentivesController() {
        require(INCENTIVES_CONTROLLER == msg.sender, CallerNotIncentivesController());
        _;
    }

    modifier onlyRewardsAdmin() {
        require(msg.sender == REWARDS_ADMIN, OnlyRewardsAdmin());
        _;
    }

    function getIncentivesController() external view override returns (address) {
        return INCENTIVES_CONTROLLER;
    }

    function getRewardsAdmin() external view override returns (address) {
        return REWARDS_ADMIN;
    }

    function performTransfer(address to, address reward, uint256 amount) external virtual returns (bool);

    function emergencyWithdrawal(address token, address to, uint256 amount) external onlyRewardsAdmin {
        IERC20(token).safeTransfer(to, amount);

        emit EmergencyWithdrawal(msg.sender, token, to, amount);
    }
}
