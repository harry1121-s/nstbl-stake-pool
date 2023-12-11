pragma solidity 0.8.21;

import "./interfaces/IERC20Helper.sol";
import "./interfaces/ILoanManager.sol";
import "@nstbl-acl-manager/contracts/IACLManager.sol";
import "./IStakePool.sol";

contract StakePoolStorage {

    /*//////////////////////////////////////////////////////////////
    STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct StakerInfo {
        uint256 amount;
        uint256 poolDebt;
        uint256 stakeTimeStamp;
        uint256 epochId;
    }

    /*//////////////////////////////////////////////////////////////
    IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice address of USDC token
    address public immutable usdc;
    uint256 internal immutable REVISION = 1;

    /*//////////////////////////////////////////////////////////////
    State Variables
    //////////////////////////////////////////////////////////////*/

    /// @notice version of the stake pool
    uint256 public versionSlot;

    /// @notice address of the ACL manager
    address public aclManager;

    /// @notice address of the NSTBL token
    address public nstbl;

    /// @notice address of the loan manager
    address public loanManager;

    /// @notice address of the ATVL
    address public atvl;

    uint256 public genesis;

    // Pool Parameters
    uint256 public poolProduct;
    uint256 public poolBalance;
    uint256 public poolEpochId;
    uint256 public unclaimedRewards;

    uint256 public oldMaturityVal;
    
    /// @notice base fee for tranche 1
    uint32 public trancheBaseFee1;

    /// @notice base fee for tranche 2
    uint32 public trancheBaseFee2;

    /// @notice base fee for tranche 3
    uint32 public trancheBaseFee3;

    /// @notice early unstake fee for tranche 1
    uint32 public earlyUnstakeFee1;

    /// @notice early unstake fee for tranche 2
    uint32 public earlyUnstakeFee2;

    /// @notice early unstake fee for tranche 3
    uint32 public earlyUnstakeFee3;

    /// @notice mapping to store the tranche stake time periods
    mapping(uint8 => uint64) public trancheStakeTimePeriod;

    mapping(uint8 => mapping(address => StakerInfo)) public stakerInfo;

    // add new variables here to extended the storage

    // reduce the gap size equal the size of new variables: to maintain original layout and prevent collision
    uint256[35] __gap;
}
