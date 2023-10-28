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
        address _nstblvault,
        address _nealthyAddr,
        // address _lUSDC,
        // address _lUSDT,
        address _loanManager
    ) 
    // address _chainLinkPriceFeed
    {
        admin = _admin;
        nstbl = _nstbl;
        nstblVault = _nstblvault;
        authorizedCallers[_nealthyAddr] = true;
        // lUSDC = _lUSDC;
        // lUSDT = _lUSDT;
        loanManager = _loanManager;
        lpToken = new TokenLP("NSTBL_StakePool", "NSTBL_SP", admin);
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

    function poolLength() public view returns (uint256 _pools) {
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
                stakeAmount: 0
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
        console.log("FEE", fee);
    }

    function _validateStake(uint256 _amount, uint256 _poolId) internal view {
        require(_amount > 0, "SP::INVALID AMOUNT");
        require(_poolId < poolInfo.length, "SP::INVALID POOL");
        require(
            totalStakedAmount + _amount <= stakingThreshold * IERC20Helper(nstbl).totalSupply() / 10_000,
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
            } 
            else if (investedAssets < _usdcInvestedAmount) {
                uint256 r = investedAssets * precision / _usdcInvestedAmount;
                _nstblYield = maturedAssets - (r * usdcMaturityAmount / precision);
            } 
            else {
                _nstblYield = maturedAssets - usdcMaturityAmount;
            }
            
        }
        _usdcMaturityAmount = maturedAssets;
        _usdcInvestedAmount = investedAssets;

        console.log("YIELD", _nstblYield, _usdcMaturityAmount, _usdcInvestedAmount);
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

    function getStakerRewardsAfterFee(address _staker, uint256 _poolId)
        external
        view
        returns (uint256 _stakerRewards, uint256 _atvlExtraYield)
    {
        StakerInfo memory staker = stakerInfo[_poolId][_staker];
        PoolInfo memory pool = poolInfo[_poolId];
        require(staker.amount > 0, "SP::INVALID STAKER");

        (,, uint256 nstblYield) = getUpdatedYieldParams();

        nstblYield *= 1e24;
        uint256 stakersYieldThreshold = yieldThreshold * totalStakedAmount*1e24 / 10_000;
        uint256 rewards;
        if(nstblYield <= stakersYieldThreshold){
            rewards = (nstblYield);
        } else {
            rewards = (stakersYieldThreshold);
            _atvlExtraYield = (nstblYield - stakersYieldThreshold);
        }

        pool.accNSTBLPerShare += rewards * pool.allocPoint / (totalAllocPoint*pool.stakeAmount);

        _stakerRewards = staker.amount + ((staker.amount * pool.accNSTBLPerShare) / 1e24) - staker.rewardDebt;
        _stakerRewards -= (_getUnstakeFee(pool.stakeTimePeriod, staker.stakeTimeStamp, pool.earlyUnstakeFee)
            * _stakerRewards / 10_000);
    }

    function getPoolInfo(uint256 _poolId) external view returns(uint256, uint64, uint64, uint64, uint256, uint256, uint256) {
        PoolInfo memory pool = poolInfo[_poolId];
        return (pool.accNSTBLPerShare, pool.allocPoint, pool.stakeTimePeriod, pool.earlyUnstakeFee, pool.unclaimedRewards, pool.rewards, pool.stakeAmount);
    }

    function getAvailableRewards() external view returns(uint256 _totalYield){
        (,, uint256 nstblYield) = getUpdatedYieldParams();
        uint256 stakersYieldThreshold = yieldThreshold * totalStakedAmount / 10_000;

        if(nstblYield<=stakersYieldThreshold){
            _totalYield = nstblYield;
        } else {
            _totalYield = stakersYieldThreshold;
        }

    }

    function updatePools() public {
        PoolInfo storage pool;

        uint256 nstblYield;
        (usdcInvestedAmount, usdcMaturityAmount, nstblYield) = getUpdatedYieldParams();
        if(nstblYield==0){
            return;
        }
        IERC20Helper(nstbl).mint(address(this), nstblYield);

        uint256 stakersYieldThreshold = yieldThreshold * totalStakedAmount/ 10_000;
        console.log("STAKERS YIELD THRESHOLD", stakersYieldThreshold);
        uint256 rewards;
        if (nstblYield <= stakersYieldThreshold) {
            rewards = nstblYield*1e24;
        } else {
            rewards = stakersYieldThreshold*1e24;
            atvlExtraYield += (nstblYield - stakersYieldThreshold);
        }
        console.log("TOTAL REWARDS", rewards);
        console.log("ATVL EXTRA YIELD", atvlExtraYield);
        for (uint256 i = 0; i < poolInfo.length; i++) {
            pool = poolInfo[i];
            if (pool.stakeAmount == 0) {
                console.log("HERE1");
                pool.unclaimedRewards += rewards * pool.allocPoint / (totalAllocPoint*1e24);
            } else {
                console.log("HERE2");
                pool.rewards += rewards * pool.allocPoint / totalAllocPoint;
                pool.accNSTBLPerShare += pool.rewards / pool.stakeAmount;
            }
            console.log("Unclaimed Rewards: ", pool.unclaimedRewards);
            console.log("Pool Rewards: ", pool.rewards);
            console.log("Pool Share", pool.accNSTBLPerShare);
        }
    }

    function getUnclaimedRewards() public view returns (uint256 _unclaimedRewards) {
        PoolInfo memory pool;
        for (uint256 i = 0; i < poolInfo.length; i++) {
            pool = poolInfo[i];
            _unclaimedRewards += pool.unclaimedRewards;
        }
    }

    function withdrawUnclaimedRewards() external authorizedCaller {
        uint256 unclaimedRewards;
        PoolInfo storage pool;
        for (uint256 i = 0; i < poolInfo.length; i++) {
            pool = poolInfo[i];
            unclaimedRewards += pool.unclaimedRewards;
            pool.unclaimedRewards = 0;
        }
        IERC20Helper(nstbl).safeTransfer(msg.sender, unclaimedRewards);
    }

    function stake(uint256 _amount, address _userAddress, uint256 _poolId) public authorizedCaller {
        _validateStake(_amount, _poolId);

        uint256 pendingNSTBL;
        StakerInfo storage staker = stakerInfo[_poolId][_userAddress];
        PoolInfo storage pool = poolInfo[_poolId];

        if (lpToken.totalSupply() != 0) {
            updatePools();
        }

        IERC20Helper(nstbl).safeTransferFrom(msg.sender, address(this), _amount);

        if (staker.amount > 0) {
            pendingNSTBL = ((staker.amount * pool.accNSTBLPerShare) / 1e24) - (staker.rewardDebt);
            staker.amount += pendingNSTBL;
            pool.stakeAmount += pendingNSTBL;
        }
        staker.amount += _amount;
        staker.rewardDebt = (staker.amount * pool.accNSTBLPerShare) / 1e24;
        staker.stakeTimeStamp = block.timestamp;
        pool.stakeAmount += _amount;
        totalStakedAmount += _amount + pendingNSTBL;

        console.log("REWARD DEBT", staker.rewardDebt);
        console.log("STAKE AMOUNT", pool.stakeAmount);
        console.log("PENDING AMOUNT", pendingNSTBL);
        lpToken.mint(msg.sender, _amount + pendingNSTBL);

        emit Stake(_userAddress, _amount, pendingNSTBL);
    }

    function unstake(uint256 _amount, address _userAddress, uint256 _poolId) public authorizedCaller {
        console.log("Unstake", _amount, _userAddress, _poolId);
        require(_amount > 0, "SP::INVALID AMOUNT");
        require(_poolId < poolInfo.length, "SP::INVALID POOL");

        StakerInfo storage staker = stakerInfo[_poolId][_userAddress];
        PoolInfo storage pool = poolInfo[_poolId];

        updatePools();

        require(_amount <= staker.amount, "SP::INVALID AMOUNT");

        uint256 pendingNSTBL = ((staker.amount * pool.accNSTBLPerShare) / 1e24) - (staker.rewardDebt);

        console.log("fgdfgdfgsdfagdfgsdfgdfgdfga", pendingNSTBL);
        uint256 unstakeFee = _getUnstakeFee(pool.stakeTimePeriod, staker.stakeTimeStamp, pool.earlyUnstakeFee)
            * (staker.amount + pendingNSTBL) / 10_000;


        staker.amount -= _amount;
        staker.rewardDebt = (staker.amount * pool.accNSTBLPerShare) / 1e24;
        pool.stakeAmount -= _amount;
        totalStakedAmount -= _amount;

        lpToken.burn(msg.sender, _amount);
        console.log("3erwtretwrwertretertetwtr", (_amount + pendingNSTBL) - unstakeFee);
        IERC20Helper(nstbl).safeTransfer(msg.sender, (_amount + pendingNSTBL) - unstakeFee);
        IERC20Helper(nstbl).safeTransfer(atvl, unstakeFee);

        emit Unstake(_userAddress, _amount);
    }

    function addATVLToStaker(uint256 _amount, uint256 _poolId) public onlyATVL {
        require(_amount > 0, "SP::INVALID AMOUNT");

        StakerInfo storage staker = stakerInfo[_poolId][atvl];
        PoolInfo storage pool = poolInfo[_poolId];

        if (!staker.ifATVLStaker) {
            staker.ifATVLStaker = true;
        }
        if (lpToken.totalSupply() != 0) {
            updatePools();
        }
        if(staker.amount>0){
            transferATVLYield(_poolId);
        }
        staker.amount += _amount;
        staker.rewardDebt = (staker.amount * pool.accNSTBLPerShare) / 1e24;
        staker.stakeTimeStamp = block.timestamp;
        pool.stakeAmount += _amount;
        totalStakedAmount += _amount;

    }

    function removeATVLFromStaker(uint256 _amount, uint256 _poolId) public onlyATVL {
        require(_amount > 0, "SP::INVALID AMOUNT");
        StakerInfo storage staker = stakerInfo[_poolId][atvl];
        PoolInfo storage pool = poolInfo[_poolId];
        require(_amount <= staker.amount, "SP::INVALID AMOUNT");

        updatePools();
        transferATVLYield(_poolId);

        staker.amount -= _amount;
        staker.rewardDebt = (staker.amount * pool.accNSTBLPerShare) / 1e24;
        pool.stakeAmount -= _amount;
        totalStakedAmount -= _amount;
    }

    //Should this be made non-reentrant?
    function transferATVLYield(uint256 _poolId) public nonReentrant {
        StakerInfo storage staker = stakerInfo[_poolId][atvl];
        PoolInfo memory pool = poolInfo[_poolId];
        uint256 atvlRewards = atvlExtraYield + ((staker.amount * pool.accNSTBLPerShare) / 1e24) - (staker.rewardDebt);
        staker.rewardDebt = (staker.amount * pool.accNSTBLPerShare) / 1e24;
        atvlExtraYield = 0;
        IERC20Helper(nstbl).safeTransfer(atvl, atvlRewards);
    }

}
