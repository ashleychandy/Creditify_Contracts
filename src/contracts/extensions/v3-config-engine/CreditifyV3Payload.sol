// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {WadRayMath} from "../../protocol/libraries/math/WadRayMath.sol";
import {ICreditifyV3ConfigEngine as IEngine} from "./ICreditifyV3ConfigEngine.sol";
import {EngineFlags} from "./EngineFlags.sol";

abstract contract CreditifyV3Payload {
    using Address for address;

    IEngine public immutable CONFIG_ENGINE;

    constructor(IEngine engine) {
        CONFIG_ENGINE = engine;
    }

    function _preExecute() internal virtual {}

    function _postExecute() internal virtual {}

    function execute() external {
        _preExecute();

        IEngine.Listing[] memory listings = newListings();
        IEngine.ListingWithCustomImpl[] memory listingsCustom = newListingsCustom();
        IEngine.CollateralUpdate[] memory collaterals = collateralsUpdates();
        IEngine.BorrowUpdate[] memory borrows = borrowsUpdates();
        IEngine.RateStrategyUpdate[] memory rates = rateStrategiesUpdates();
        IEngine.PriceFeedUpdate[] memory priceFeeds = priceFeedsUpdates();
        IEngine.CapsUpdate[] memory caps = capsUpdates();

        if (listings.length != 0) {
            address(CONFIG_ENGINE).functionDelegateCall(
                abi.encodeWithSelector(CONFIG_ENGINE.listAssets.selector, getPoolContext(), listings)
            );
        }

        if (listingsCustom.length != 0) {
            address(CONFIG_ENGINE).functionDelegateCall(
                abi.encodeWithSelector(CONFIG_ENGINE.listAssetsCustom.selector, getPoolContext(), listingsCustom)
            );
        }

        if (borrows.length != 0) {
            address(CONFIG_ENGINE).functionDelegateCall(
                abi.encodeWithSelector(CONFIG_ENGINE.updateBorrowSide.selector, borrows)
            );
        }

        if (collaterals.length != 0) {
            address(CONFIG_ENGINE).functionDelegateCall(
                abi.encodeWithSelector(CONFIG_ENGINE.updateCollateralSide.selector, collaterals)
            );
        }

        if (rates.length != 0) {
            address(CONFIG_ENGINE).functionDelegateCall(
                abi.encodeWithSelector(CONFIG_ENGINE.updateRateStrategies.selector, rates)
            );
        }

        if (priceFeeds.length != 0) {
            address(CONFIG_ENGINE).functionDelegateCall(
                abi.encodeWithSelector(CONFIG_ENGINE.updatePriceFeeds.selector, priceFeeds)
            );
        }

        if (caps.length != 0) {
            address(CONFIG_ENGINE).functionDelegateCall(abi.encodeWithSelector(CONFIG_ENGINE.updateCaps.selector, caps));
        }

        _postExecute();
    }

    function _bpsToRay(uint256 amount) internal pure returns (uint256) {
        return (amount * WadRayMath.RAY) / 10_000;
    }

    function newListings() public view virtual returns (IEngine.Listing[] memory) {}

    function newListingsCustom() public view virtual returns (IEngine.ListingWithCustomImpl[] memory) {}

    function capsUpdates() public view virtual returns (IEngine.CapsUpdate[] memory) {}

    function collateralsUpdates() public view virtual returns (IEngine.CollateralUpdate[] memory) {}

    function borrowsUpdates() public view virtual returns (IEngine.BorrowUpdate[] memory) {}

    function priceFeedsUpdates() public view virtual returns (IEngine.PriceFeedUpdate[] memory) {}

    function rateStrategiesUpdates() public view virtual returns (IEngine.RateStrategyUpdate[] memory) {}

    function getPoolContext() public view virtual returns (IEngine.PoolContext memory);
}
