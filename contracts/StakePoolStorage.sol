pragma solidity 0.8.21;

import "./interfaces/IERC20Helper.sol";
import "./interfaces/ILoanManager.sol";
import "@nstbl-acl-manager/contracts/IACLManager.sol";
import "./IStakePool.sol";
import "./TokenLP.sol";

contract StakePoolStorage is IStakePool {
    
    /*//////////////////////////////////////////////////////////////
    IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    address public immutable nstbl;
    address public immutable usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public immutable loanManager;

    /*//////////////////////////////////////////////////////////////
    STORAGE : Stake Pool
    //////////////////////////////////////////////////////////////*/

    address public aclManager;
    address public atvl;

    uint64 public trancheFee1;
    uint64 public trancheFee2;
    uint64 public trancheFee3;

    TokenLP public lpToken;

    mapping(uint8 => mapping(address => StakerInfo)) public stakerInfo;

    uint256 public poolProduct = 1e18;
    uint256 public poolBalance;
    uint256 public poolEpochId;
    uint256 public unclaimedRewards;

    uint256 public yieldThreshold = 285_388_127; //9% APY
    // uint256 public stakingThreshold;

    uint256 public atvlExtraYield;

    // mapping(bytes11 => StakerInfo) public stakerInfo;

    uint256 public oldMaturityVal;
    // uint256 public precision = 1e27;
    uint256 public trancheBaseFee1;
    uint256 public trancheBaseFee2;
    uint256 public trancheBaseFee3;

    uint256 public earlyUnstakeFee1;
    uint256 public earlyUnstakeFee2;
    uint256 public earlyUnstakeFee3;

    mapping(uint8 => uint64) public trancheStakeTimePeriod;
}
