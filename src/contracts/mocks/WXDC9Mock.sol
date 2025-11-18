// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WXDC9} from '../dependencies/wxdc/WXDC9.sol';
import {Ownable} from '../dependencies/openzeppelin/contracts/Ownable.sol';

contract WXDC9Mock is WXDC9, Ownable {
  constructor(string memory mockName, string memory mockSymbol, address owner) {
    name = mockName;
    symbol = mockSymbol;

    transferOwnership(owner);
  }

  function mint(address account, uint256 value) public onlyOwner returns (bool) {
    balanceOf[account] += value;
    emit Transfer(address(0), account, value);
    return true;
  }
}
