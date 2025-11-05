// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ICreditifyIncentivesController} from '../../../interfaces/ICreditifyIncentivesController.sol';
import {IPool} from '../../../interfaces/IPool.sol';
import {IncentivizedERC20} from './IncentivizedERC20.sol';

abstract contract MintableIncentivizedERC20 is IncentivizedERC20 {
  
  constructor(
    IPool pool,
    string memory name,
    string memory symbol,
    uint8 decimals,
    address rewardsController
  ) IncentivizedERC20(pool, name, symbol, decimals, rewardsController) {
    
  }

  function _mint(address account, uint120 amount) internal virtual {
    uint256 oldTotalSupply = _totalSupply;
    _totalSupply = oldTotalSupply + amount;

    uint120 oldAccountBalance = _userState[account].balance;
    _userState[account].balance = oldAccountBalance + amount;

    if (address(REWARDS_CONTROLLER) != address(0)) {
      REWARDS_CONTROLLER.handleAction(account, oldTotalSupply, oldAccountBalance);
    }
  }

  function _burn(address account, uint120 amount) internal virtual {
    uint256 oldTotalSupply = _totalSupply;
    _totalSupply = oldTotalSupply - amount;

    uint120 oldAccountBalance = _userState[account].balance;
    _userState[account].balance = oldAccountBalance - amount;

    if (address(REWARDS_CONTROLLER) != address(0)) {
      REWARDS_CONTROLLER.handleAction(account, oldTotalSupply, oldAccountBalance);
    }
  }
}
