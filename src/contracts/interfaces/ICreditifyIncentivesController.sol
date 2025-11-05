// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICreditifyIncentivesController {
  
  function handleAction(address user, uint256 totalSupply, uint256 userBalance) external;
}
