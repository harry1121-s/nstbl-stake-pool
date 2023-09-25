// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Helper} from "./NSTBLVaultStorage.sol";

contract NSTBLStakePool {
    using SafeERC20 for IERC20Helper;

    modifier onlyAdmin() {
        require(msg.sender == admin, "SP::NOT ADMIN");
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
        address _lpToken,
        address _lUSDC,
        address _lUSDT,
        address _loanManager,
        address _chainLinkPriceFeed
    ) {
        admin = _admin;
        nstbl = _nstbl;
        lpToken = _lpToken;
        lUSDC = _lUSDC;
        lUSDT = _lUSDT;
        loanManager = _loanManager;
        chainLinkPriceFeed = _chainLinkPriceFeed;
        trancheTimePeriods[1] = 90 days;
        trancheTimePeriods[2] = 180 days;
        trancheTimePeriods[3] = 270 days;
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    function _getUnstakeFee(int8 tranche, uint256 timeStamp, uint256 amount) internal returns (uint256 fee) {
        uint256 timeElapsed = block.timestamp - timeStamp;
        if (timeStamp < trancheTimePeriods[tranche]) {
            fee = amount * 5 / 100;
        } else {
            fee = amount;
        }
    }

    function updatePool() public {
        //using 8 decimals for price and standard 6 decimals for amount

        uint256 priceLiquidAssets = ChainlinkPriceFeed(chainLinkPriceFeed).getAverageAssetsPrice();
        uint256 priceNSTBL = (700 * 1e8 + 300 * priceLiquidAssets) / 1000;

        uint256 tvlLiquidAssets = INSTBLVault(nstblVault).getTvlLiquidAssets(); //6 * 8 decimals

        uint256 unrealisedUsdcTvl = ILoanManager(loanManager).getAssetsWithUnrealisedLosses(usdc, lUSDCSupply)
            * ChainlinkPriceFeed(chainLinkPriceFeed).getUSDCPrice();
        uint256 unrealisedUsdtTvl = ILoanManager(loanManager).getAssetsWithUnrealisedLosses(usdt, lUSDTSupply)
            * ChainlinkPriceFeed(chainLinkPriceFeed).getUSDTPrice();

        uint256 totalUnrealisedTvl = unrealisedUsdcTvl + unrealisedUsdtTvl + tvlLiquidAssets;

        uint256 nstblToBeMinted =
            (totalUnrealisedTvl * 1e12 - (priceNSTBL * IERC20Helper(nstbl).totalSupply())) / priceNSTBL;

        IERC20Helper(nstbl).mint(address(this), nstblToBeMinted);

        accNSTBLPerShare += (nstblToBeMinted * 1e12) / (IERC20Helper(lpToken).totalSupply());
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
        totalStaked += _amount;
        IERC20Helper(lpToken).mint(msg.sender, _amount);
        emit Stake(_userAddress, _amount);
    }

    function unstake(uint256 _amount, address _userAddress) public authorizedCaller {
        require(_amount > 0, "SP::INVALID AMOUNT");

        StakerInfo storage staker = stakerInfo[_userAddress];
        updatePool();
        require(_amount <= staker.amount, "SP::INVALID AMOUNT");

        uint256 pendingNSTBL = ((staker.amount * accNSTBLPerShare) / 1e12) - (staker.rewardDebt);
        uint256 unstakeFee = _getUnstakeFee(staker.stakeTranche, staker.stakeTimeStamp, staker.amount);

        staker.rewardDebt -= (_amount * accNSTBLPerShare) / 1e12;
        staker.amount -= _amount;
        totalStaked -= _amount;
        IERC20Helper(lpToken).burn(msg.sender, _amount);
        IERC20Helper(nstbl).safeTransfer(msg.sender, pendingNSTBL - unstakeFee);
        emit UnStake(_userAddress, _amount);
    }
}
