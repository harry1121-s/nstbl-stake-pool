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
    address public immutable usdc;
    uint256 internal immutable REVISION = 1;

    /*//////////////////////////////////////////////////////////////
    STORAGE : Stake Pool
    //////////////////////////////////////////////////////////////*/

    address public versionSlot;
    address public aclManager;
    address public nstbl;
    address public loanManager;
    address public atvl;

    uint256 public genesis;

    uint64 public trancheFee1;
    uint64 public trancheFee2;
    uint64 public trancheFee3;

    TokenLP public lpToken;

    mapping(uint8 => mapping(address => StakerInfo)) public stakerInfo;

    uint256 public poolProduct;
    uint256 public poolBalance;
    uint256 public poolEpochId;
    uint256 public unclaimedRewards;

    uint256 public yieldThreshold; //9% APY
    // uint256 public stakingThreshold;

    uint256 public atvlExtraYield;

    // mapping(bytes11 => StakerInfo) public stakerInfo;

    uint256 public oldMaturityVal;
    // uint256 public precision = 1e27;
    uint32 public trancheBaseFee1;
    uint32 public trancheBaseFee2;
    uint32 public trancheBaseFee3;

    uint32 public earlyUnstakeFee1;
    uint32 public earlyUnstakeFee2;
    uint32 public earlyUnstakeFee3;

    mapping(uint8 => uint64) public trancheStakeTimePeriod;

    //add new variables here to extended the storage
    //reduce the gap size equal the size of new variables: to maintain original layout and prevent collision
    uint256[33] __gap;
}
