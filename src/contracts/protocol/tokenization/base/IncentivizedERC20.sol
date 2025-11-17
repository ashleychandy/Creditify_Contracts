// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Context} from '../../../dependencies/openzeppelin/contracts/Context.sol';
import {IERC20} from '../../../dependencies/openzeppelin/contracts/IERC20.sol';
import {IERC20Detailed} from '../../../dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {WadRayMath} from '../../libraries/math/WadRayMath.sol';
import {Errors} from '../../libraries/helpers/Errors.sol';
import {ICreditifyIncentivesController} from '../../../interfaces/ICreditifyIncentivesController.sol';
import {IPoolAddressesProvider} from '../../../interfaces/IPoolAddressesProvider.sol';
import {IPool} from '../../../interfaces/IPool.sol';
import {IACLManager} from '../../../interfaces/IACLManager.sol';

abstract contract IncentivizedERC20 is Context, IERC20Detailed {
  using WadRayMath for uint256;
  using SafeCast for uint256;

  error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

  modifier onlyPoolAdmin() {
    IACLManager aclManager = IACLManager(_addressesProvider.getACLManager());
    require(aclManager.isPoolAdmin(_msgSender()), Errors.CallerNotPoolAdmin());
    _;
  }

  modifier onlyPool() {
    require(_msgSender() == address(POOL), Errors.CallerMustBePool());
    _;
  }

  struct UserState {
    uint120 balance;
    uint128 additionalData;
  }

  mapping(address => UserState) internal _userState;

  mapping(address => mapping(address => uint256)) private _allowances;

  uint256 internal _totalSupply;
  string private _name;
  string private _symbol;
  uint8 private _decimals;

  ICreditifyIncentivesController internal __deprecated_incentivesController;
  IPoolAddressesProvider internal immutable _addressesProvider;
  IPool public immutable POOL;

  ICreditifyIncentivesController public immutable REWARDS_CONTROLLER;

  constructor(
    IPool pool,
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    address rewardsController
  ) {
    _addressesProvider = pool.ADDRESSES_PROVIDER();
    _name = name_;
    _symbol = symbol_;
    _decimals = decimals_;
    POOL = pool;
    REWARDS_CONTROLLER = ICreditifyIncentivesController(rewardsController);
  }

  function name() public view override returns (string memory) {
    return _name;
  }

  function symbol() external view override returns (string memory) {
    return _symbol;
  }

  function decimals() external view override returns (uint8) {
    return _decimals;
  }

  function totalSupply() public view virtual override returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) public view virtual override returns (uint256) {
    return _userState[account].balance;
  }

  function getIncentivesController()
    external
    view
    virtual
    returns (ICreditifyIncentivesController)
  {
    return REWARDS_CONTROLLER;
  }

  function transfer(address recipient, uint256 amount) external virtual override returns (bool) {
    uint120 castAmount = amount.toUint120();
    _transfer(_msgSender(), recipient, castAmount);
    return true;
  }

  function allowance(
    address owner,
    address spender
  ) external view virtual override returns (uint256) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount) external virtual override returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external virtual override returns (bool) {
    uint120 castAmount = amount.toUint120();
    _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - castAmount);
    _transfer(sender, recipient, castAmount);
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
    return true;
  }

  function decreaseAllowance(
    address spender,
    uint256 subtractedValue
  ) external virtual returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender] - subtractedValue);
    return true;
  }

  function _spendAllowance(
    address owner,
    address spender,
    uint256 amount,
    uint256 correctedAmount
  ) internal virtual {
    uint256 currentAllowance = _allowances[owner][spender];
    if (currentAllowance < amount) {
      revert ERC20InsufficientAllowance(spender, currentAllowance, amount);
    }

    uint256 consumption = currentAllowance >= correctedAmount ? correctedAmount : currentAllowance;
    _approve(owner, spender, currentAllowance - consumption);
  }

  function _transfer(address sender, address recipient, uint120 amount) internal virtual {
    uint120 oldSenderBalance = _userState[sender].balance;
    _userState[sender].balance = oldSenderBalance - amount;
    uint120 oldRecipientBalance = _userState[recipient].balance;
    _userState[recipient].balance = oldRecipientBalance + amount;

    if (address(REWARDS_CONTROLLER) != address(0)) {
      uint256 currentTotalSupply = _totalSupply;
      REWARDS_CONTROLLER.handleAction(sender, currentTotalSupply, oldSenderBalance);
      if (sender != recipient) {
        REWARDS_CONTROLLER.handleAction(recipient, currentTotalSupply, oldRecipientBalance);
      }
    }
  }

  function _approve(address owner, address spender, uint256 amount) internal virtual {
    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function _setName(string memory newName) internal {
    _name = newName;
  }

  function _setSymbol(string memory newSymbol) internal {
    _symbol = newSymbol;
  }

  function _setDecimals(uint8 newDecimals) internal {
    _decimals = newDecimals;
  }
}
