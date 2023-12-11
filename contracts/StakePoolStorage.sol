pragma solidity 0.8.21;

import "./interfaces/IERC20Helper.sol";
import "./interfaces/ILoanManager.sol";
import "@nstbl-acl-manager/contracts/IACLManager.sol";
import "./interfaces/IStakePool.sol";

contract StakePoolStorage {
    struct StakerInfo {
        uint256 amount;
        uint256 poolDebt;
        uint256 stakeTimeStamp;
        uint256 epochId;
    }
    /*//////////////////////////////////////////////////////////////
    IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable usdc;
    uint256 internal immutable REVISION = 1;

    /*//////////////////////////////////////////////////////////////
    STORAGE : Stake Pool
    //////////////////////////////////////////////////////////////*/

    uint256 public versionSlot;
    address public aclManager;
    address public nstbl;
    address public loanManager;
    address public atvl;

    uint256 public genesis;

    mapping(uint8 => mapping(address => StakerInfo)) public stakerInfo;

    uint256 public poolProduct;
    uint256 public poolBalance;
    uint256 public poolEpochId;
    uint256 public unclaimedRewards;

    uint256 public oldMaturityVal;

    uint32 public trancheBaseFee1;
    uint32 public trancheBaseFee2;
    uint32 public trancheBaseFee3;

    uint32 public earlyUnstakeFee1;
    uint32 public earlyUnstakeFee2;
    uint32 public earlyUnstakeFee3;

    mapping(uint8 => uint64) public trancheStakeTimePeriod;

    //add new variables here to extended the storage
    //reduce the gap size equal the size of new variables: to maintain original layout and prevent collision
    uint256[36] __gap;
}
