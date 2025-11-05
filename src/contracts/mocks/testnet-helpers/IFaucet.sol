// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFaucet {
  
  function mint(address token, address to, uint256 amount) external returns (uint256);

  function setPermissioned(bool value) external;

  function isPermissioned() external view returns (bool);

  function transferOwnershipOfChild(address[] calldata childContracts, address newOwner) external;
}
