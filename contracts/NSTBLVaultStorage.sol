pragma solidity 0.8.21;

import "./interfaces/IERC20Helper.sol";
import "./ChainlinkPriceFeed.sol";

contract NSTBLVaultStorage {

    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    address public immutable nstbl;
    address public immutable lpToken;
    address public immutable lUSDC;
    address public immutable lUSDT;
    address public immutable usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public immutable usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public immutable loanManager;

    /*//////////////////////////////////////////////////////////////
                        STORAGE : Stake Pool
    //////////////////////////////////////////////////////////////*/
    address public admin;
    address public chainLinkPriceFeed;

    struct StakerInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 stakeTimeStamp;
        int8 stakeTranche;
    }

    uint256 public accNSTBLPerShare;
    uint256 public lastRewardTimeStamp;
    uint256 public totalStakedAmount;
    // uint256 public nstblToBeMinted;

    mapping(address => StakerInfo) public stakerInfo;
    mapping(address => bool) public authorizedCallers;
    mapping(int8 => uint256) public trancheTimePeriods;


}