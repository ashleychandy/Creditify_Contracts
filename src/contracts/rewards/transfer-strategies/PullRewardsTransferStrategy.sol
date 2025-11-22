// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IPullRewardsTransferStrategy} from "../interfaces/IPullRewardsTransferStrategy.sol";
import {ITransferStrategyBase} from "../interfaces/ITransferStrategyBase.sol";
import {TransferStrategyBase} from "./TransferStrategyBase.sol";
import {SafeERC20} from "../../dependencies/openzeppelin/contracts/SafeERC20.sol";
import {IERC20} from "../../dependencies/openzeppelin/contracts/IERC20.sol";

contract PullRewardsTransferStrategy is TransferStrategyBase, IPullRewardsTransferStrategy {
    using SafeERC20 for IERC20;

    address internal immutable REWARDS_VAULT;

    constructor(address incentivesController, address rewardsAdmin, address rewardsVault)
        TransferStrategyBase(incentivesController, rewardsAdmin)
    {
        REWARDS_VAULT = rewardsVault;
    }

    function performTransfer(address to, address reward, uint256 amount)
        external
        override(TransferStrategyBase, ITransferStrategyBase)
        onlyIncentivesController
        returns (bool)
    {
        IERC20(reward).safeTransferFrom(REWARDS_VAULT, to, amount);

        return true;
    }

    function getRewardsVault() external view returns (address) {
        return REWARDS_VAULT;
    }
}
