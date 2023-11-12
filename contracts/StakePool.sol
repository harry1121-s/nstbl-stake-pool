// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { console } from "forge-std/console.sol";
import { VersionedInitializable } from "./upgradeable/VersionedInitializable.sol";
import { IERC20Helper, ILoanManager, IACLManager, TokenLP, StakePoolStorage } from "./StakePoolStorage.sol";

contract NSTBLStakePool is StakePoolStorage, VersionedInitializable {
    using SafeERC20 for IERC20Helper;

    uint256 private _locked;

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

    constructor() {
        usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    }

    function initialize(address _aclManager, address _nstbl, address _loanManager, address _atvl)
        external
        initializer
    {
        _zeroAddressCheck(_aclManager);
        _zeroAddressCheck(_nstbl);
        _zeroAddressCheck(_loanManager);
        _zeroAddressCheck(_atvl);
        aclManager = _aclManager;
        nstbl = _nstbl;
        loanManager = _loanManager;
        atvl = _atvl;
        lpToken = new TokenLP("NSTBLStakePool LP Token", "NSTBL_SP", IACLManager(aclManager).admin());
        _locked = 1;
        poolProduct = 1e18;
        emit StakePoolInitialized(REVISION, aclManager, nstbl, loanManager, atvl, address(lpToken));
    }

    function setupStakePool(
        // uint256 _yieldThreshold,
        uint16[3] memory trancheBaseFee,
        uint16[3] memory earlyUnstakeFee,
        uint8[3] memory stakeTimePeriods
    ) external onlyAdmin {
        require(trancheBaseFee.length == 3, "SP: INVALID_TRANCHE_FEE");
        require(earlyUnstakeFee.length == 3, "SP: INVALID_EARLY_UNSTAKE_FEE");
        require(stakeTimePeriods.length == 3, "SP: INVALID_STAKE_TIME_PERIODS");
        // yieldThreshold = _yieldThreshold;
        trancheBaseFee1 = trancheBaseFee[0];
        trancheBaseFee2 = trancheBaseFee[1];
        trancheBaseFee3 = trancheBaseFee[2];
        earlyUnstakeFee1 = earlyUnstakeFee[0];
        earlyUnstakeFee2 = earlyUnstakeFee[1];
        earlyUnstakeFee3 = earlyUnstakeFee[2];
        trancheStakeTimePeriod[0] = uint64(stakeTimePeriods[0]);
        trancheStakeTimePeriod[1] = uint64(stakeTimePeriods[1]);
        trancheStakeTimePeriod[2] = uint64(stakeTimePeriods[2]);
        emit StakePoolSetup(trancheStakeTimePeriod[0], trancheStakeTimePeriod[1], trancheStakeTimePeriod[2]);
    }

    function setATVL(address _atvl) external onlyAdmin {
        _zeroAddressCheck(_atvl);
        atvl = _atvl;
        emit ATVLUpdated(atvl);
    }

    function _getUnstakeFee(uint8 _trancheId, uint256 _stakeTimeStamp) internal view returns (uint256 fee) {
        uint256 timeElapsed = (block.timestamp - _stakeTimeStamp) / 1 days;
        if (_trancheId == 0) {
            fee = (timeElapsed > trancheStakeTimePeriod[0])
                ? trancheBaseFee1
                : trancheBaseFee1
                    + (earlyUnstakeFee1 * (trancheStakeTimePeriod[0] - timeElapsed) / trancheStakeTimePeriod[0]);
        } else if (_trancheId == 1) {
            fee = (timeElapsed > trancheStakeTimePeriod[1])
                ? trancheBaseFee2
                : trancheBaseFee2
                    + (earlyUnstakeFee2 * (trancheStakeTimePeriod[1] - timeElapsed) / trancheStakeTimePeriod[1]);
        } else {
            fee = (timeElapsed > trancheStakeTimePeriod[2])
                ? trancheBaseFee3
                : trancheBaseFee3
                    + (earlyUnstakeFee3 * (trancheStakeTimePeriod[2] - timeElapsed) / trancheStakeTimePeriod[2]);
        }
    }

    function updatePoolFromHub(bool redeem, uint256 stablesReceived, uint256 depositAmount)
        external
        authorizedCaller
        nonReentrant
    {
        if (ILoanManager(loanManager).awaitingRedemption() && !redeem) {
            oldMaturityVal += depositAmount;
            return;
        }
        uint256 nstblYield;
        uint256 newMaturityVal = ILoanManager(loanManager).getMaturedAssets();

        if (redeem) {
            if (newMaturityVal + stablesReceived < oldMaturityVal) {
                return;
            }
            nstblYield = newMaturityVal + stablesReceived - oldMaturityVal;
            oldMaturityVal = newMaturityVal;
        } else {
            if (newMaturityVal < oldMaturityVal) {
                oldMaturityVal += depositAmount;
                return;
            }
            nstblYield = newMaturityVal - oldMaturityVal;
            if (nstblYield <= 1e18) {
                oldMaturityVal += depositAmount;
                return;
            }
            oldMaturityVal = newMaturityVal + depositAmount;
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

    function _updatePool() internal {
        if (ILoanManager(loanManager).awaitingRedemption()) {
            return;
        }

        uint256 newMaturityVal = ILoanManager(loanManager).getMaturedAssets();
        if (newMaturityVal > oldMaturityVal) {
            // in case Maple devalues T-bills
            uint256 nstblYield = newMaturityVal - oldMaturityVal;

            if (nstblYield <= 1e18) {
                return;
            }

            if (poolBalance <= 1e18) {
                IERC20Helper(nstbl).mint(atvl, nstblYield);
                oldMaturityVal = newMaturityVal;
                return;
            }
            uint256 atvlBal = IERC20Helper(nstbl).balanceOf(atvl);
            uint256 atvlYield = nstblYield * atvlBal / (poolBalance + atvlBal);

            nstblYield -= atvlYield;

            IERC20Helper(nstbl).mint(address(this), nstblYield);
            IERC20Helper(nstbl).mint(atvl, atvlYield);

            nstblYield *= 1e18; //to maintain precision

            poolProduct = (poolProduct * ((poolBalance * 1e18 + nstblYield))) / (poolBalance * 1e18);
            poolBalance += (nstblYield / 1e18);

            oldMaturityVal = newMaturityVal;
        }
    }

    function previewUpdatePool() public view returns(uint256) {
        if (ILoanManager(loanManager).awaitingRedemption()) {
            return 0;
        }

        uint256 newMaturityVal = ILoanManager(loanManager).getMaturedAssets();
        if (newMaturityVal > oldMaturityVal) {
            // in case Maple devalues T-bills
            uint256 nstblYield = newMaturityVal - oldMaturityVal;

            if (nstblYield <= 1e18) {
                return 0;
            }

            if (poolBalance <= 1e18) {
                // IERC20Helper(nstbl).mint(atvl, nstblYield);
                // oldMaturityVal = newMaturityVal;
                return 0;
            }
            uint256 atvlBal = IERC20Helper(nstbl).balanceOf(atvl);
            uint256 atvlYield = nstblYield * atvlBal / (poolBalance + atvlBal);

            nstblYield -= atvlYield;

            // IERC20Helper(nstbl).mint(address(this), nstblYield);
            // IERC20Helper(nstbl).mint(atvl, atvlYield);

            nstblYield *= 1e18; //to maintain precision

            // uint256 tempPoolProduct = (poolProduct * ((poolBalance * 1e18 + nstblYield))) / (poolBalance * 1e18);
            return (poolProduct * ((poolBalance * 1e18 + nstblYield))) / (poolBalance * 1e18);


            // oldMaturityVal = newMaturityVal;
        }
    }

    function getUserAvailableTokens(address _user, uint8 _trancheId) external view returns(uint256){
        StakerInfo memory staker = stakerInfo[_trancheId][_user];
        uint256 newPoolProduct = previewUpdatePool();
        if(newPoolProduct != 0){
            return staker.amount*newPoolProduct/staker.poolDebt;
        }
        else{
            return staker.amount*poolProduct/staker.poolDebt;
        }
    }

    function updateMaturityValue() external {
        require(genesis == 0, "SP: GENESIS");
        oldMaturityVal = ILoanManager(loanManager).getMaturedAssets();
        genesis += 1;
    }

    function withdrawUnclaimedRewards() external authorizedCaller {
        IERC20Helper(nstbl).safeTransfer(msg.sender, unclaimedRewards);
        unclaimedRewards = 0;
        emit UnclaimedRewardsWithdrawn(msg.sender, unclaimedRewards);
    }

    function burnNSTBL(uint256 _amount) external authorizedCaller {
        _updatePool();
        transferATVLYield();

        require(_amount <= poolBalance, "SP: Burn > SP_BALANCE");
        IERC20Helper(nstbl).burn(address(this), _amount);

        poolProduct = (poolProduct * ((poolBalance * 1e18 - _amount * 1e18))) / (poolBalance * 1e18);

        if (poolProduct == 0 || poolBalance - _amount <= 1e18) {
            //because of loss of precision
            // IERC20Helper(nstbl).safeTransfer(atvl, poolBalance - _amount);
            poolProduct = 1e18;
            poolBalance = 0;
            poolEpochId += 1;
        } else {
            poolBalance -= _amount;
        }
        emit NSTBLBurned(_amount, poolProduct, poolBalance, poolEpochId);
    }

    function stake(address user, uint256 stakeAmount, uint8 trancheId, address destinationAddress)
        external
        authorizedCaller
        nonReentrant
    {
        require(stakeAmount > 0, "SP: ZERO_AMOUNT");
        require(trancheId < 3, "SP: INVALID_TRANCHE");
        StakerInfo storage staker = stakerInfo[trancheId][user];

        _updatePool();

        if (staker.amount > 0) {
            uint256 tokensAvailable = (staker.amount * poolProduct) / staker.poolDebt;
            uint256 unstakeFee = _getUnstakeFee(trancheId, staker.stakeTimeStamp) * tokensAvailable / 10_000;
            staker.amount = tokensAvailable - unstakeFee + stakeAmount;
            poolBalance -= unstakeFee;
            IERC20Helper(nstbl).safeTransfer(atvl, unstakeFee);
        } else {
            staker.amount = stakeAmount;
            staker.epochId = poolEpochId;
        }
        staker.poolDebt = poolProduct;
        staker.stakeTimeStamp = block.timestamp;
        poolBalance += stakeAmount;
        staker.lpTokens += stakeAmount;
        lpToken.mint(destinationAddress, stakeAmount);

        // IERC20Helper(nstbl).safeTransferFrom(msg.sender, address(this), stakeAmount);
        emit Stake(user, staker.amount, staker.poolDebt, staker.epochId, staker.lpTokens);
    }

    function unstake(address user, uint8 trancheId, bool depeg, address lpOwner)
        external
        authorizedCaller
        nonReentrant 
        returns(uint256)
    {
        StakerInfo storage staker = stakerInfo[trancheId][user];
        require(lpToken.balanceOf(lpOwner) >= staker.lpTokens);
        require(staker.amount > 0, "SP: NO STAKE");
        _updatePool();
        if (staker.epochId != poolEpochId) {
            staker.amount = 0;
            return 0;
        }

        uint256 timeElapsed = (block.timestamp - staker.stakeTimeStamp) / 1 days;
        uint256 unstakeFee;
        uint256 tokensAvailable = (staker.amount * poolProduct) / staker.poolDebt;

        if (!depeg) {
            unstakeFee = _getUnstakeFee(trancheId, staker.stakeTimeStamp) * tokensAvailable / 10_000;
        } else {
            unstakeFee = 0;
        }

        lpToken.burn(lpOwner, staker.lpTokens);
        staker.amount = 0;
        staker.lpTokens = 0;
        poolBalance -= tokensAvailable;

        //resetting system
        if (poolBalance <= 1e18) {
            poolProduct = 1e18;
            poolEpochId += 1;
            poolBalance = 0;
        }

        // IERC20Helper(nstbl).safeTransfer(msg.sender, tokensAvailable - unstakeFee);
        IERC20Helper(nstbl).safeTransfer(atvl, unstakeFee);
        emit Unstake(user, tokensAvailable, unstakeFee);
        return(tokensAvailable - unstakeFee);

    }

    function getStakerInfo(address user, uint8 trancheId)
        external
        view
        returns (uint256 _amount, uint256 _poolDebt, uint256 _epochId, uint256 _lpTokens, uint256 _stakerTimeStamp)
    {
        StakerInfo memory staker = stakerInfo[trancheId][user];
        _amount = staker.amount;
        _poolDebt = staker.poolDebt;
        _epochId = staker.epochId;
        _lpTokens = staker.lpTokens;
        _stakerTimeStamp = staker.stakeTimeStamp;
    }

    function transferATVLYield() public nonReentrant {
        IERC20Helper(nstbl).safeTransfer(atvl, atvlExtraYield);
        atvlExtraYield = 0;
    }

    function _zeroAddressCheck(address _address) internal pure {
        require(_address != address(0), "SP:INVALID_ADDRESS");
    }

    function getRevision() internal pure virtual override returns (uint256) {
        return REVISION;
    }

    function getVersion() public pure returns (uint256 _version) {
        _version = getRevision();
    }
}
