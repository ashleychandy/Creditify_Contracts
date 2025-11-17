// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC4626} from 'openzeppelin-contracts/contracts/interfaces/IERC4626.sol';
import {IERC20Permit} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol';
import {IERC4626StataToken} from './IERC4626StataToken.sol';
import {IERC20CreditifyLM} from './IERC20CreditifyLM.sol';

interface IStataTokenV2 is IERC4626, IERC20Permit, IERC4626StataToken, IERC20CreditifyLM {
  function canPause(address actor) external view returns (bool);

  function setPaused(bool paused) external;
}
