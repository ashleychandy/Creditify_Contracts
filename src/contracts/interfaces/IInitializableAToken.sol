// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICreditifyIncentivesController} from "./ICreditifyIncentivesController.sol";
import {IPool} from "./IPool.sol";

interface IInitializableAToken {
    event Initialized(
        address indexed underlyingAsset,
        address indexed pool,
        address treasury,
        address incentivesController,
        uint8 aTokenDecimals,
        string aTokenName,
        string aTokenSymbol,
        bytes params
    );

    function initialize(
        IPool pool,
        address underlyingAsset,
        uint8 aTokenDecimals,
        string calldata aTokenName,
        string calldata aTokenSymbol,
        bytes calldata params
    ) external;
}
