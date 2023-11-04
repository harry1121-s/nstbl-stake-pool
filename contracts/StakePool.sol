// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { console } from "forge-std/Test.sol";
import "./StakePoolStorage.sol";

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
        require(msg.sender == admin, "SP::NOT ADMIN");
        _;
    }

    modifier onlyATVL() {
        require(msg.sender == atvl, "SP::NOT ATVL");
        _;
    }

    modifier authorizedCaller() {
        require(authorizedCallers[msg.sender], "SP::NOT AUTHORIZED");
        _;
    }

    function setAuthorizedCaller(address _caller, bool _isAuthorized) external onlyAdmin {
        authorizedCallers[_caller] = _isAuthorized;
    }

    constructor(
        address _admin,
        address _nstbl,
        address _nealthyAddr,
        address _loanManager
    ) 
    // address _chainLinkPriceFeed
    {
        admin = _admin;
        nstbl = _nstbl;
        authorizedCallers[_nealthyAddr] = true;
        loanManager = _loanManager;
    }

    function init(address _atvl, uint256 _yieldThreshold, uint256 _stakingThreshold) external onlyAdmin {
        atvl = _atvl;
        yieldThreshold = _yieldThreshold;
        stakingThreshold = _stakingThreshold;
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    function setATVL(address _atvl) external onlyAdmin {
        atvl = _atvl;
    }

    function poolLength() external view returns (uint256 _pools) {
        _pools = poolInfo.length;
    }

    function configurePool(uint256 _allocPoint, uint256 _stakeTimePeriod, uint256 _earlyUnstakeFee)
        external
        onlyAdmin
    {
        totalAllocPoint += _allocPoint;
        poolInfo.push(
            PoolInfo({
                accNSTBLPerShare: 0,
                allocPoint: uint64(_allocPoint),
                stakeTimePeriod: uint64(_stakeTimePeriod),
                earlyUnstakeFee: uint64(_earlyUnstakeFee),
                unclaimedRewards: 0,
                rewards: 0,
                stakeAmount: 0,
                burnNSTBLPerShare: 0
            })
        );
    }

    function _getUnstakeFee(uint64 _stakeTimePeriod, uint256 _stakeTimeStamp, uint64 _earlyUnstakeFee)
        internal
        view
        returns (uint256 fee)
    {
        uint256 timeElapsed = (block.timestamp - _stakeTimeStamp) / 1 days;
        fee = (timeElapsed < _stakeTimePeriod)
            ? (_earlyUnstakeFee * (_stakeTimePeriod - timeElapsed) / _stakeTimePeriod)
            : 0;
    }

    function _validateStake(uint256 _amount, uint256 _poolId) internal view {
        require(_amount > 0, "SP::INVALID AMOUNT");
        require(_poolId < poolInfo.length, "SP::INVALID POOL");
        require(
            totalStakedAmount + _amount <= (stakingThreshold * IERC20Helper(nstbl).totalSupply() / 10_000) + IERC20Helper(nstbl).balanceOf(atvl),
            "SP::STAKING THRESHOLD REACHED"
        );
    }

    function getUpdatedYieldParams()
        public
        view
        returns (uint256 _usdcInvestedAmount, uint256 _usdcMaturityAmount, uint256 _nstblYield)
    {
        uint256 investedAssets = ILoanManager(loanManager).getInvestedAssets(usdc);
        uint256 maturedAssets = ILoanManager(loanManager).getMaturedAssets(usdc);

        _usdcInvestedAmount = usdcInvestedAmount;
        _usdcMaturityAmount = usdcMaturityAmount;

        if (_usdcInvestedAmount == 0) {
            _nstblYield = maturedAssets - investedAssets;
        } else {
            if (investedAssets > _usdcInvestedAmount) {
                _nstblYield = maturedAssets - _usdcMaturityAmount - (investedAssets - _usdcInvestedAmount);
            } else if (investedAssets < _usdcInvestedAmount) {
                uint256 r = investedAssets * precision / _usdcInvestedAmount;
                _nstblYield = maturedAssets - (r * usdcMaturityAmount / precision);
            } else {
                _nstblYield = maturedAssets - usdcMaturityAmount;
            }
        }
        _usdcMaturityAmount = maturedAssets;
        _usdcInvestedAmount = investedAssets;
    }

    function getUserStakedAmount(address _user, uint256 _poolId) external view returns (uint256 _stakedAmount) {
        StakerInfo memory staker = stakerInfo[_poolId][_user];
        _stakedAmount = staker.amount;
    }

    function getUserRewardDebt(address _user, uint256 _poolId) external view returns (uint256 _rewardDebt) {
        StakerInfo memory staker = stakerInfo[_poolId][_user];
        _rewardDebt = staker.rewardDebt;
    }

    //TODO: get user staked amount + rewards function

    // function getAvailableTokens(address _staker, uint256 _poolId)
    //     public
    //     view
    //     returns (uint256 _stakerRewards, uint256 _atvlExtraYield)
    // {
    //     StakerInfo memory staker = stakerInfo[_poolId][_staker];
    //     PoolInfo memory pool = poolInfo[_poolId];
    //     require(staker.amount > 0, "SP::INVALID STAKER");
    //     require(_amount <= staker.amount, "SP::INVALID AMOUNT");

    //     (,, uint256 nstblYield) = getUpdatedYieldParams();

    //     nstblYield *= 1e18;
    //     uint256 stakersYieldThreshold = yieldThreshold * totalStakedAmount * 1e18 / 10_000;
    //     uint256 rewards;
    //     if (nstblYield <= stakersYieldThreshold) {
    //         rewards = (nstblYield);
    //     } else {
    //         rewards = (stakersYieldThreshold);
    //         _atvlExtraYield = (nstblYield - stakersYieldThreshold);
    //     }

    //     pool.accNSTBLPerShare += rewards * pool.allocPoint / (totalAllocPoint * pool.stakeAmount);

    //     _stakerRewards = _amount + ((staker.amount * pool.accNSTBLPerShare) / 1e18) - staker.rewardDebt;
    //     _stakerRewards -= (
    //         _getUnstakeFee(pool.stakeTimePeriod, staker.stakeTimeStamp, pool.earlyUnstakeFee) * _stakerRewards / 100_000
    //     );
    // }

    // function getAvailableUserRewardsAfterFee(address _staker, uint256 _poolId)
    //     external
    //     view
    //     returns (uint256 _rewards)
    // {
    //     (_rewards,) = previewUnstake(0, _staker, _poolId);
    // }

    function getPoolInfo(uint256 _poolId)
        external
        view
        returns (uint256, uint64, uint64, uint64, uint256, uint256, uint256, uint256)
    {
        PoolInfo memory pool = poolInfo[_poolId];
        return (
            pool.accNSTBLPerShare,
            pool.allocPoint,
            pool.stakeTimePeriod,
            pool.earlyUnstakeFee,
            pool.unclaimedRewards,
            pool.rewards,
            pool.stakeAmount,
            pool.burnNSTBLPerShare
        );
    }

    function getAvailableYield() external view returns (uint256 _totalYield) {
        (,, uint256 nstblYield) = getUpdatedYieldParams();
        uint256 atvlBal = IERC20Helper(nstbl).balanceOf(atvl);
        uint256 atvlYield = nstblYield * atvlBal / (totalStakedAmount + atvlBal);

        nstblYield -= atvlYield;
        uint256 stakersYieldThreshold = yieldThreshold * totalStakedAmount / 10_000;

        if (nstblYield <= stakersYieldThreshold) {
            _totalYield = nstblYield;
        } else {
            _totalYield = stakersYieldThreshold;
        }
    }

    function burnNstbl(uint256 _amount) external authorizedCaller nonReentrant {
        console.log("BURN AMOUNT: ", _amount);
        updatePools();
        PoolInfo storage pool;
        uint256 removeFromStakeAmount;
        uint256 stakePoolBal = IERC20Helper(nstbl).balanceOf(address(this));
        console.log("BURNING");
        console.log("Stake Pool Balance: ", stakePoolBal);

        require(_amount <= stakePoolBal, "SP:: Burn amount exceeds staked amount");
        IERC20Helper(nstbl).burn(address(this), _amount);
        console.log("Rewards: ", stakePoolBal-totalStakedAmount);
        if(_amount >= stakePoolBal-totalStakedAmount)
        {
            removeFromStakeAmount = (_amount - (stakePoolBal-totalStakedAmount));
            for(uint256 i = 0; i < poolInfo.length; i++)
            {   
                poolInfo[i].unclaimedRewards = 0;
            }

        }
        else {
            removeFromStakeAmount = 0;
        }
        console.log("Remove From Stake Amount: ", removeFromStakeAmount);


        for (uint256 i = 0; i < poolInfo.length; i++) {
            pool = poolInfo[i];
            pool.stakeAmount -= (removeFromStakeAmount) * pool.stakeAmount / totalStakedAmount;
            pool.burnNSTBLPerShare += (_amount * 1e18 / totalStakedAmount);
            console.log("Burn NSTBL Per Share: ", pool.burnNSTBLPerShare);
            console.log("Stake Amount: ", pool.stakeAmount);
        }
        totalStakedAmount -= removeFromStakeAmount;
        console.log("Total Staked Amount: ", totalStakedAmount);
        console.log("Pool Balance", IERC20Helper(nstbl).balanceOf(address(this)));
        console.log("END BURNING");

    }

    function updatePools() public {
        PoolInfo storage pool;

        uint256 nstblYield;
        (usdcInvestedAmount, usdcMaturityAmount, nstblYield) = getUpdatedYieldParams();
        if (nstblYield == 0) {
            return;
        }
        uint256 atvlBal = IERC20Helper(nstbl).balanceOf(atvl);
        uint256 atvlYield = nstblYield * atvlBal / (totalStakedAmount + atvlBal);

        nstblYield -= atvlYield;
        IERC20Helper(nstbl).mint(address(this), nstblYield);
        IERC20Helper(nstbl).mint(atvl, atvlYield);
        console.log("NSTBL YIELD: ", nstblYield);
        console.log("ATVL YIELD: ", atvlYield);
        nstblYield *= 1e18;
        uint256 stakersYieldThreshold = yieldThreshold * totalStakedAmount * 1e18 / 10_000;
        uint256 rewards;
        if (nstblYield <= stakersYieldThreshold) {
            rewards = nstblYield;
        } else {
            rewards = stakersYieldThreshold;
            atvlExtraYield += (nstblYield - stakersYieldThreshold);
        }

        for (uint256 i = 0; i < poolInfo.length; i++) {
            pool = poolInfo[i];
            if (pool.stakeAmount == 0) {
                pool.unclaimedRewards += rewards * pool.allocPoint / (totalAllocPoint);
            } else {
                pool.rewards += rewards * pool.allocPoint / totalAllocPoint;
                pool.accNSTBLPerShare += rewards * pool.allocPoint / (totalAllocPoint * pool.stakeAmount);
                console.log("Pool Acc NSTBL Per Share: ", pool.accNSTBLPerShare);
            }
        }
        console.log("END UPDATE");
    }

    function getUnclaimedRewards() external view returns (uint256 _unclaimedRewards) {
        PoolInfo memory pool;
        for (uint256 i = 0; i < poolInfo.length; i++) {
            pool = poolInfo[i];
            _unclaimedRewards += pool.unclaimedRewards;
        }
        _unclaimedRewards /= 1e18;
    }

    function withdrawUnclaimedRewards() external authorizedCaller {
        uint256 unclaimedRewards;
        PoolInfo storage pool;
        for (uint256 i = 0; i < poolInfo.length; i++) {
            pool = poolInfo[i];
            unclaimedRewards += pool.unclaimedRewards;
            pool.unclaimedRewards = 0;
        }
        unclaimedRewards /= 1e18;
        IERC20Helper(nstbl).safeTransfer(msg.sender, unclaimedRewards);
    }

    function stake(uint256 _amount, address _userAddress, uint256 _poolId) public authorizedCaller {
        _validateStake(_amount, _poolId);
        console.log("Stake AMount: ", _amount);
        uint256 a1;
        uint256 a2;
        StakerInfo storage staker = stakerInfo[_poolId][_userAddress];
        PoolInfo storage pool = poolInfo[_poolId];

        if (totalStakedAmount != 0) {
            updatePools();
            console.log("HERE");
        }

        IERC20Helper(nstbl).safeTransferFrom(msg.sender, address(this), _amount);

        if (staker.amount > 0) {
            console.log("HERE2");
            a1 = staker.burnDebt + (staker.amount * pool.accNSTBLPerShare / 1e18);
            a2 = (staker.amount * pool.burnNSTBLPerShare / 1e18) + (staker.rewardDebt);
            console.log(staker.burnDebt, (staker.amount * pool.accNSTBLPerShare / 1e18));
            console.log((staker.amount * pool.burnNSTBLPerShare / 1e18), (staker.rewardDebt));
            console.log(pool.stakeAmount, a1, a2);
            // pool.stakeAmount += ((staker.amount * pool.accNSTBLPerShare / 1e18)-staker.rewardDebt);
            // pool.stakeAmount = (pool.stakeAmount + a1)-a2;
            console.log(staker.amount, a1, a2);
            staker.amount = (staker.amount + a1)-a2;
            // totalStakedAmount = (totalStakedAmount + a1)-a2;
        }
        console.log("HERE3");

        staker.amount += _amount;
        console.log("Staker Amt:", staker.amount);
        staker.rewardDebt = (staker.amount * pool.accNSTBLPerShare) / 1e18;
        staker.burnDebt = (staker.amount * pool.burnNSTBLPerShare) / 1e18;
        staker.stakeTimeStamp = block.timestamp;
        pool.stakeAmount += _amount;
        console.log("Pool Stake Amount: ", pool.stakeAmount);
        totalStakedAmount += _amount;
        console.log("Total Staked Amount: ", totalStakedAmount);
        console.log("Pool Balance", IERC20Helper(nstbl).balanceOf(address(this)));

        emit Stake(_userAddress, _amount, a1, a2);
    }

    function unstake(address _userAddress, uint256 _poolId, bool _depeg) public authorizedCaller {
        require(_poolId < poolInfo.length, "SP::INVALID POOL");

        StakerInfo storage staker = stakerInfo[_poolId][_userAddress];
        PoolInfo storage pool = poolInfo[_poolId];
        uint256 unstakeFee;
        updatePools();

        uint256 timeElapsed = (block.timestamp - staker.stakeTimeStamp) / 1 days;
        uint256 a1 = staker.burnDebt + (staker.amount * pool.accNSTBLPerShare / 1e18);
        uint256 a2 = (staker.amount * pool.burnNSTBLPerShare / 1e18) + (staker.rewardDebt);
        uint256 tokensAvailable = staker.amount + a1 - a2;

        if (!_depeg) {
            if (timeElapsed <= pool.stakeTimePeriod + 1 days) {

                unstakeFee = _getUnstakeFee(pool.stakeTimePeriod, staker.stakeTimeStamp, pool.earlyUnstakeFee)
                    * (tokensAvailable) / 100_000;

            } else {
                //restake
                pool.stakeAmount -= staker.amount;
                totalStakedAmount -= staker.amount;
                staker.amount = tokensAvailable;
                pool.stakeAmount += tokensAvailable;
                totalStakedAmount += tokensAvailable;
                staker.rewardDebt = (staker.amount * pool.accNSTBLPerShare) / 1e18;
                staker.burnDebt = (staker.amount * pool.burnNSTBLPerShare) / 1e18;
                staker.stakeTimeStamp = block.timestamp;
                return;
            }
        } else {
            unstakeFee = 0;
        }

        if(_depeg || timeElapsed <= pool.stakeTimePeriod + 1 days)
        {
            pool.stakeAmount -= staker.amount;
            totalStakedAmount -= staker.amount;
            staker.amount = 0;
            staker.rewardDebt = 0;
            staker.burnDebt = 0;

            IERC20Helper(nstbl).safeTransfer(msg.sender, tokensAvailable - unstakeFee);
            IERC20Helper(nstbl).safeTransfer(atvl, unstakeFee);
        }
        
    }
    
    function transferATVLYield(uint256 _poolId) public nonReentrant {
        IERC20Helper(nstbl).safeTransfer(atvl, atvlExtraYield);
        atvlExtraYield = 0;
    }
}
