pragma solidity 0.8.21;

interface IStakePool {
    /*//////////////////////////////////////////////////////////////
    EVENTS
    //////////////////////////////////////////////////////////////*/

    event Stake(address indexed user, uint256 stakeAmount, uint256 poolDebt);
    event Unstake(address indexed user, uint256 tokensAvailable);

    struct StakerInfo{
        uint256 amount;
        uint256 poolDebt;
        uint256 stakeTimeStamp;
        uint256 epochId;
        uint256 lpTokens;
    }
}
