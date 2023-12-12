// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { VersionedInitializable } from "@nstbl-loan-manager/contracts/upgradeable/VersionedInitializable.sol";
import { IStakePool, IERC20Helper, ILoanManager, IACLManager, StakePoolStorage } from "./StakePoolStorage.sol";

contract NSTBLStakePool is IStakePool, StakePoolStorage, VersionedInitializable {
    using SafeERC20 for IERC20Helper;

    uint256 private _locked;

    /*//////////////////////////////////////////////////////////////
    Modifiers
    //////////////////////////////////////////////////////////////*/

    modifier nonReentrant() {
        require(_locked == 1, "P:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    modifier onlyAdmin() {
        require(msg.sender == IACLManager(aclManager).admin(), "SP: unAuth Admin");
        _;
    }

    modifier authorizedCaller() {
        require(IACLManager(aclManager).authorizedCallersStakePool(msg.sender), "SP: unAuth Hub");
        _;
    }

    /*//////////////////////////////////////////////////////////////
    Constructor
    //////////////////////////////////////////////////////////////*/

    constructor() {
        usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    }

    /*//////////////////////////////////////////////////////////////
    Externals
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IStakePool
     */
    function initialize(address aclManager_, address nstbl_, address loanManager_, address atvl_)
        external
        initializer
    {
        _zeroAddressCheck(aclManager_);
        _zeroAddressCheck(nstbl_);
        _zeroAddressCheck(loanManager_);
        _zeroAddressCheck(atvl_);
        aclManager = aclManager_;
        nstbl = nstbl_;
        loanManager = loanManager_;
        atvl = atvl_;
        _locked = 1;
        poolProduct = 1e18;
        emit StakePoolInitialized(REVISION, aclManager, nstbl, loanManager, atvl);
    }

    /**
     * @inheritdoc IStakePool
     */
    function setupStakePool(
        uint16[3] memory trancheBaseFee_,
        uint16[3] memory earlyUnstakeFee_,
        uint8[3] memory stakeTimePeriods_
    ) external onlyAdmin {
        require(
            earlyUnstakeFee_[0] < 501 && earlyUnstakeFee_[1] < 501 && earlyUnstakeFee_[2] < 501, "SP: Cannot Exceed 5%"
        );
        trancheBaseFee1 = trancheBaseFee_[0];
        trancheBaseFee2 = trancheBaseFee_[1];
        trancheBaseFee3 = trancheBaseFee_[2];
        earlyUnstakeFee1 = earlyUnstakeFee_[0];
        earlyUnstakeFee2 = earlyUnstakeFee_[1];
        earlyUnstakeFee3 = earlyUnstakeFee_[2];
        trancheStakeTimePeriod[0] = uint64(stakeTimePeriods_[0]);
        trancheStakeTimePeriod[1] = uint64(stakeTimePeriods_[1]);
        trancheStakeTimePeriod[2] = uint64(stakeTimePeriods_[2]);
        emit TrancheBaseFeeUpdated(trancheBaseFee1, trancheBaseFee2, trancheBaseFee3);
        emit TrancheEarlyUnstakeFeeUpdated(earlyUnstakeFee1, earlyUnstakeFee2, earlyUnstakeFee2);
        emit TrancheStakeTimePeriodUpdated(
            trancheStakeTimePeriod[0], trancheStakeTimePeriod[1], trancheStakeTimePeriod[2]
        );
    }

    /**
     * @inheritdoc IStakePool
     */
    function setATVL(address atvl_) external onlyAdmin {
        _zeroAddressCheck(atvl_);
        atvl = atvl_;
        emit ATVLUpdated(atvl);
    }

    /**
     * @inheritdoc IStakePool
     */
    function stake(address user_, uint256 stakeAmount_, uint8 trancheId_) external authorizedCaller nonReentrant {
        require(stakeAmount_ > 0, "SP: ZERO_AMOUNT");
        require(trancheId_ < 3, "SP: INVALID_TRANCHE");
        IERC20Helper(nstbl).safeTransferFrom(msg.sender, address(this), stakeAmount_);
        StakerInfo storage staker = stakerInfo[trancheId_][user_];

        (uint256 poolYield, uint256 atvlYield) = _updatePool();
        uint256 unstakeFee;
        if (staker.amount > 0 && staker.epochId == poolEpochId) {
            uint256 tokensAvailable = (staker.amount * poolProduct) / staker.poolDebt;
            unstakeFee = getUnstakeFee(trancheId_, staker.stakeTimeStamp) * tokensAvailable / 10_000;
            staker.amount = tokensAvailable - unstakeFee + stakeAmount_;
            poolBalance -= unstakeFee;
        } else {
            staker.amount = stakeAmount_;
            staker.epochId = poolEpochId;
        }
        staker.poolDebt = poolProduct;
        staker.stakeTimeStamp = block.timestamp;
        poolBalance += stakeAmount_;

        IERC20Helper(nstbl).mint(address(this), poolYield);
        IERC20Helper(nstbl).mint(atvl, atvlYield);
        IERC20Helper(nstbl).safeTransfer(atvl, unstakeFee);

        emit Stake(user_, staker.amount, staker.poolDebt, staker.epochId);
    }

    /**
     * @inheritdoc IStakePool
     */
    function unstake(address user_, uint8 trancheId_, bool depeg_, address destAddress_)
        external
        authorizedCaller
        nonReentrant
        returns (uint256 tokensReceived_)
    {
        StakerInfo storage staker = stakerInfo[trancheId_][user_];
        require(staker.amount > 0, "SP: NO STAKE");
        (uint256 poolYield, uint256 atvlYield) = _updatePool();

        if (staker.epochId != poolEpochId) {
            staker.amount = 0;
            emit Unstake(user_, 0, 0);
            tokensReceived_ = 0;
        } else {
            uint256 unstakeFee;
            uint256 tokensAvailable = (staker.amount * poolProduct) / staker.poolDebt;

            if (!depeg_) {
                unstakeFee = getUnstakeFee(trancheId_, staker.stakeTimeStamp) * tokensAvailable / 10_000;
            } else {
                unstakeFee = 0;
            }
            staker.amount = 0;
            poolBalance -= tokensAvailable;

            //resetting system
            if (poolBalance <= 1e18) {
                poolProduct = 1e18;
                poolEpochId += 1;
                poolBalance = 0;
            }

            IERC20Helper(nstbl).mint(address(this), poolYield);
            IERC20Helper(nstbl).mint(atvl, atvlYield);

            IERC20Helper(nstbl).safeTransfer(atvl, unstakeFee);
            IERC20Helper(nstbl).safeTransfer(destAddress_, (tokensAvailable - unstakeFee));

            emit Unstake(user_, tokensAvailable, unstakeFee);
            tokensReceived_ = (tokensAvailable - unstakeFee);
        }
    }

    /**
     * @inheritdoc IStakePool
     */
    function updatePoolFromHub(bool redeem_, uint256 stablesReceived_, uint256 depositAmount_)
        external
        authorizedCaller
        nonReentrant
    {
        if (ILoanManager(loanManager).awaitingRedemption() && !redeem_) {
            oldMaturityVal += depositAmount_;
            return;
        }
        uint256 nstblYield;
        uint256 newMaturityVal = ILoanManager(loanManager).getMaturedAssets();

        if (redeem_) {
            if (newMaturityVal + stablesReceived_ < oldMaturityVal) {
                return;
            }
            nstblYield = newMaturityVal + stablesReceived_ - oldMaturityVal;
            oldMaturityVal = newMaturityVal;
        } else {
            if (newMaturityVal < oldMaturityVal) {
                oldMaturityVal += depositAmount_;
                return;
            }
            nstblYield = newMaturityVal - oldMaturityVal;
            if (nstblYield <= 1e18) {
                oldMaturityVal += depositAmount_;
                return;
            }
            oldMaturityVal = newMaturityVal + depositAmount_;
        }
        if (poolBalance <= 1e18) {
            IERC20Helper(nstbl).mint(address(this), nstblYield);
            unclaimedRewards += (nstblYield);
            return;
        }
        uint256 atvlBal = IERC20Helper(nstbl).balanceOf(atvl);
        uint256 atvlYield = nstblYield * atvlBal / (poolBalance + atvlBal);
        nstblYield -= atvlYield;
        IERC20Helper(nstbl).mint(address(this), nstblYield);
        IERC20Helper(nstbl).mint(atvl, atvlYield);

        nstblYield *= 1e18; //to maintain precision for accNSTBLPerShare

        poolProduct = (poolProduct * (poolBalance * 1e18 + nstblYield)) / (poolBalance * 1e18);
        poolBalance += (nstblYield / 1e18);
        emit UpdatedFromHub(poolProduct, poolBalance, nstblYield, atvlYield);
    }

    /**
     * @inheritdoc IStakePool
     */
    function updateMaturityValue() external authorizedCaller {
        require(genesis == 0, "SP: GENESIS");
        oldMaturityVal = ILoanManager(loanManager).getMaturedAssets();
        genesis += 1;
    }

    /**
     * @inheritdoc IStakePool
     */
    function withdrawUnclaimedRewards() external authorizedCaller {
        IERC20Helper(nstbl).safeTransfer(msg.sender, unclaimedRewards);
        unclaimedRewards = 0;
        emit UnclaimedRewardsWithdrawn(msg.sender, unclaimedRewards);
    }

    /**
     * @inheritdoc IStakePool
     */
    function burnNSTBL(uint256 amount_) external authorizedCaller {
        (uint256 poolYield, uint256 atvlYield) = _updatePool();
        require(amount_ <= poolBalance, "SP: Burn > SP_BALANCE");

        poolProduct = (poolProduct * ((poolBalance * 1e18 - amount_ * 1e18))) / (poolBalance * 1e18);

        if (poolProduct == 0 || poolBalance - amount_ <= 1e18) {
            poolProduct = 1e18;
            poolBalance = 0;
            poolEpochId += 1;
        } else {
            poolBalance -= amount_;
        }
        IERC20Helper(nstbl).mint(address(this), poolYield);
        IERC20Helper(nstbl).mint(atvl, atvlYield);
        IERC20Helper(nstbl).burn(address(this), amount_);
        emit NSTBLBurned(amount_, poolProduct, poolBalance, poolEpochId);
    }

    /*//////////////////////////////////////////////////////////////
    Views
    //////////////////////////////////////////////////////////////*/

    function getUnstakeFee(uint8 trancheId_, uint256 stakeTimeStamp_) public view returns (uint256 fee_) {
        uint256 timeElapsed = (block.timestamp - stakeTimeStamp_) / 1 days;
        if (trancheId_ == 0) {
            fee_ = (timeElapsed > trancheStakeTimePeriod[0])
                ? trancheBaseFee1
                : trancheBaseFee1
                    + (earlyUnstakeFee1 * (trancheStakeTimePeriod[0] - timeElapsed) / trancheStakeTimePeriod[0]);
        } else if (trancheId_ == 1) {
            fee_ = (timeElapsed > trancheStakeTimePeriod[1])
                ? trancheBaseFee2
                : trancheBaseFee2
                    + (earlyUnstakeFee2 * (trancheStakeTimePeriod[1] - timeElapsed) / trancheStakeTimePeriod[1]);
        } else {
            fee_ = (timeElapsed > trancheStakeTimePeriod[2])
                ? trancheBaseFee3
                : trancheBaseFee3
                    + (earlyUnstakeFee3 * (trancheStakeTimePeriod[2] - timeElapsed) / trancheStakeTimePeriod[2]);
        }
    }

    /**
     * @inheritdoc IStakePool
     */
    function previewUpdatePool() public view returns (uint256 poolProduct_) {
        if (ILoanManager(loanManager).awaitingRedemption()) {
            poolProduct_ = poolProduct;
        } else {
            uint256 newMaturityVal = ILoanManager(loanManager).getMaturedAssets();
            if (newMaturityVal > oldMaturityVal) {
                uint256 nstblYield = newMaturityVal - oldMaturityVal;

                if (nstblYield <= 1e18) {
                    poolProduct_ = poolProduct;
                } else if (poolBalance <= 1e18) {
                    poolProduct_ = poolProduct;
                } else {
                    uint256 atvlBal = IERC20Helper(nstbl).balanceOf(atvl);
                    uint256 atvlYield = nstblYield * atvlBal / (poolBalance + atvlBal);

                    nstblYield -= atvlYield;
                    nstblYield *= 1e18; //to maintain precision

                    poolProduct_ = ((poolProduct * ((poolBalance * 1e18 + nstblYield))) / (poolBalance * 1e18));
                }
            } else {
                poolProduct_ = poolProduct;
            }
        }
    }

    /**
     * @inheritdoc IStakePool
     */
    function getUserAvailableTokens(address user_, uint8 trancheId_) external view returns (uint256 availableTokens_) {
        StakerInfo memory staker = stakerInfo[trancheId_][user_];
        uint256 newPoolProduct = previewUpdatePool();

        if (staker.amount != 0 && staker.epochId == poolEpochId) {
            availableTokens_ = staker.amount * newPoolProduct / staker.poolDebt;
        } else {
            availableTokens_ = 0;
        }
    }
    /**
     * @inheritdoc IStakePool
     */
    function getStakerInfo(address user_, uint8 trancheId_)
        external
        view
        returns (uint256 amount_, uint256 poolDebt_, uint256 epochId_, uint256 stakerTimeStamp_)
    {
        StakerInfo memory staker = stakerInfo[trancheId_][user_];
        amount_ = staker.amount;
        poolDebt_ = staker.poolDebt;
        epochId_ = staker.epochId;
        stakerTimeStamp_ = staker.stakeTimeStamp;
    }

    /**
     * @inheritdoc IStakePool
     */
    function getVersion() public pure returns (uint256 version_) {
        version_ = getRevision();
    }

    /*//////////////////////////////////////////////////////////////
    Internals
    //////////////////////////////////////////////////////////////*/

    function _updatePool() internal returns (uint256, uint256) {
        //returns nstblYield for the pool and atvl
        if (ILoanManager(loanManager).awaitingRedemption()) {
            return (0, 0);
        }

        uint256 newMaturityVal = ILoanManager(loanManager).getMaturedAssets();
        if (newMaturityVal > oldMaturityVal) {
            // in case Maple devalues T-bills
            uint256 nstblYield = newMaturityVal - oldMaturityVal;

            if (nstblYield <= 1e18) {
                return (0, 0);
            }

            if (poolBalance <= 1e18) {
                // IERC20Helper(nstbl).mint(atvl, nstblYield);
                oldMaturityVal = newMaturityVal;
                return (0, nstblYield);
            }
            uint256 atvlBal = IERC20Helper(nstbl).balanceOf(atvl);
            uint256 atvlYield = nstblYield * atvlBal / (poolBalance + atvlBal);

            nstblYield -= atvlYield;

            // IERC20Helper(nstbl).mint(address(this), nstblYield);
            // IERC20Helper(nstbl).mint(atvl, atvlYield);

            nstblYield *= 1e18; //to maintain precision

            poolProduct = (poolProduct * ((poolBalance * 1e18 + nstblYield))) / (poolBalance * 1e18);
            poolBalance += (nstblYield / 1e18);

            oldMaturityVal = newMaturityVal;
            return (nstblYield / 1e18, atvlYield);
        } else {
            return (0, 0);
        }
    }
    
    function _zeroAddressCheck(address address_) internal pure {
        require(address_ != address(0), "SP:INVALID_ADDRESS");
    }

    function getRevision() internal pure virtual override returns (uint256 revision_) {
        revision_ = REVISION;
    }

}
