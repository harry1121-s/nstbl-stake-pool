pragma solidity 0.8.21;

interface IStakePool {
    /*//////////////////////////////////////////////////////////////
    EVENTS
    //////////////////////////////////////////////////////////////*/

    event Stake(address indexed user, uint256 stakeAmount, uint256 poolDebt, uint256 epochId, uint256 lpTokens);
    event Unstake(address indexed user, uint256 maturityTokens, uint256 unstakeFee);
    event StakePoolInitialized(
        uint256 version, address aclManager, address nstblToken, address loanManager, address atvl, address lpToken
    );
    event StakePoolSetup(
        uint64 trancheStakeTimePeriod1,
        uint64 trancheStakeTimePeriod2,
        uint64 trancheStakeTimePeriod3
    );
    event ATVLUpdated(address atvl);
    event UpdatedFromHub(uint256 poolProduct, uint256 poolBalance, uint256 nstblYield, uint256 atvlYield);
    event UnclaimedRewardsWithdrawn(address indexed user, uint256 amount);
    event NSTBLBurned(uint256 amount, uint256 poolProduct, uint256 poolBalance, uint256 poolEpochId);

    struct StakerInfo {
        uint256 amount;
        uint256 poolDebt;
        uint256 stakeTimeStamp;
        uint256 epochId;
        uint256 lpTokens;
    }
}
