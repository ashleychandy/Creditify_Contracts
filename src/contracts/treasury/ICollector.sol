// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface ICollector {
    struct Stream {
        uint256 deposit;
        uint256 ratePerSecond;
        uint256 remainingBalance;
        uint256 startTime;
        uint256 stopTime;
        address recipient;
        address sender;
        address tokenAddress;
        bool isEntity;
    }

    error BalanceExceeded();

    error DepositSmallerTimeDelta();

    error DepositNotMultipleTimeDelta();

    error InvalidRecipient();

    error InvalidStartTime();

    error InvalidStopTime();

    error InvalidZeroAddress();

    error InvalidZeroAmount();

    error OnlyFundsAdmin();

    error OnlyFundsAdminOrRecipient();

    error StreamDoesNotExist();

    event CreateStream(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        uint256 deposit,
        address tokenAddress,
        uint256 startTime,
        uint256 stopTime
    );

    event WithdrawFromStream(uint256 indexed streamId, address indexed recipient, uint256 amount);

    event CancelStream(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        uint256 senderBalance,
        uint256 recipientBalance
    );

    function FUNDS_ADMIN_ROLE() external view returns (bytes32);

    function XDC_MOCK_ADDRESS() external pure returns (address);

    function isFundsAdmin(address admin) external view returns (bool);

    function balanceOf(uint256 streamId, address who) external view returns (uint256 balance);

    function approve(IERC20 token, address recipient, uint256 amount) external;

    function transfer(IERC20 token, address recipient, uint256 amount) external;

    function createStream(address recipient, uint256 deposit, address tokenAddress, uint256 startTime, uint256 stopTime)
        external
        returns (uint256 streamId);

    function getStream(uint256 streamId)
        external
        view
        returns (
            address sender,
            address recipient,
            uint256 deposit,
            address tokenAddress,
            uint256 startTime,
            uint256 stopTime,
            uint256 remainingBalance,
            uint256 ratePerSecond
        );

    function withdrawFromStream(uint256 streamId, uint256 amount) external returns (bool);

    function cancelStream(uint256 streamId) external returns (bool);

    function getNextStreamId() external view returns (uint256);
}
