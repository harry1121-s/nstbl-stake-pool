pragma solidity 0.8.21;

interface IStakePool {
    event Stake(bytes11 indexed stakeId, uint8 trancheId, uint256 amount);
    event Unstake(address indexed user, uint256 amount);

    struct StakerInfo {
        bytes11 stakeId;
        uint8 trancheId;
        address owner;
        uint256 amount;
        uint256 rewardDebt;
        uint256 burnDebt;
        uint256 stakeTimeStamp;
    }
}
