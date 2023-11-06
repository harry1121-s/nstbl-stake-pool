// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { console } from "forge-std/Test.sol";
import { IERC20Helper, ILoanManager, IACLManager, StakePoolStorage } from "./StakePoolStorage.sol";

contract NSTBLStakePool is StakePoolStorage {
    using SafeERC20 for IERC20Helper;

    uint256 private _locked = 1;

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

    constructor(address _aclManager, address _nstbl, address _loanManager) 
    // address _chainLinkPriceFeed
    {
        aclManager = _aclManager;
        nstbl = _nstbl;
        loanManager = _loanManager;
    }

    function init(address _atvl, uint256 _yieldThreshold, uint256 _stakingThreshold) external onlyAdmin {
        atvl = _atvl;
        yieldThreshold = _yieldThreshold;
        stakingThreshold = _stakingThreshold;
    }

    function setATVL(address _atvl) external onlyAdmin {
        atvl = _atvl;
    }

    function _getUnstakeFee(uint64 _stakeTimePeriod, uint256 _stakeTimeStamp, uint64 _earlyUnstakeFee, uint8)
        internal
        view
        returns (uint256 fee)
    {
        uint256 timeElapsed = (block.timestamp - _stakeTimeStamp) / 1 days;
        fee = (timeElapsed < _stakeTimePeriod)
            ? (_earlyUnstakeFee * (_stakeTimePeriod - timeElapsed) / _stakeTimePeriod)
            : 0;
    }

    //@TODO:retrieve function for unclaimed Rewards
    // TODO: manual add function hub
    function updatePoolFromHub(bool redeem, uint256 stablesReceived, uint256 depositAmount) external authorizedCaller{
        if(ILoanManager(loanManager).getAwaitingRedemptionStatus(usdc) && !redeem){
            return;
        }
        uint256 nstblYield;
        uint256 newMaturityVal = ILoanManager(loanManager).getMaturedAssets(usdc);
        console.log("VAL:", newMaturityVal, stablesReceived, oldMaturityVal);

        if(redeem){
            console.log("Redeeming");
            if(newMaturityVal + stablesReceived < oldMaturityVal){
                console.log("Returning");
                return;
            }
            nstblYield = newMaturityVal + stablesReceived - oldMaturityVal;
            oldMaturityVal = newMaturityVal;
        }
        else{
            if(newMaturityVal < oldMaturityVal){
                return;
            }
            nstblYield = newMaturityVal - oldMaturityVal;
            oldMaturityVal = newMaturityVal + depositAmount;
        }

        uint256 atvlBal = IERC20Helper(nstbl).balanceOf(atvl);
        uint256 atvlYield = nstblYield * atvlBal / (totalStakedAmount + atvlBal);
        nstblYield -= atvlYield;
        IERC20Helper(nstbl).mint(address(this), nstblYield);
        IERC20Helper(nstbl).mint(atvl, atvlYield);

        nstblYield *= 1e18; //to maintain precision for accNSTBLPerShare
        uint256 stakersYieldThreshold = yieldThreshold * totalStakedAmount * 1e18 / 10_000;
        uint256 rewards;

        if (nstblYield <= stakersYieldThreshold) {
            rewards = nstblYield;
        } else {
            rewards = stakersYieldThreshold;
            atvlExtraYield += (nstblYield - stakersYieldThreshold);
        }

        accNSTBLPerShare += rewards / totalStakedAmount;

    }

    function updatePool() public {
        console.log("Updating Pool");
        console.log(ILoanManager(loanManager).getAwaitingRedemptionStatus(usdc), "dfgsfdgsfg");
        if(ILoanManager(loanManager).getAwaitingRedemptionStatus(usdc)){
            console.log("Returning");
            return;
        }

        uint256 newMaturityVal = ILoanManager(loanManager).getMaturedAssets(usdc);

        if(newMaturityVal > oldMaturityVal){ //in case Maple devalues T-bills
            uint256 nstblYield = newMaturityVal - oldMaturityVal;
            uint256 atvlBal = IERC20Helper(nstbl).balanceOf(atvl);
            uint256 atvlYield = nstblYield * atvlBal / (totalStakedAmount + atvlBal);
            nstblYield -= atvlYield;
            IERC20Helper(nstbl).mint(address(this), nstblYield);
            IERC20Helper(nstbl).mint(atvl, atvlYield);

            nstblYield *= 1e18; //to maintain precision for accNSTBLPerShare
            uint256 stakersYieldThreshold = yieldThreshold * totalStakedAmount * 1e18 / 10_000;
            uint256 rewards;

            if (nstblYield <= stakersYieldThreshold) {
                rewards = nstblYield;
            } else {
                rewards = stakersYieldThreshold;
                atvlExtraYield += (nstblYield - stakersYieldThreshold);
            }

            accNSTBLPerShare += rewards / totalStakedAmount;

            oldMaturityVal = newMaturityVal;
        }

    }

    // TODO: accessControl
    function updateMaturyValue() external {
        oldMaturityVal = ILoanManager(loanManager).getMaturedAssets(usdc);
        console.log("Old Maturity val: ", oldMaturityVal);
    }

    // function getUnclaimedRewards() external view returns (uint256 _unclaimedRewards) {
    //     PoolInfo memory pool;
    //     for (uint256 i = 0; i < poolInfo.length; i++) {
    //         pool = poolInfo[i];
    //         _unclaimedRewards += pool.unclaimedRewards;
    //     }
    //     _unclaimedRewards /= 1e18;
    // }

    // function withdrawUnclaimedRewards() external authorizedCaller {
    //     uint256 unclaimedRewards;
    //     PoolInfo storage pool;
    //     for (uint256 i = 0; i < poolInfo.length; i++) {
    //         pool = poolInfo[i];
    //         unclaimedRewards += pool.unclaimedRewards;
    //         pool.unclaimedRewards = 0;
    //     }
    //     unclaimedRewards /= 1e18;
    //     IERC20Helper(nstbl).safeTransfer(msg.sender, unclaimedRewards);
    // }

    function burnNSTBL(uint256 _amount) external authorizedCaller nonReentrant {
        console.log("BURN AMOUNT: ", _amount);
        updatePool();
        transferATVLYield();

        uint256 removeFromStakeAmount;
        uint256 stakePoolBal = IERC20Helper(nstbl).balanceOf(address(this));

        require(_amount <= stakePoolBal, "SP: Burn > SP_BALANCE");
        IERC20Helper(nstbl).burn(address(this), _amount);
        // console.log("BURNING");
        // console.log("Stake Pool Balance: ", stakePoolBal);
        // console.log("Rewards: ", stakePoolBal-totalStakedAmount);

        if(_amount >= stakePoolBal-totalStakedAmount) {
            removeFromStakeAmount = (_amount - (stakePoolBal-totalStakedAmount));
        }
        else {
            removeFromStakeAmount = 0;
        }
        console.log("Remove From Stake Amount: ", removeFromStakeAmount);

        burnNSTBLPerShare += (_amount * 1e18 / totalStakedAmount);
        totalStakedAmount -= removeFromStakeAmount;

        // console.log("Total Staked Amount: ", totalStakedAmount);
        // console.log("Pool Balance", IERC20Helper(nstbl).balanceOf(address(this)));
        // console.log("END BURNING");
    }

    function stake(uint256 amount, uint8 trancheId, bytes11 stakeId) public authorizedCaller nonReentrant {
        console.log("Stake AMount: ", amount);
        uint256 a1;
        uint256 a2;
        StakerInfo storage staker = stakerInfo[stakeId];

        if (totalStakedAmount != 0) {
            updatePool();
            console.log("HERE");
        }

        IERC20Helper(nstbl).safeTransferFrom(msg.sender, address(this), amount);

        if (staker.amount > 0) {
            console.log("HERE2");
            a1 = staker.burnDebt + (staker.amount * accNSTBLPerShare / 1e18);
            a2 = (staker.amount * burnNSTBLPerShare / 1e18) + (staker.rewardDebt);
            totalStakedAmount += ((staker.amount * accNSTBLPerShare / 1e18) - staker.rewardDebt);
            staker.amount = (staker.amount + a1) - a2;
        } else {
            staker.owner = msg.sender;
            staker.trancheId = trancheId;
            staker.stakeId = stakeId;
        }
        // console.log("HERE3");

        staker.amount += amount;
        staker.rewardDebt = (staker.amount * accNSTBLPerShare) / 1e18;
        staker.burnDebt = (staker.amount * burnNSTBLPerShare) / 1e18;
        staker.stakeTimeStamp = block.timestamp;
        totalStakedAmount += amount;
        emit Stake(stakeId, trancheId, amount);
    }

    // function unstake(address _userAddress, uint256 _poolId, bool _depeg) public authorizedCaller {
    //     require(_poolId < poolInfo.length, "SP::INVALID POOL");
    //     console.log("UNSTAKING--------------");
    //     StakerInfo storage staker = stakerInfo[_poolId][_userAddress];
    //     PoolInfo storage pool = poolInfo[_poolId];
    //     uint256 unstakeFee;
    //     updatePool();

    //     uint256 timeElapsed = (block.timestamp - staker.stakeTimeStamp) / 1 days;
    //     uint256 a1 = staker.burnDebt + (staker.amount * pool.accNSTBLPerShare / 1e18);
    //     uint256 a2 = (staker.amount * pool.burnNSTBLPerShare / 1e18) + (staker.rewardDebt);
    //     uint256 tokensAvailable = staker.amount + a1 - a2;
    //     console.log(staker.amount, a1, a2);
    //     console.log("Tokens Available: ", tokensAvailable);
    //     console.log("TIMES: ", timeElapsed, pool.stakeTimePeriod);
    //     if (!_depeg) {
    //         if (timeElapsed <= pool.stakeTimePeriod + 1 ) {
    //             console.log("Early Unstakingggggg");
    //             unstakeFee = _getUnstakeFee(pool.stakeTimePeriod, staker.stakeTimeStamp, pool.earlyUnstakeFee)
    //                 * (tokensAvailable) / 100_000;

    //         } else {
    //             //restake
    //             console.log("Restakingggggg");
    //             pool.stakeAmount -= staker.amount;
    //             totalStakedAmount -= staker.amount;
    //             staker.amount = tokensAvailable;
    //             pool.stakeAmount += tokensAvailable;
    //             totalStakedAmount += tokensAvailable;
    //             staker.rewardDebt = (staker.amount * pool.accNSTBLPerShare) / 1e18;
    //             staker.burnDebt = (staker.amount * pool.burnNSTBLPerShare) / 1e18;
    //             staker.stakeTimeStamp = block.timestamp;
    //             return;
    //         }
    //     } else {
    //         unstakeFee = 0;
    //     }

    //     if(_depeg || timeElapsed <= pool.stakeTimePeriod + 1 )
    //     {
    //         console.log("Final Unstakingggggg");
    //         pool.stakeAmount -= staker.amount;
    //         totalStakedAmount -= staker.amount;
    //         staker.amount = 0;
    //         staker.rewardDebt = 0;
    //         staker.burnDebt = 0;

    //         IERC20Helper(nstbl).safeTransfer(msg.sender, tokensAvailable - unstakeFee);
    //         IERC20Helper(nstbl).safeTransfer(atvl, unstakeFee);
    //     }

    // }

    function transferATVLYield() public nonReentrant {
        IERC20Helper(nstbl).safeTransfer(atvl, atvlExtraYield);
        atvlExtraYield = 0;
    }
}
