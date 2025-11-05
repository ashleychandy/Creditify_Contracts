// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ITransferStrategyBase} from './ITransferStrategyBase.sol';

interface IPullRewardsTransferStrategy is ITransferStrategyBase {
  
  function getRewardsVault() external view returns (address);
}
