// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./StakePoolStorage.sol";

contract NSTBLStakePool is StakePoolStorage{
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
        address _lUSDC,
        address _lUSDT,
        address _loanManager,
        address _chainLinkPriceFeed
    ) {
        admin = _admin;
        nstbl = _nstbl;
        nstblVault = _nstblvault;
        lUSDC = _lUSDC;
        lUSDT = _lUSDT;
        loanManager = _loanManager;
        chainLinkPriceFeed = _chainLinkPriceFeed;
        lpToken = new TokenLP("NSTBL_StakePool", "NSTBL_SP", admin);
        
    }

    function init(
        address _atvl,
        uint256 _yieldThreshold
    ) external onlyAdmin {
        atvl = _atvl;
        yieldThreshold = _yieldThreshold;
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

    function configurePool(uint256 _allocPoint, uint256 _stakeTimePeriod, uint256 _earlyUnstakeFee) external authorizedCaller {
        totalAllocPoint += _allocPoint;
        poolInfo.push(PoolInfo({
            accNSTBLPerShare: 0,
            allocPoint: uint64(_allocPoint),
            stakeTimePeriod: uint64(_stakeTimePeriod),
            earlyUnstakeFee: uint64(_earlyUnstakeFee)
        }));
    }

    function _getUnstakeFee(uint64 _stakeTimePeriod, uint256 _stakeTimeStamp, uint64 _earlyUnstakeFee) internal view returns (uint256 fee) {
        uint256 timeElapsed = (block.timestamp - _stakeTimeStamp)/ 1 days;
        fee = (timeElapsed < _stakeTimePeriod) ? (_earlyUnstakeFee*(_stakeTimePeriod-timeElapsed)/_stakeTimePeriod) : 0;
    }

    function getUpdatedYieldParams() public view returns(uint256 _usdcInvestedAmount, uint256 _usdcMaturityAmount, uint256 _nstblYield){
        uint256 investedAssets = ILoanManager(loanManager).getInvestedAssets();
        uint256 maturedAssets = ILoanManager(loanManager).getAssets(usdc, IERC20Helper(lUSDC).totalSupply());
        
        _usdcInvestedAmount = usdcInvestedAmount;
        _usdcMaturityAmount = usdcMaturityAmount;

        if(_usdcInvestedAmount == 0){
            _usdcInvestedAmount = investedAssets;
            _usdcMaturityAmount = maturedAssets; 
            //mint NSTBL = nstblYield
            _nstblYield = _usdcMaturityAmount - _usdcInvestedAmount;
        }
        else {
            uint256 r = investedAssets > usdcInvestedAmount ? precision : investedAssets*precision/usdcInvestedAmount;
            _nstblYield = maturedAssets - (r*usdcMaturityAmount/precision);
            _usdcMaturityAmount = maturedAssets;

            if(investedAssets != _usdcInvestedAmount){
                _usdcInvestedAmount = investedAssets;
            }
        }
    }

    function updatePools() internal {
        uint256 nstblYield;
        (usdcInvestedAmount, usdcMaturityAmount, nstblYield)= getUpdatedYieldParams();
        IERC20Helper(nstbl).mint(address(this), nstblYield);

        uint256 stakersYieldThreshold = yieldThreshold * totalStakedAmount/10000;
        uint256 nstblPerShare;
        if(nstblYield <= stakersYieldThreshold){
            nstblPerShare = (nstblYield * 1e12) / (lpToken.totalSupply()+atvlStakeAmount);
        }
        else{
            nstblPerShare = (stakersYieldThreshold * 1e12) / (lpToken.totalSupply()+atvlStakeAmount);
            atvlExtraYield += (nstblYield - stakersYieldThreshold);
        }

        for(uint256 i=0; i<poolInfo.length; i++){
            PoolInfo storage pool = poolInfo[i];
            pool.accNSTBLPerShare += nstblPerShare * pool.allocPoint / totalAllocPoint;
        }
    }

    function stake(uint256 _amount, address _userAddress, uint256 _poolId) public authorizedCaller {
        require(_amount > 0, "SP::INVALID AMOUNT");
        require(_poolId < poolInfo.length, "SP::INVALID POOL");
        uint256 pendingNSTBL;

        StakerInfo storage staker = stakerInfo[_poolId][_userAddress];
        updatePools();
        PoolInfo memory pool = poolInfo[_poolId];

        IERC20Helper(nstbl).safeTransferFrom(msg.sender, address(this), _amount);

        if(staker.amount > 0){
            pendingNSTBL = ((staker.amount * pool.accNSTBLPerShare) / 1e12) - (staker.rewardDebt);
            staker.amount += pendingNSTBL;
        }
        staker.amount += _amount;
        staker.rewardDebt += ((_amount+pendingNSTBL) * pool.accNSTBLPerShare) / 1e12;
        staker.stakeTimeStamp = block.timestamp;
        totalStakedAmount += _amount+pendingNSTBL;

        lpToken.mint(msg.sender, _amount+pendingNSTBL);
        emit Stake(_userAddress, _amount, pendingNSTBL);
    }

    function unstake(uint256 _amount, address _userAddress, uint256 _poolId) public authorizedCaller {
        require(_amount > 0, "SP::INVALID AMOUNT");
        require(_poolId < poolInfo.length, "SP::INVALID POOL");

        StakerInfo storage staker = stakerInfo[_poolId][_userAddress];
        updatePools();
        PoolInfo memory pool = poolInfo[_poolId];

        require(_amount <= staker.amount, "SP::INVALID AMOUNT");

        uint256 pendingNSTBL = ((staker.amount * pool.accNSTBLPerShare) / 1e12) - (staker.rewardDebt);

        uint256 unstakeFee = _getUnstakeFee(pool.stakeTimePeriod, staker.stakeTimeStamp, pool.earlyUnstakeFee) * (staker.amount+pendingNSTBL) / 10000;
        //TODO: will revert
        staker.rewardDebt -= (_amount * accNSTBLPerShare) / 1e12;
        staker.amount -= _amount;
        totalStakedAmount -= _amount;
        lpToken.burn(msg.sender, _amount);
        IERC20Helper(nstbl).safeTransfer(msg.sender, (_amount+pendingNSTBL) - unstakeFee);
        IERC20Helper(nstbl).safeTransfer(atvl, unstakeFee);

        emit Unstake(_userAddress, _amount);
    }

    function addATVLToStaker(uint256 _amount, uint256 _poolId) public onlyATVL {
        require(_amount > 0, "SP::INVALID AMOUNT");
        StakerInfo storage staker = stakerInfo[_poolId][atvl];
        if(!staker.ifATVLStaker)
            staker.ifATVLStaker = true;

        updatePools();
        transferATVLYield(_poolId);

        PoolInfo memory pool = poolInfo[_poolId];
    
        staker.amount += _amount;
        staker.rewardDebt = (_amount * pool.accNSTBLPerShare) / 1e12;
        staker.stakeTimeStamp = block.timestamp;
        totalStakedAmount += _amount;

        atvlStakeAmount += _amount;

    }   

    function removeATVLFromStaker(uint256 _amount, uint256 _poolId) public onlyATVL {
        require(_amount > 0, "SP::INVALID AMOUNT");
        updatePools();
        transferATVLYield(_poolId);
        PoolInfo memory pool = poolInfo[_poolId];
        StakerInfo storage staker = stakerInfo[_poolId][atvl];
        require(_amount <= staker.amount, "SP::INVALID AMOUNT");
        staker.amount -= _amount;
        //TODO revert
        staker.rewardDebt -= (_amount * pool.accNSTBLPerShare) / 1e12;
        totalStakedAmount -= _amount;
        atvlStakeAmount -= _amount;
    }

    //Should this be made non-reentrant?
    function transferATVLYield(uint256 _poolId) public nonReentrant{
        StakerInfo storage staker = stakerInfo[_poolId][atvl];
        PoolInfo memory pool = poolInfo[_poolId];
        uint256 accAtvlNSTBL = atvlExtraYield + ((staker.amount * pool.accNSTBLPerShare) / 1e12) - (staker.rewardDebt);
        staker.rewardDebt = (staker.amount * accNSTBLPerShare) / 1e12;
        atvlExtraYield = 0;
        IERC20Helper(nstbl).safeTransfer(atvl, accAtvlNSTBL);

    }
}
