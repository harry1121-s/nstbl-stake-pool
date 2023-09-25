// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import "./interfaces/IERC20Helper.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ChainlinkPriceFeed.sol";

contract NSTBLStakePool {

    address public admin;
    address public immutable nstbl;
    address public immutable lpToken;
    address public immutable lUSDC;
    address public immutable lUSDT;
    address public immutable usdc;
    address public immutable usdt;
    address public immutable loanManager;
    address public chainLinkPriceFeed;
    uint256 initialUsdcInMapleCash;
    uint256 initialUsdtInMapleCash;

    struct StakerInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    uint256 public accNSTBLPerShare;
    uint256 public lastRewardTimeStamp;
    uint256 public totalStakedAmount;
    // uint256 public nstblToBeMinted;

    modifier onlyAdmin() {
        require(msg.sender == admin, "SP::NOT ADMIN");
        _;
    }

    modifier authorizedCaller {
        require(authorizedCallers[msg.sender], "SP::NOT AUTHORIZED");
        _;
    }

    /// @notice Info of each user that stakes NSTBL tokens.
    mapping (address => StakerInfo) public stakerInfo;

    mapping (address => bool) public authorizedCallers;

    function setAuthorizedCaller(address _caller, bool _isAuthorized) external onlyAdmin {
        authorizedCallers[_caller] = _isAuthorized;
    }

    function init(address _nstbl, address _lpToken) external onlyAdmin {
        require(_nstbl != address(0), "SP::INVALID NSTBL ADDRESS");
        require(_lpToken != address(0), "SP::INVALID LP TOKEN ADDRESS");
        nstbl = _nstbl;
        lpToken = _lpToken;
        initialUsdcInMapleCash = INSTBLVault(nstblVault).usdcInMapleCash();
        initialUsdtInMapleCash = INSTBLVault(nstblVault).usdtInMapleCash();
    }

    function updatePool() public {

        //using 8 decimals for price and standard 6 decimals for amount

        uint256 priceLiquidAssets = ChainlinkPriceFeed(chainLinkPriceFeed).getAverageAssetsPrice();
        uint256 priceNSTBL = (700 * 1e8 + 300 * priceLiquidAssets)/1000;

        uint256 tvlLiquidAssets = INSTBLVault(nstblVault).getTvlLiquidAssets(); //6 * 8 decimals
        
        uint256 unrealisedUsdcTvl = ILoanManager(loanManager).getAssetsWithUnrealisedLosses(usdc, lUSDCSupply) * ChainlinkPriceFeed(chainLinkPriceFeed).getUSDCPrice();
        uint256 unrealisedUsdtTvl = ILoanManager(loanManager).getAssetsWithUnrealisedLosses(usdt, lUSDTSupply) * ChainlinkPriceFeed(chainLinkPriceFeed).getUSDTPrice();

        uint256 totalUnrealisedTvl = unrealisedUsdcTvl + unrealisedUsdtTvl + tvlLiquidAssets;

        uint256 nstblToBeMinted = (totalUnrealisedTvl*1e12 - (priceNSTBL * IERC20Helper(nstbl).totalSupply()))/priceNSTBL;

        IERC20Helper(nstbl).mint(address(this), nstblToBeMinted);

        accNSTBLPerShare = accNSTBLPerShare.add(nstblToBeMinted.mul(1e12).div(IERC20Helper(lpToken).totalSupply()));
        
    }

    function stake(uint256 _amount, address _userAddress) public authorizedCaller {
        require(_amount > 0, "SP::INVALID AMOUNT");
        StakerInfo storage staker = stakerInfo[_userAddress];
        updatePool();

        
        SafeERC20.safeTransferFrom(IERC20Helper(nstbl), msg.sender, address(this), _amount);
        staker.amount += _amount;
        staker.rewardDebt = staker.amount.mul(accNSTBLPerShare).div(1e12);
        totalStaked += _amount;
    }

}