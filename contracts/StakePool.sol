// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./NSTBLVaultStorage.sol";

contract NSTBLStakePool is NSTBLVaultStorage{
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
        uint256 _yieldThreshold,
        uint256 _atvlSharePercent,
        uint256[] memory _trancheFee
    ) external onlyAdmin {
        atvl = _atvl;
        yieldThreshold = _yieldThreshold;
        atvlSharePercent = _atvlSharePercent;
        trancheTimePeriods[0] = 30 days;
        trancheTimePeriods[1] = 900 days;
        trancheTimePeriods[2] = 180 days;
        trancheFee[0] = _trancheFee[0];
        trancheFee[1] = _trancheFee[1];
        trancheFee[2] = _trancheFee[2];
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    function setATVL(address _atvl) external onlyAdmin {
        atvl = _atvl;
    }

    function _getUnstakeFee(int8 tranche, uint256 timeStamp) internal view returns (uint256 fee) {
        uint256 timeElapsed = (block.timestamp - timeStamp)/ 1 days;
        
        if(tranche == 0) {
            fee = 200 + (trancheFee[0]*(30-timeElapsed))/30;
        }
        else if(tranche == 1) {
            fee = 100 + (trancheFee[1]*(90-timeElapsed))/90;
        }
        else if(tranche == 2) {
            fee = trancheFee[2]*(180-timeElapsed)/180;
        }
        else {
            fee = 0;
        }
    }

    function updatePool() public {
        // using 8 decimals for price and standard 6 decimals for amount

        uint256 priceLiquidAssets = IChainlinkPriceFeed(chainLinkPriceFeed).getAverageAssetsPrice();
        uint256 priceNSTBL = (700 * 1e8 + 300 * priceLiquidAssets) / 1000;

        uint256 tvlLiquidAssets = INSTBLVault(nstblVault).getTvlLiquidAssets(); //6 * 8 decimals

        uint256 unrealisedUsdcTvl = ILoanManager(loanManager).getAssetsWithUnrealisedLosses(usdc, IERC20Helper(lUSDC).totalSupply())
            * IChainlinkPriceFeed(chainLinkPriceFeed).getUSDCPrice();
        uint256 unrealisedUsdtTvl = ILoanManager(loanManager).getAssetsWithUnrealisedLosses(usdt, IERC20Helper(lUSDT).totalSupply())
            * IChainlinkPriceFeed(chainLinkPriceFeed).getUSDTPrice();

        uint256 totalUnrealisedTvl = unrealisedUsdcTvl + unrealisedUsdtTvl + tvlLiquidAssets;

        uint256 nstblToBeMinted =
            (totalUnrealisedTvl * 1e12 - (priceNSTBL * IERC20Helper(nstbl).totalSupply())) / priceNSTBL;

        uint256 atvlShare = atvlSharePercent * nstblToBeMinted / 10000;
        
        IERC20Helper(nstbl).mint(atvl, atvlShare);
        IERC20Helper(nstbl).mint(address(this), nstblToBeMinted-atvlShare);

        uint256 stakersYieldThreshold = yieldThreshold * totalStakedAmount/10000;
        if(nstblToBeMinted <= stakersYieldThreshold){
            accNSTBLPerShare += (nstblToBeMinted * 1e12) / (lpToken.totalSupply()+atvlStakeAmount);
        }
        else{
            accNSTBLPerShare += (stakersYieldThreshold * 1e12) / (lpToken.totalSupply()+atvlStakeAmount);
            atvlExtraYield += (nstblToBeMinted - stakersYieldThreshold);
        }
    }

    function getPendingYield() public view returns(uint256 nstblToBeMinted, uint256 accNSTBL, uint256 atvlShare, uint256 atvlExtra) {
        
        uint256 priceLiquidAssets = IChainlinkPriceFeed(chainLinkPriceFeed).getAverageAssetsPrice();
        uint256 priceNSTBL = (700 * 1e8 + 300 * priceLiquidAssets) / 1000;

        uint256 tvlLiquidAssets = INSTBLVault(nstblVault).getTvlLiquidAssets(); //6 * 8 decimals

        uint256 unrealisedUsdcTvl = ILoanManager(loanManager).getAssetsWithUnrealisedLosses(usdc, IERC20Helper(lUSDC).totalSupply())
            * IChainlinkPriceFeed(chainLinkPriceFeed).getUSDCPrice();
        uint256 unrealisedUsdtTvl = ILoanManager(loanManager).getAssetsWithUnrealisedLosses(usdt, IERC20Helper(lUSDT).totalSupply())
            * IChainlinkPriceFeed(chainLinkPriceFeed).getUSDTPrice();

        uint256 totalUnrealisedTvl = unrealisedUsdcTvl + unrealisedUsdtTvl + tvlLiquidAssets;

        nstblToBeMinted =
            (totalUnrealisedTvl * 1e12 - (priceNSTBL * IERC20Helper(nstbl).totalSupply())) / priceNSTBL;

        atvlShare = atvlSharePercent * nstblToBeMinted / 10000;
        

        uint256 stakersYieldThreshold = yieldThreshold * totalStakedAmount/10000;
        if(nstblToBeMinted <= stakersYieldThreshold){
            accNSTBL += (nstblToBeMinted * 1e12) / (lpToken.totalSupply()+atvlStakeAmount);
        }
        else{
            accNSTBL +=  accNSTBLPerShare + (stakersYieldThreshold * 1e12) / (lpToken.totalSupply()+atvlStakeAmount);
            atvlExtra += atvlExtraYield + (nstblToBeMinted - stakersYieldThreshold);
        }

    }

    function stake(uint256 _amount, address _userAddress, int8 _stakeTranche) public authorizedCaller {
        require(_amount > 0, "SP::INVALID AMOUNT");
        StakerInfo storage staker = stakerInfo[_userAddress];
        updatePool();

        IERC20Helper(nstbl).safeTransferFrom(msg.sender, address(this), _amount);
        staker.amount += _amount;
        staker.rewardDebt += (_amount * accNSTBLPerShare) / 1e12;
        staker.stakeTimeStamp = block.timestamp;
        staker.stakeTranche = _stakeTranche;
        totalStakedAmount += _amount;
        lpToken.mint(msg.sender, _amount);
        emit Stake(_userAddress, _amount);
    }

    function unstake(uint256 _amount, address _userAddress) public authorizedCaller {
        require(_amount > 0, "SP::INVALID AMOUNT");

        StakerInfo storage staker = stakerInfo[_userAddress];
        updatePool();
        require(_amount <= staker.amount, "SP::INVALID AMOUNT");

        uint256 pendingNSTBL = ((staker.amount * accNSTBLPerShare) / 1e12) - (staker.rewardDebt);
        uint256 unstakeFee = _getUnstakeFee(staker.stakeTranche, staker.stakeTimeStamp) * staker.amount / 10000;

        staker.rewardDebt -= (_amount * accNSTBLPerShare) / 1e12;
        staker.amount -= _amount;
        totalStakedAmount -= _amount;
        lpToken.burn(msg.sender, _amount);
        IERC20Helper(nstbl).safeTransfer(msg.sender, pendingNSTBL - unstakeFee);
        emit Unstake(_userAddress, _amount);
    }

    function addATVLToStaker(uint256 _amount) public onlyATVL {
        require(_amount > 0, "SP::INVALID AMOUNT");
        StakerInfo storage staker = stakerInfo[atvl];
        updatePool();
        if(!staker.ifATVLStaker)
            staker.ifATVLStaker = true;

        staker.amount += _amount;
        staker.rewardDebt += (_amount * accNSTBLPerShare) / 1e12;
        staker.stakeTimeStamp = block.timestamp;
        totalStakedAmount += _amount;

        atvlStakeAmount += _amount;

    }   

    function removeATVLFromStaker(uint256 _amount) public onlyATVL {
        transferATVLYield();
        StakerInfo storage staker = stakerInfo[atvl];
        staker.amount -= _amount;
        staker.rewardDebt -= (_amount * accNSTBLPerShare) / 1e12;
        totalStakedAmount -= _amount;
        atvlStakeAmount -= _amount;
    }

    //Should this be made non-reentrant?
    function transferATVLYield() public nonReentrant{
        StakerInfo storage staker = stakerInfo[atvl];
        updatePool();
        uint256 accAtvlNSTBL = atvlExtraYield + ((staker.amount * accNSTBLPerShare) / 1e12) - (staker.rewardDebt);
        staker.rewardDebt = (staker.amount * accNSTBLPerShare) / 1e12;
        atvlExtraYield = 0;
        IERC20Helper(nstbl).safeTransfer(atvl, accAtvlNSTBL);

    }
}
