// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {WXDC9} from '../../dependencies/wxdc/WXDC9.sol';

contract WXDC9Mocked is WXDC9 {
  function mint(uint256 value) public returns (bool) {
    balanceOf[msg.sender] += value;
    emit Transfer(address(0), msg.sender, value);
    return true;
  }

  function mint(address account, uint256 value) public returns (bool) {
    balanceOf[account] += value;
    emit Transfer(address(0), account, value);
    return true;
  }
}
