// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from '../../dependencies/openzeppelin/contracts/IERC20.sol';
import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {Errors} from '../libraries/helpers/Errors.sol';
import {IPool} from '../../interfaces/IPool.sol';
import {IInitializableDebtToken} from '../../interfaces/IInitializableDebtToken.sol';
import {IVariableDebtToken} from '../../interfaces/IVariableDebtToken.sol';
import {EIP712Base} from './base/EIP712Base.sol';
import {DebtTokenBase} from './base/DebtTokenBase.sol';
import {ScaledBalanceTokenBase} from './base/ScaledBalanceTokenBase.sol';
import {TokenMath} from '../libraries/helpers/TokenMath.sol';

abstract contract VariableDebtToken is DebtTokenBase, ScaledBalanceTokenBase, IVariableDebtToken {
  using TokenMath for uint256;
  using SafeCast for uint256;

  uint256[3] private __unusedGap;

  bytes32 private __DEPRECATED_AND_NEVER_TO_BE_REUSED;

  constructor(
    IPool pool,
    address rewardsController
  )
    DebtTokenBase()
    ScaledBalanceTokenBase(
      pool,
      'VARIABLE_DEBT_TOKEN_IMPL',
      'VARIABLE_DEBT_TOKEN_IMPL',
      0,
      rewardsController
    )
  {}

  function initialize(
    IPool initializingPool,
    address underlyingAsset,
    uint8 debtTokenDecimals,
    string memory debtTokenName,
    string memory debtTokenSymbol,
    bytes calldata params
  ) external virtual;

  function balanceOf(address user) public view virtual override returns (uint256) {
    return
      super.balanceOf(user).getVTokenBalance(
        POOL.getReserveNormalizedVariableDebt(_underlyingAsset)
      );
  }

  function mint(
    address user,
    address onBehalfOf,
    uint256 amount,
    uint256 scaledAmount,
    uint256 index
  ) external virtual override onlyPool returns (uint256) {
    uint256 scaledBalanceOfUser = super.balanceOf(user);

    if (user != onBehalfOf) {
      _decreaseBorrowAllowance(
        onBehalfOf,
        user,
        amount,
        (scaledBalanceOfUser + scaledAmount).getVTokenBalance(index) -
          scaledBalanceOfUser.getVTokenBalance(index)
      );
    }
    _mintScaled({
      caller: user,
      onBehalfOf: onBehalfOf,
      amountScaled: scaledAmount,
      index: index,
      getTokenBalance: TokenMath.getVTokenBalance
    });
    return scaledTotalSupply();
  }

  function burn(
    address from,
    uint256 scaledAmount,
    uint256 index
  ) external virtual override onlyPool returns (bool, uint256) {
    return (
      _burnScaled({
        user: from,
        target: address(0),
        amountScaled: scaledAmount,
        index: index,
        getTokenBalance: TokenMath.getVTokenBalance
      }),
      scaledTotalSupply()
    );
  }

  function totalSupply() public view virtual override returns (uint256) {
    return
      super.totalSupply().getVTokenBalance(POOL.getReserveNormalizedVariableDebt(_underlyingAsset));
  }

  function _EIP712BaseId() internal view override returns (string memory) {
    return name();
  }

  function transfer(address, uint256) external virtual override returns (bool) {
    revert Errors.OperationNotSupported();
  }

  function allowance(address, address) external view virtual override returns (uint256) {
    revert Errors.OperationNotSupported();
  }

  function approve(address, uint256) external virtual override returns (bool) {
    revert Errors.OperationNotSupported();
  }

  function transferFrom(address, address, uint256) external virtual override returns (bool) {
    revert Errors.OperationNotSupported();
  }

  function increaseAllowance(address, uint256) external virtual override returns (bool) {
    revert Errors.OperationNotSupported();
  }

  function decreaseAllowance(address, uint256) external virtual override returns (bool) {
    revert Errors.OperationNotSupported();
  }

  function UNDERLYING_ASSET_ADDRESS() external view override returns (address) {
    return _underlyingAsset;
  }
}
