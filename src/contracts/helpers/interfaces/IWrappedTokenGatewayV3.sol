// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import {IWXDC} from '../interfaces/IWXDC.sol';
import {IPool} from '../../interfaces/IPool.sol';

interface IWrappedTokenGatewayV3 {
  function WXDC() external view returns (IWXDC);

  function POOL() external view returns (IPool);

  function depositXDC(address pool, address onBehalfOf, uint16 referralCode) external payable;

  function withdrawXDC(address pool, uint256 amount, address onBehalfOf) external;

  function repayXDC(address pool, uint256 amount, address onBehalfOf) external payable;

  function borrowXDC(address pool, uint256 amount, uint16 referralCode) external;

  function withdrawXDCWithPermit(
    address pool,
    uint256 amount,
    address to,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external;
}
