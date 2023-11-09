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

    function init(address _atvl, uint256 _yieldThreshold, uint16[3] memory trancheBaseFee, uint16[3] memory earlyUnstakeFee, uint8[3] memory stakeTimePeriods) external onlyAdmin {
        require(trancheBaseFee.length == 3, "SP: INVALID_TRANCHE_FEE");
        require(earlyUnstakeFee.length == 3, "SP: INVALID_EARLY_UNSTAKE_FEE");
        require(stakeTimePeriods.length == 3, "SP: INVALID_STAKE_TIME_PERIODS");
        atvl = _atvl;
        yieldThreshold = _yieldThreshold;
        trancheBaseFee1 = trancheBaseFee[0];
        trancheBaseFee2 = trancheBaseFee[1];
        trancheBaseFee3 = trancheBaseFee[2];
        earlyUnstakeFee1 = earlyUnstakeFee[0];
        earlyUnstakeFee2 = earlyUnstakeFee[1];
        earlyUnstakeFee3 = earlyUnstakeFee[2];
        trancheStakeTimePeriod[0] = uint64(stakeTimePeriods[0]);
        trancheStakeTimePeriod[1] = uint64(stakeTimePeriods[1]);
        trancheStakeTimePeriod[2] = uint64(stakeTimePeriods[2]);
    }

    function setATVL(address _atvl) external onlyAdmin {
        atvl = _atvl;
    }


    function _getUnstakeFee(uint8 _trancheId, uint256 _stakeTimeStamp)
        internal
        view
        returns (uint256 fee)
    {
        uint256 timeElapsed = (block.timestamp - _stakeTimeStamp) / 1 days;
        if(_trancheId == 0){
            fee = (timeElapsed > 30 days) ? trancheBaseFee1 :
            trancheBaseFee1 + (earlyUnstakeFee1 * (timeElapsed / 30 days));
        }
        else if( _trancheId == 1) {
            fee = (timeElapsed > 90 days) ? trancheBaseFee2 :
            trancheBaseFee2 + (earlyUnstakeFee2 * (timeElapsed / 90 days));
        }
        else {
            fee = (timeElapsed > 180 days) ? trancheBaseFee3 :
            trancheBaseFee3 + (earlyUnstakeFee3 * (timeElapsed / 180 days));
        }
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
        console.log("VAL:", newMaturityVal, oldMaturityVal);
        if(newMaturityVal > oldMaturityVal){ //in case Maple devalues T-bills
            uint256 nstblYield = newMaturityVal - oldMaturityVal;

            if(nstblYield <= 1e18){
                return; 
            }
            uint256 atvlBal = IERC20Helper(nstbl).balanceOf(atvl);
  
             if(poolBalance == 0){
                IERC20Helper(nstbl).mint(atvl, nstblYield);
                oldMaturityVal = newMaturityVal;
                return;
            }

            uint256 atvlYield = nstblYield * atvlBal / (poolBalance + atvlBal);
            
            nstblYield -= atvlYield;

            IERC20Helper(nstbl).mint(address(this), nstblYield);
            IERC20Helper(nstbl).mint(atvl, atvlYield);

            nstblYield *= 1e18; //to maintain precision
            console.log("NSTBL YIELD", nstblYield);
            

            console.log("Rewards before: ", nstblYield, poolBalance, poolProduct);

            poolProduct = (poolProduct*((poolBalance*1e18 + nstblYield)/poolBalance))/1e18;
            poolBalance += (nstblYield/1e18);

            console.log("Rewards: ", nstblYield, poolBalance, poolProduct);
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
        updatePool();
        transferATVLYield();

        require(_amount <= poolBalance, "SP: Burn > SP_BALANCE");
        IERC20Helper(nstbl).burn(address(this), _amount);

        poolProduct = (poolProduct * ((poolBalance*1e18 - _amount*1e18) / poolBalance))/1e18;

        if(poolProduct == 0 ||  poolBalance - _amount <= 1e18){ //because of loss of precision
            // IERC20Helper(nstbl).safeTransfer(atvl, poolBalance - _amount);
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

        uint256 timeElapsed = (block.timestamp - staker.stakeTimeStamp)/1 days;
        uint256 unstakeFee;
        uint256 tokensAvailable = (staker.amount * poolProduct) / staker.poolDebt;
        uint256 maturityTokens = _getMaturityTokens(tokensAvailable, staker.amount, staker.stakeTimeStamp);
        console.log("Tokens ::::::::", tokensAvailable, maturityTokens);
        if (!depeg) {
            if (timeElapsed <= trancheStakeTimePeriod[trancheId] + 1 ) {
                console.log("Early Unstakingggggg");
                unstakeFee = maturityTokens <= tokensAvailable ? 0 : _getUnstakeFee(trancheId , staker.stakeTimeStamp) * maturityTokens / 10_000;
            }
            // } else {
            //     //restake
            //     console.log("Restakingggggg");
            //     pool.stakeAmount -= staker.amount;
            //     poolBalance -= staker.amount;
            //     staker.amount = tokensAvailable;
            //     pool.stakeAmount += tokensAvailable;
            //     poolBalance += tokensAvailable;
            //     staker.rewardDebt = (staker.amount * pool.accNSTBLPerShare) / 1e18;
            //     staker.burnDebt = (staker.amount * pool.burnNSTBLPerShare) / 1e18;
            //     staker.stakeTimeStamp = block.timestamp;
            //     return;
            // }
        } else {
            unstakeFee = 0;
        }

        if(depeg || timeElapsed <= trancheStakeTimePeriod[trancheId] + 1 )
        {           
            
            staker.amount = 0;
            poolBalance -= tokensAvailable;

            console.log("HEREeeeeeeeeeeee");
            console.log(maturityTokens - unstakeFee);
            console.log(tokensAvailable - maturityTokens + unstakeFee);

            IERC20Helper(nstbl).safeTransfer(msg.sender, maturityTokens - unstakeFee);
            IERC20Helper(nstbl).safeTransfer(atvl, (tokensAvailable - maturityTokens) + unstakeFee);

             //resetting system
            if(poolBalance <= 1e18){
                poolProduct = 1e18;
                poolEpochId += 1;
                poolBalance = 0;
                // IERC20Helper(nstbl).safeTransfer(atvl, IERC20Helper(nstbl).balanceOf(address(this)));

            }
            emit Unstake(user, tokensAvailable);

        }









////////////////////////////////////////do not touch this code////////////////////////////////////////
        // console.log("IDHR");
        // console.log("Tokens Available: ", tokensAvailable);
        // console.log("Pool Balance: ", poolBalance);
        // staker.amount = 0;

        // IERC20Helper(nstbl).safeTransfer(msg.sender, tokensAvailable);

        // poolBalance -= tokensAvailable;

    }

    function _getMaturityTokens(uint256 tokensAvailable, uint256 stakeAmount, uint256 stakeTimeStamp) internal view returns(uint256){
        uint256 timeElapsed = (block.timestamp - stakeTimeStamp);
        console.log("In getMaturity Tokens");
        console.log("Time Elapsed: ", timeElapsed);
        console.log("Tokens Available: ", tokensAvailable);
        console.log("Stake Amount: ", stakeAmount);
        if(tokensAvailable <= stakeAmount){
            return tokensAvailable;
        }  
        else {
            console.log("APY params:", stakeAmount, timeElapsed, yieldThreshold);
            console.log("APY earned", stakeAmount*timeElapsed*yieldThreshold/1e17);
            uint256 maturityTokens = stakeAmount + (stakeAmount*timeElapsed*yieldThreshold/1e17);
            return maturityTokens <= tokensAvailable ? maturityTokens : tokensAvailable;
        }

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
