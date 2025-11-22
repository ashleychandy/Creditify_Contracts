// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {VersionedInitializable} from "../misc/creditify-upgradeability/VersionedInitializable.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {IScaledBalanceToken} from "../interfaces/IScaledBalanceToken.sol";
import {RewardsDistributor} from "./RewardsDistributor.sol";
import {IRewardsController} from "./interfaces/IRewardsController.sol";
import {ITransferStrategyBase} from "./interfaces/ITransferStrategyBase.sol";
import {RewardsDataTypes} from "./libraries/RewardsDataTypes.sol";
import {AggregatorInterface} from "../dependencies/chainlink/AggregatorInterface.sol";

contract RewardsController is RewardsDistributor, VersionedInitializable, IRewardsController {
    using SafeCast for uint256;

    uint256 public constant REVISION = 1;

    mapping(address => address) internal _authorizedClaimers;

    mapping(address => ITransferStrategyBase) internal _transferStrategy;

    mapping(address => AggregatorInterface) internal _rewardOracle;

    modifier onlyAuthorizedClaimers(address claimer, address user) {
        require(_authorizedClaimers[user] == claimer, "CLAIMER_UNAUTHORIZED");
        _;
    }

    constructor(address emissionManager) RewardsDistributor(emissionManager) {}

    function initialize(address) external initializer {}

    function getClaimer(address user) external view override returns (address) {
        return _authorizedClaimers[user];
    }

    function getRevision() internal pure override returns (uint256) {
        return REVISION;
    }

    function getRewardOracle(address reward) external view override returns (address) {
        return address(_rewardOracle[reward]);
    }

    function getTransferStrategy(address reward) external view override returns (address) {
        return address(_transferStrategy[reward]);
    }

    function configureAssets(RewardsDataTypes.RewardsConfigInput[] memory config)
        external
        override
        onlyEmissionManager
    {
        for (uint256 i = 0; i < config.length; i++) {
            config[i].totalSupply = IScaledBalanceToken(config[i].asset).scaledTotalSupply();

            _installTransferStrategy(config[i].reward, config[i].transferStrategy);

            _setRewardOracle(config[i].reward, config[i].rewardOracle);
        }
        _configureAssets(config);
    }

    function setTransferStrategy(address reward, ITransferStrategyBase transferStrategy) external onlyEmissionManager {
        _installTransferStrategy(reward, transferStrategy);
    }

    function setRewardOracle(address reward, AggregatorInterface rewardOracle) external onlyEmissionManager {
        _setRewardOracle(reward, rewardOracle);
    }

    function handleAction(address user, uint256 totalSupply, uint256 userBalance) external override {
        _updateData(msg.sender, user, userBalance, totalSupply);
    }

    function claimRewards(address[] calldata assets, uint256 amount, address to, address reward)
        external
        override
        returns (uint256)
    {
        require(to != address(0), "INVALID_TO_ADDRESS");
        return _claimRewards(assets, amount, msg.sender, msg.sender, to, reward);
    }

    function claimRewardsOnBehalf(address[] calldata assets, uint256 amount, address user, address to, address reward)
        external
        override
        onlyAuthorizedClaimers(msg.sender, user)
        returns (uint256)
    {
        require(user != address(0), "INVALID_USER_ADDRESS");
        require(to != address(0), "INVALID_TO_ADDRESS");
        return _claimRewards(assets, amount, msg.sender, user, to, reward);
    }

    function claimRewardsToSelf(address[] calldata assets, uint256 amount, address reward)
        external
        override
        returns (uint256)
    {
        return _claimRewards(assets, amount, msg.sender, msg.sender, msg.sender, reward);
    }

    function claimAllRewards(address[] calldata assets, address to)
        external
        override
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        require(to != address(0), "INVALID_TO_ADDRESS");
        return _claimAllRewards(assets, msg.sender, msg.sender, to);
    }

    function claimAllRewardsOnBehalf(address[] calldata assets, address user, address to)
        external
        override
        onlyAuthorizedClaimers(msg.sender, user)
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        require(user != address(0), "INVALID_USER_ADDRESS");
        require(to != address(0), "INVALID_TO_ADDRESS");
        return _claimAllRewards(assets, msg.sender, user, to);
    }

    function claimAllRewardsToSelf(address[] calldata assets)
        external
        override
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        return _claimAllRewards(assets, msg.sender, msg.sender, msg.sender);
    }

    function setClaimer(address user, address caller) external override onlyEmissionManager {
        _authorizedClaimers[user] = caller;
        emit ClaimerSet(user, caller);
    }

    function _getUserAssetBalances(address[] calldata assets, address user)
        internal
        view
        override
        returns (RewardsDataTypes.UserAssetBalance[] memory userAssetBalances)
    {
        userAssetBalances = new RewardsDataTypes.UserAssetBalance[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            userAssetBalances[i].asset = assets[i];
            (userAssetBalances[i].userBalance, userAssetBalances[i].totalSupply) =
                IScaledBalanceToken(assets[i]).getScaledUserBalanceAndSupply(user);
        }
        return userAssetBalances;
    }

    function _claimRewards(
        address[] calldata assets,
        uint256 amount,
        address claimer,
        address user,
        address to,
        address reward
    ) internal returns (uint256) {
        if (amount == 0) {
            return 0;
        }
        uint256 totalRewards;

        _updateDataMultiple(user, _getUserAssetBalances(assets, user));
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            totalRewards += _assets[asset].rewards[reward].usersData[user].accrued;

            if (totalRewards <= amount) {
                _assets[asset].rewards[reward].usersData[user].accrued = 0;
            } else {
                uint256 difference = totalRewards - amount;
                totalRewards -= difference;
                _assets[asset].rewards[reward].usersData[user].accrued = difference.toUint128();
                break;
            }
        }

        if (totalRewards == 0) {
            return 0;
        }

        _transferRewards(to, reward, totalRewards);
        emit RewardsClaimed(user, reward, to, claimer, totalRewards);

        return totalRewards;
    }

    function _claimAllRewards(address[] calldata assets, address claimer, address user, address to)
        internal
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        uint256 rewardsListLength = _rewardsList.length;
        rewardsList = new address[](rewardsListLength);
        claimedAmounts = new uint256[](rewardsListLength);

        _updateDataMultiple(user, _getUserAssetBalances(assets, user));

        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            for (uint256 j = 0; j < rewardsListLength; j++) {
                if (rewardsList[j] == address(0)) {
                    rewardsList[j] = _rewardsList[j];
                }
                uint256 rewardAmount = _assets[asset].rewards[rewardsList[j]].usersData[user].accrued;
                if (rewardAmount != 0) {
                    claimedAmounts[j] += rewardAmount;
                    _assets[asset].rewards[rewardsList[j]].usersData[user].accrued = 0;
                }
            }
        }
        for (uint256 i = 0; i < rewardsListLength; i++) {
            _transferRewards(to, rewardsList[i], claimedAmounts[i]);
            emit RewardsClaimed(user, rewardsList[i], to, claimer, claimedAmounts[i]);
        }
        return (rewardsList, claimedAmounts);
    }

    function _transferRewards(address to, address reward, uint256 amount) internal {
        ITransferStrategyBase transferStrategy = _transferStrategy[reward];

        bool success = transferStrategy.performTransfer(to, reward, amount);

        require(success == true, "TRANSFER_ERROR");
    }

    function _isContract(address account) internal view returns (bool) {
        uint256 size;

        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function _installTransferStrategy(address reward, ITransferStrategyBase transferStrategy) internal {
        require(address(transferStrategy) != address(0), "STRATEGY_CAN_NOT_BE_ZERO");
        require(_isContract(address(transferStrategy)) == true, "STRATEGY_MUST_BE_CONTRACT");

        _transferStrategy[reward] = transferStrategy;

        emit TransferStrategyInstalled(reward, address(transferStrategy));
    }

    function _setRewardOracle(address reward, AggregatorInterface rewardOracle) internal {
        require(rewardOracle.latestAnswer() > 0, "ORACLE_MUST_RETURN_PRICE");
        _rewardOracle[reward] = rewardOracle;
        emit RewardOracleUpdated(reward, address(rewardOracle));
    }
}
