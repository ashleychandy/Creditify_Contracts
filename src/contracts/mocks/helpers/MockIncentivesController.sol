// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ICreditifyIncentivesController} from '../../interfaces/ICreditifyIncentivesController.sol';

contract MockIncentivesController is ICreditifyIncentivesController {
  function handleAction(address, uint256, uint256) external override {}
}
