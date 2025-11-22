// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControlUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {ICollector} from "./ICollector.sol";

contract Collector is AccessControlUpgradeable, ReentrancyGuardUpgradeable, ICollector {
    using SafeERC20 for IERC20;
    using Address for address payable;

    address public constant XDC_MOCK_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    bytes32 public constant FUNDS_ADMIN_ROLE = "FUNDS_ADMIN";

    uint256[53] private ______gap;

    uint256 private _nextStreamId;

    mapping(uint256 => Stream) private _streams;

    modifier onlyFundsAdmin() {
        if (_onlyFundsAdmin() == false) {
            revert OnlyFundsAdmin();
        }
        _;
    }

    modifier onlyAdminOrRecipient(uint256 streamId) {
        if (_onlyFundsAdmin() == false && msg.sender != _streams[streamId].recipient) {
            revert OnlyFundsAdminOrRecipient();
        }
        _;
    }

    modifier streamExists(uint256 streamId) {
        if (!_streams[streamId].isEntity) revert StreamDoesNotExist();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 nextStreamId, address admin) external virtual initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(FUNDS_ADMIN_ROLE, admin);
        if (nextStreamId != 0) {
            _nextStreamId = nextStreamId;
        }
    }

    function isFundsAdmin(address admin) external view returns (bool) {
        return hasRole(FUNDS_ADMIN_ROLE, admin);
    }

    function getNextStreamId() external view returns (uint256) {
        return _nextStreamId;
    }

    function getStream(uint256 streamId)
        external
        view
        streamExists(streamId)
        returns (
            address sender,
            address recipient,
            uint256 deposit,
            address tokenAddress,
            uint256 startTime,
            uint256 stopTime,
            uint256 remainingBalance,
            uint256 ratePerSecond
        )
    {
        sender = _streams[streamId].sender;
        recipient = _streams[streamId].recipient;
        deposit = _streams[streamId].deposit;
        tokenAddress = _streams[streamId].tokenAddress;
        startTime = _streams[streamId].startTime;
        stopTime = _streams[streamId].stopTime;
        remainingBalance = _streams[streamId].remainingBalance;
        ratePerSecond = _streams[streamId].ratePerSecond;
    }

    function deltaOf(uint256 streamId) public view streamExists(streamId) returns (uint256 delta) {
        Stream memory stream = _streams[streamId];
        if (block.timestamp <= stream.startTime) return 0;
        if (block.timestamp < stream.stopTime) return block.timestamp - stream.startTime;
        return stream.stopTime - stream.startTime;
    }

    struct BalanceOfLocalVars {
        uint256 recipientBalance;
        uint256 withdrawalAmount;
        uint256 senderBalance;
    }

    function balanceOf(uint256 streamId, address who) public view streamExists(streamId) returns (uint256 balance) {
        Stream memory stream = _streams[streamId];
        BalanceOfLocalVars memory vars;

        uint256 delta = deltaOf(streamId);
        vars.recipientBalance = delta * stream.ratePerSecond;

        if (stream.deposit > stream.remainingBalance) {
            vars.withdrawalAmount = stream.deposit - stream.remainingBalance;
            vars.recipientBalance = vars.recipientBalance - vars.withdrawalAmount;
        }

        if (who == stream.recipient) return vars.recipientBalance;
        if (who == stream.sender) {
            vars.senderBalance = stream.remainingBalance - vars.recipientBalance;
            return vars.senderBalance;
        }
        return 0;
    }

    function approve(IERC20 token, address recipient, uint256 amount) external onlyFundsAdmin {
        token.forceApprove(recipient, amount);
    }

    function transfer(IERC20 token, address recipient, uint256 amount) external onlyFundsAdmin {
        if (recipient == address(0)) revert InvalidZeroAddress();

        if (address(token) == XDC_MOCK_ADDRESS) {
            payable(recipient).sendValue(amount);
        } else {
            token.safeTransfer(recipient, amount);
        }
    }

    function _onlyFundsAdmin() internal view returns (bool) {
        return hasRole(FUNDS_ADMIN_ROLE, msg.sender);
    }

    struct CreateStreamLocalVars {
        uint256 duration;
        uint256 ratePerSecond;
    }

    function createStream(address recipient, uint256 deposit, address tokenAddress, uint256 startTime, uint256 stopTime)
        external
        onlyFundsAdmin
        returns (uint256)
    {
        if (recipient == address(0)) revert InvalidZeroAddress();
        if (recipient == address(this)) revert InvalidRecipient();
        if (recipient == msg.sender) revert InvalidRecipient();
        if (deposit == 0) revert InvalidZeroAmount();
        if (startTime < block.timestamp) revert InvalidStartTime();
        if (stopTime <= startTime) revert InvalidStopTime();

        CreateStreamLocalVars memory vars;
        vars.duration = stopTime - startTime;

        if (deposit < vars.duration) revert DepositSmallerTimeDelta();

        if (deposit % vars.duration > 0) revert DepositNotMultipleTimeDelta();

        vars.ratePerSecond = deposit / vars.duration;

        uint256 streamId = _nextStreamId;
        _streams[streamId] = Stream({
            remainingBalance: deposit,
            deposit: deposit,
            isEntity: true,
            ratePerSecond: vars.ratePerSecond,
            recipient: recipient,
            sender: address(this),
            startTime: startTime,
            stopTime: stopTime,
            tokenAddress: tokenAddress
        });

        _nextStreamId++;

        emit CreateStream(streamId, address(this), recipient, deposit, tokenAddress, startTime, stopTime);
        return streamId;
    }

    function withdrawFromStream(uint256 streamId, uint256 amount)
        external
        nonReentrant
        streamExists(streamId)
        onlyAdminOrRecipient(streamId)
        returns (bool)
    {
        if (amount == 0) revert InvalidZeroAmount();
        Stream memory stream = _streams[streamId];

        uint256 balance = balanceOf(streamId, stream.recipient);
        if (balance < amount) revert BalanceExceeded();

        _streams[streamId].remainingBalance = stream.remainingBalance - amount;

        if (_streams[streamId].remainingBalance == 0) delete _streams[streamId];

        IERC20(stream.tokenAddress).safeTransfer(stream.recipient, amount);
        emit WithdrawFromStream(streamId, stream.recipient, amount);
        return true;
    }

    function cancelStream(uint256 streamId)
        external
        nonReentrant
        streamExists(streamId)
        onlyAdminOrRecipient(streamId)
        returns (bool)
    {
        Stream memory stream = _streams[streamId];
        uint256 senderBalance = balanceOf(streamId, stream.sender);
        uint256 recipientBalance = balanceOf(streamId, stream.recipient);

        delete _streams[streamId];

        IERC20 token = IERC20(stream.tokenAddress);
        if (recipientBalance > 0) token.safeTransfer(stream.recipient, recipientBalance);

        emit CancelStream(streamId, stream.sender, stream.recipient, senderBalance, recipientBalance);
        return true;
    }

    receive() external payable {}
}
