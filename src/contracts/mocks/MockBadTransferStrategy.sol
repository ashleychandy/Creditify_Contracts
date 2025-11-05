// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ITransferStrategyBase} from '../rewards/interfaces/ITransferStrategyBase.sol';
import {TransferStrategyBase} from '../rewards/transfer-strategies/TransferStrategyBase.sol';
import {SafeERC20} from '../dependencies/openzeppelin/contracts/SafeERC20.sol';
import {IERC20} from '../dependencies/openzeppelin/contracts/IERC20.sol';

contract MockBadTransferStrategy is TransferStrategyBase {
  using SafeERC20 for IERC20;

  uint256 ignoreWarning;

  constructor(
    address incentivesController,
    address rewardsAdmin
  ) TransferStrategyBase(incentivesController, rewardsAdmin) {}

  function performTransfer(
    address,
    address,
    uint256
  ) external override onlyIncentivesController returns (bool) {
    ignoreWarning = 1;
    return false;
  }
}
