pragma solidity 0.8.21;

import "./interfaces/IERC20Helper.sol";
import "./interfaces/ILoanManager.sol";
import "@nstbl-acl-manager//contracts/ACLManager.sol";


contract StakePoolStorage {
    event Stake(address indexed user, uint256 amount, uint256 rewards, uint256 burn);
    event Unstake(address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    address public immutable nstbl;
    address public immutable usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public immutable loanManager;
    /*//////////////////////////////////////////////////////////////
                        STORAGE : Stake Pool
    //////////////////////////////////////////////////////////////*/

    address public admin;
    address public aclManager;

    struct StakerInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 burnDebt;
        uint256 stakeTimeStamp;
    }

    struct PoolInfo {
        uint256 accNSTBLPerShare;
        uint64 allocPoint;
        uint64 stakeTimePeriod;
        uint64 earlyUnstakeFee;
        uint256 unclaimedRewards;
        uint256 rewards;
        uint256 stakeAmount;
        uint256 burnNSTBLPerShare;
    }

    uint256 public totalStakedAmount;
    uint256 public yieldThreshold;
    uint256 public stakingThreshold;

    address public atvl;
    uint256 public atvlStakeAmount;
    uint256 public atvlRewardDebt;
    uint256 public atvlExtraYield;

    mapping(uint256 => mapping(address => StakerInfo)) public stakerInfo;
    PoolInfo[] public poolInfo;
    uint256 public totalAllocPoint;

    mapping(int8 => uint256) public trancheTimePeriods;
    mapping(int8 => uint256) public trancheFee;
    mapping(int8 => uint256) public trancheBaseFee;

    uint256 public usdcInvestedAmount;
    uint256 public usdcMaturityAmount;
    uint256 public precision = 1e27;
}
