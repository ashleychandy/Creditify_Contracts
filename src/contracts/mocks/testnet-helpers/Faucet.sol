// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from '../../dependencies/openzeppelin/contracts/Ownable.sol';
import {TestnetERC20} from './TestnetERC20.sol';
import {IFaucet} from './IFaucet.sol';

contract Faucet is IFaucet, Ownable {

  bool internal _permissioned;

  uint256 public constant MAX_MINT_AMOUNT = 10000;

  constructor(address owner, bool permissioned) {
    require(owner != address(0));
    transferOwnership(owner);
    _permissioned = permissioned;
  }

  modifier onlyOwnerIfPermissioned() {
    if (_permissioned == true) {
      require(owner() == _msgSender(), 'Ownable: caller is not the owner');
    }
    _;
  }

  function mint(
    address token,
    address to,
    uint256 amount
  ) external override onlyOwnerIfPermissioned returns (uint256) {
    require(
      amount <= MAX_MINT_AMOUNT * (10 ** TestnetERC20(token).decimals()),
      'Error: Mint limit transaction exceeded'
    );

    TestnetERC20(token).mint(to, amount);
    return amount;
  }

  function setPermissioned(bool permissioned) external override onlyOwner {
    _permissioned = permissioned;
  }

  function isPermissioned() external view override returns (bool) {
    return _permissioned;
  }

  function transferOwnershipOfChild(
    address[] calldata childContracts,
    address newOwner
  ) external override onlyOwner {
    for (uint256 i = 0; i < childContracts.length; i++) {
      Ownable(childContracts[i]).transferOwnership(newOwner);
    }
  }
}
