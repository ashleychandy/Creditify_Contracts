// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {AccessControl} from "../../dependencies/openzeppelin/contracts/AccessControl.sol";
import {IPoolAddressesProvider} from "../../interfaces/IPoolAddressesProvider.sol";
import {IACLManager} from "../../interfaces/IACLManager.sol";
import {Errors} from "../libraries/helpers/Errors.sol";

contract ACLManager is AccessControl, IACLManager {
    bytes32 public constant override POOL_ADMIN_ROLE = keccak256("POOL_ADMIN");
    bytes32 public constant override EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN");
    bytes32 public constant override RISK_ADMIN_ROLE = keccak256("RISK_ADMIN");
    bytes32 public constant override ASSET_LISTING_ADMIN_ROLE = keccak256("ASSET_LISTING_ADMIN");

    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

    constructor(IPoolAddressesProvider provider) {
        ADDRESSES_PROVIDER = provider;
        address aclAdmin = provider.getACLAdmin();
        require(aclAdmin != address(0), Errors.AclAdminCannotBeZero());
        _setupRole(DEFAULT_ADMIN_ROLE, aclAdmin);
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRoleAdmin(role, adminRole);
    }

    function addPoolAdmin(address admin) external override {
        grantRole(POOL_ADMIN_ROLE, admin);
    }

    function removePoolAdmin(address admin) external override {
        revokeRole(POOL_ADMIN_ROLE, admin);
    }

    function isPoolAdmin(address admin) external view override returns (bool) {
        return hasRole(POOL_ADMIN_ROLE, admin);
    }

    function addEmergencyAdmin(address admin) external override {
        grantRole(EMERGENCY_ADMIN_ROLE, admin);
    }

    function removeEmergencyAdmin(address admin) external override {
        revokeRole(EMERGENCY_ADMIN_ROLE, admin);
    }

    function isEmergencyAdmin(address admin) external view override returns (bool) {
        return hasRole(EMERGENCY_ADMIN_ROLE, admin);
    }

    function addRiskAdmin(address admin) external override {
        grantRole(RISK_ADMIN_ROLE, admin);
    }

    function removeRiskAdmin(address admin) external override {
        revokeRole(RISK_ADMIN_ROLE, admin);
    }

    function isRiskAdmin(address admin) external view override returns (bool) {
        return hasRole(RISK_ADMIN_ROLE, admin);
    }

    function addAssetListingAdmin(address admin) external override {
        grantRole(ASSET_LISTING_ADMIN_ROLE, admin);
    }

    function removeAssetListingAdmin(address admin) external override {
        revokeRole(ASSET_LISTING_ADMIN_ROLE, admin);
    }

    function isAssetListingAdmin(address admin) external view override returns (bool) {
        return hasRole(ASSET_LISTING_ADMIN_ROLE, admin);
    }
}
