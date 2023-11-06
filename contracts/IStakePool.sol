pragma solidity 0.8.21;

interface IStakePool {
    /*//////////////////////////////////////////////////////////////
    EVENTS
    //////////////////////////////////////////////////////////////*/

    event Stake(address indexed user, uint256 stakeAmount, uint256 poolDebt, uint8 trancheId);
    event Unstake(address indexed user, uint256 tokensAvailable, uint8 trancheId);

    struct StakerInfo{
        uint256 amount;
        uint256 poolDebt;
        uint256 stakeTimeStamp;
        uint8 trancheId;
    }
}
