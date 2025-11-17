// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Ownable} from '../dependencies/openzeppelin/contracts/Ownable.sol';
import {IERC20} from '../dependencies/openzeppelin/contracts/IERC20.sol';
import {SafeERC20} from '../dependencies/openzeppelin/contracts/SafeERC20.sol';
import {IWETH} from './interfaces/IWETH.sol';
import {IPool} from '../interfaces/IPool.sol';
import {IAToken} from '../interfaces/IAToken.sol';
import {ReserveConfiguration} from '../protocol/libraries/configuration/ReserveConfiguration.sol';
import {UserConfiguration} from '../protocol/libraries/configuration/UserConfiguration.sol';
import {DataTypes} from '../protocol/libraries/types/DataTypes.sol';
import {IWrappedTokenGatewayV3} from './interfaces/IWrappedTokenGatewayV3.sol';

contract WrappedTokenGatewayV3 is IWrappedTokenGatewayV3, Ownable {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using SafeERC20 for IERC20;

  IWETH public immutable WETH;
  IPool public immutable POOL;

  constructor(address weth, address owner, IPool pool) {
    WETH = IWETH(weth);
    POOL = pool;
    transferOwnership(owner);
    IWETH(weth).approve(address(pool), type(uint256).max);
  }

  function depositETH(address, address onBehalfOf, uint16 referralCode) external payable override {
    WETH.deposit{value: msg.value}();
    POOL.deposit(address(WETH), msg.value, onBehalfOf, referralCode);
  }

  function withdrawETH(address, uint256 amount, address to) external override {
    IAToken aWETH = IAToken(POOL.getReserveAToken(address(WETH)));
    uint256 userBalance = aWETH.balanceOf(msg.sender);
    uint256 amountToWithdraw = amount;

    if (amount == type(uint256).max) {
      amountToWithdraw = userBalance;
    }
    aWETH.transferFrom(msg.sender, address(this), amountToWithdraw);
    POOL.withdraw(address(WETH), amountToWithdraw, address(this));
    WETH.withdraw(amountToWithdraw);
    _safeTransferETH(to, amountToWithdraw);
  }

  function repayETH(address, uint256 amount, address onBehalfOf) external payable override {
    uint256 paybackAmount = IERC20(POOL.getReserveVariableDebtToken(address(WETH))).balanceOf(
      onBehalfOf
    );

    if (amount < paybackAmount) {
      paybackAmount = amount;
    }
    require(msg.value >= paybackAmount, 'msg.value is less than repayment amount');
    WETH.deposit{value: paybackAmount}();
    POOL.repay(
      address(WETH),
      paybackAmount,
      uint256(DataTypes.InterestRateMode.VARIABLE),
      onBehalfOf
    );

    if (msg.value > paybackAmount) _safeTransferETH(msg.sender, msg.value - paybackAmount);
  }

  function borrowETH(address, uint256 amount, uint16 referralCode) external override {
    POOL.borrow(
      address(WETH),
      amount,
      uint256(DataTypes.InterestRateMode.VARIABLE),
      referralCode,
      msg.sender
    );
    WETH.withdraw(amount);
    _safeTransferETH(msg.sender, amount);
  }

  function withdrawETHWithPermit(
    address,
    uint256 amount,
    address to,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external override {
    IAToken aWETH = IAToken(POOL.getReserveAToken(address(WETH)));
    uint256 userBalance = aWETH.balanceOf(msg.sender);
    uint256 amountToWithdraw = amount;

    if (amount == type(uint256).max) {
      amountToWithdraw = userBalance;
    }

    try
      aWETH.permit(msg.sender, address(this), amount, deadline, permitV, permitR, permitS)
    {} catch {}
    aWETH.transferFrom(msg.sender, address(this), amountToWithdraw);
    POOL.withdraw(address(WETH), amountToWithdraw, address(this));
    WETH.withdraw(amountToWithdraw);
    _safeTransferETH(to, amountToWithdraw);
  }

  function _safeTransferETH(address to, uint256 value) internal {
    (bool success, ) = to.call{value: value}(new bytes(0));
    require(success, 'ETH_TRANSFER_FAILED');
  }

  function emergencyTokenTransfer(address token, address to, uint256 amount) external onlyOwner {
    IERC20(token).safeTransfer(to, amount);
  }

  function emergencyEtherTransfer(address to, uint256 amount) external onlyOwner {
    _safeTransferETH(to, amount);
  }

  function getWETHAddress() external view returns (address) {
    return address(WETH);
  }

  receive() external payable {
    require(msg.sender == address(WETH), 'Receive not allowed');
  }

  fallback() external payable {
    revert('Fallback not allowed');
  }
}
