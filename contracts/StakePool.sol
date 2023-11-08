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

    function init(address _atvl, uint256 _yieldThreshold) external onlyAdmin {
        atvl = _atvl;
        yieldThreshold = _yieldThreshold;
    }

    function setATVL(address _atvl) external onlyAdmin {
        atvl = _atvl;
    }


    // function _getUnstakeFee(uint64 _stakeTimePeriod, uint256 _stakeTimeStamp, uint64 _earlyUnstakeFee, uint8)
    //     internal
    //     view
    //     returns (uint256 fee)
    // {
    //     uint256 timeElapsed = (block.timestamp - _stakeTimeStamp) / 1 days;
    //     fee = (timeElapsed < _stakeTimePeriod)
    //         ? (_earlyUnstakeFee * (_stakeTimePeriod - timeElapsed) / _stakeTimePeriod)
    //         : 0;
    // }

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
        uint256 atvlYield = nstblYield * atvlBal / (poolBalance + atvlBal);
        nstblYield -= atvlYield;
        IERC20Helper(nstbl).mint(address(this), nstblYield);
        IERC20Helper(nstbl).mint(atvl, atvlYield);

        nstblYield *= 1e18; //to maintain precision for accNSTBLPerShare
        uint256 stakersYieldThreshold = yieldThreshold * poolBalance * 1e18 / 10_000;
        uint256 rewards;

        if (nstblYield <= stakersYieldThreshold) {
            rewards = nstblYield;
        } else {
            rewards = stakersYieldThreshold;
            atvlExtraYield += (nstblYield - stakersYieldThreshold);
        }

        if(poolBalance == 0){
            unclaimedRewards += (rewards/1e18);
            return;
        }
        poolProduct = poolProduct*(1e18 + rewards/poolBalance)/1e18;
        poolBalance += (rewards/1e18);

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
            console.log("HEREEEEEE", newMaturityVal, oldMaturityVal);
            uint256 nstblYield = newMaturityVal - oldMaturityVal;
            if(nstblYield <= 1e18){
                return; //to maintain precision 
            }
            console.log("NSTBL YIELD", nstblYield);
            uint256 atvlBal = IERC20Helper(nstbl).balanceOf(atvl);
            console.log("fgsdgdf", atvlBal, poolBalance);
            console.log("ATVL YIELD PARAMS", nstblYield);
            console.log("NSTBL Supply: ", IERC20Helper(nstbl).totalSupply());
             if(poolBalance == 0){
                IERC20Helper(nstbl).mint(atvl, nstblYield);
                oldMaturityVal = newMaturityVal;
                return;
            }
            console.log("ATVL YIELD PARAMS2", nstblYield);

            uint256 atvlYield = nstblYield * atvlBal / (poolBalance + atvlBal);
            console.log("ATVL YIELD", atvlYield);
            
            nstblYield -= atvlYield;
            console.log("HERE");
            console.log("NSTBL Supply: ", IERC20Helper(nstbl).totalSupply());

            IERC20Helper(nstbl).mint(address(this), nstblYield);
            if(atvlYield != 0)
                IERC20Helper(nstbl).mint(atvl, atvlYield);

            console.log("NSTBL YIELD", nstblYield);
            uint256 stakersYieldThreshold = yieldThreshold * poolBalance / 10_000;
            uint256 rewards;
            console.log("NSTBL YIELD", nstblYield, stakersYieldThreshold);
            if (nstblYield <= stakersYieldThreshold) {
                console.log("HERE");
                rewards = nstblYield*1e18;
            } else {
                rewards = stakersYieldThreshold*1e18;
                atvlExtraYield += (nstblYield - stakersYieldThreshold);
                console.log("HERE2");
                console.log("ATVL EXTRA YIELD", atvlExtraYield);
            }

            console.log("Rewards before: ", rewards, poolBalance, poolProduct);

            // uint256 poolBalbefore = poolBalance*1e18 + rewards;
            poolProduct = (poolProduct*((poolBalance*1e18 + rewards)/poolBalance))/1e18;
            poolBalance += (rewards/1e18);
            // uint256 nstblLoss = poolBalbefore - poolBalance*1e18;

            console.log("Rewards: ", rewards, poolBalance, poolProduct);
            oldMaturityVal = newMaturityVal;

        }
    }

    function updateMaturyValue() external {
        oldMaturityVal = ILoanManager(loanManager).getMaturedAssets(usdc);
        console.log("Old Maturity val: ", oldMaturityVal);
    }

    function withdrawUnclaimedRewards() external authorizedCaller {
        IERC20Helper(nstbl).safeTransfer(msg.sender, unclaimedRewards);
        unclaimedRewards = 0;
    }

    function burnNSTBL(uint256 _amount) external authorizedCaller {
        console.log("BURN AMOUNT: ", _amount);
        updatePool();
        transferATVLYield();

        require(_amount <= poolBalance, "SP: Burn > SP_BALANCE");
        IERC20Helper(nstbl).burn(address(this), _amount);

        console.log("STATES BEFORE: ",_amount, poolBalance, poolProduct);
        console.log("PRECOMPUTE: ", (poolProduct * ((poolBalance*1e18 - _amount*1e18) / poolBalance)));
        poolProduct = (poolProduct * ((poolBalance*1e18 - _amount*1e18) / poolBalance))/1e18;
        console.log("STATES after: ",_amount, poolBalance, poolProduct);

        if(poolProduct == 0 ||  poolBalance - _amount <= 1e18){ //because of loss of precision
            IERC20Helper(nstbl).safeTransfer(atvl, poolBalance - _amount);
            poolProduct = 1e18;
            poolBalance = 0;
            poolEpochId += 1;
        }
        else{
            poolBalance -= _amount;
        }
        console.log("STATES after: ",_amount, poolBalance, poolProduct);


        console.log("END BURNING");
    }

    function stake(address user, uint256 stakeAmount, uint8 trancheId) external authorizedCaller nonReentrant {
        console.log("Stake AMount: ", stakeAmount);
        require(stakeAmount != 0, "SP: ZERO_AMOUNT");
        require(trancheId < 3, "SP: INVALID_TRANCHE");
        StakerInfo storage staker = stakerInfo[trancheId][user];
        
        updatePool();

        IERC20Helper(nstbl).safeTransferFrom(msg.sender, address(this), stakeAmount);

        if (staker.amount > 0) {
            staker.amount = (staker.amount * poolProduct) / staker.poolDebt + stakeAmount;
        } else {
            staker.amount = stakeAmount;
            staker.epochId = poolEpochId;
        }
        staker.poolDebt = poolProduct;
        staker.stakeTimeStamp = block.timestamp;
        poolBalance += stakeAmount;
    
        emit Stake(user, staker.amount, staker.poolDebt);
    }

    function unstake(address user, uint8 trancheId, bool depeg) external authorizedCaller nonReentrant {
        StakerInfo storage staker = stakerInfo[trancheId][user];
        require(staker.amount > 0, "SP: NO STAKE");
        console.log("STAKER AMOUNT: ", staker.amount, staker.poolDebt);
        updatePool();
        console.log(staker.epochId, poolEpochId);
        if(staker.epochId != poolEpochId){
            staker.amount = 0;
            return;
        }

        uint256 tokensAvailable = (staker.amount * poolProduct) / staker.poolDebt;
        console.log("IDHR");
        console.log("Tokens Available: ", tokensAvailable);
        console.log("Pool Balance: ", poolBalance);
        staker.amount = 0;

        IERC20Helper(nstbl).safeTransfer(msg.sender, tokensAvailable);

        poolBalance -= tokensAvailable;

        //resetting system
        if(poolBalance <= 1e18){
            poolProduct = 1e18;
            poolEpochId += 1;
            poolBalance = 0;
            // IERC20Helper(nstbl).safeTransfer(atvl, IERC20Helper(nstbl).balanceOf(address(this)));

        }
    //      if (!_depeg) {
    //         if (timeElapsed <= pool.stakeTimePeriod + 1 ) {
    //             console.log("Early Unstakingggggg");
    //             unstakeFee = _getUnstakeFee(pool.stakeTimePeriod, staker.stakeTimeStamp, tranchearlyUnstakeFee)
    // //                 * (tokensAvailable) / 100_000;

    //         } else {
    //             //restake
    //             console.log("Restakingggggg");
    //             pool.stakeAmount -= staker.amount;
    //             poolBalance -= staker.amount;
    //             staker.amount = tokensAvailable;
    //             pool.stakeAmount += tokensAvailable;
    //             poolBalance += tokensAvailable;
    //             staker.rewardDebt = (staker.amount * pool.accNSTBLPerShare) / 1e18;
    //             staker.burnDebt = (staker.amount * pool.burnNSTBLPerShare) / 1e18;
    //             staker.stakeTimeStamp = block.timestamp;
    //             return;
    //         }
    //     } else {
    //         unstakeFee = 0;
    //     }

        // if(_depeg || timeElapsed <= pool.stakeTimePeriod + 1 )
        // {   
            

        //     console.log("Final Unstakingggggg");
        //     pool.stakeAmount -= staker.amount;
        //     poolBalance -= staker.amount;
        //     staker.amount = 0;
        //     staker.rewardDebt = 0;
        //     staker.burnDebt = 0;

        //     IERC20Helper(nstbl).safeTransfer(msg.sender, tokensAvailable - unstakeFee);
        //     IERC20Helper(nstbl).safeTransfer(atvl, unstakeFee);
        // }
        emit Unstake(user, tokensAvailable);
    }

    function getStakerInfo(address user, uint8 trancheId) external view returns (uint256 _amount, uint256 _poolDebt, uint256 _epochId) {
        StakerInfo memory staker = stakerInfo[trancheId][user];
        _amount = staker.amount;
        _poolDebt = staker.poolDebt;
        _epochId = staker.epochId;
    }

    function transferATVLYield() public nonReentrant {
        IERC20Helper(nstbl).safeTransfer(atvl, atvlExtraYield);
        atvlExtraYield = 0;
    }
}
