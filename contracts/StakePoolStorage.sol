pragma solidity 0.8.21;

import "./interfaces/IERC20Helper.sol";
import "./interfaces/ILoanManager.sol";
import "@nstbl-acl-manager/contracts/IACLManager.sol";
import "./IStakePool.sol";

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

    uint64 public earlyUnstakeFee1;
    uint64 public earlyUnstakeFee2;
    uint64 public earlyUnstakeFee3;

    uint256 public accNSTBLPerShare;
    uint256 public burnNSTBLPerShare;
    uint256 public unclaimedRewards;
    // uint256 rewards;

    uint256 public totalStakedAmount;
    uint256 public yieldThreshold;
    uint256 public stakingThreshold;

    uint256 public atvlExtraYield;

    mapping(bytes11 => StakerInfo) public stakerInfo;

    uint256 public oldMaturityVal;
    uint256 public precision = 1e27;
}
