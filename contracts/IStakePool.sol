pragma solidity 0.8.21;

interface IStakePool {
    /*//////////////////////////////////////////////////////////////
    EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emitted when a user stakes tokens
     * @param user Address of the user
     * @param stakeAmount Amount of tokens staked
     * @param poolDebt Amount of tokens owed to the pool
     * @param epochId Epoch ID of the stake
     * @param lpTokens Amount of LP tokens minted
     */
    event Stake(address indexed user, uint256 stakeAmount, uint256 poolDebt, uint256 epochId, uint256 lpTokens);

    /**
     * @dev Emitted when a user unstakes tokens
     * @param user Address of the user
     * @param maturityTokens Amount of tokens matured
     * @param unstakeFee Total amount of fees paid
     */
    event Unstake(address indexed user, uint256 maturityTokens, uint256 unstakeFee);

    /**
     * @dev Emitted to initalize the stake pool
     * @param version Version of the stake pool
     * @param aclManager Address of the ACL manager
     * @param nstblToken Address of the NSTBL token
     * @param loanManager Address of the loan manager
     * @param atvl Address of the ATVL
     * @param lpToken Address of the LP token
     */
    event StakePoolInitialized(
        uint256 version, address aclManager, address nstblToken, address loanManager, address atvl, address lpToken
    );

    /**
     * @dev Emitted to setup the tranche fee, unstake fee, and stake time periods
     * @param trancheStakeTimePeriod1 tranche stake time period 1
     * @param trancheStakeTimePeriod2 tranche stake time period 2
     * @param trancheStakeTimePeriod3 tranche stake time period 3
     */
    event StakePoolSetup(
        uint64 trancheStakeTimePeriod1, uint64 trancheStakeTimePeriod2, uint64 trancheStakeTimePeriod3
    );

    /**
     * @dev Emitted when the ATVL is updated
     * @param atvl Address of the ATVL
     */
    event ATVLUpdated(address atvl);

    /**
     * @dev Emitted when the pool is updated from the hub
     * @param poolProduct Product of the pool
     * @param poolBalance Balance of the pool
     * @param nstblYield Total NSTBL yield
     * @param atvlYield Total yield transferred to the ATVL
     */
    event UpdatedFromHub(uint256 poolProduct, uint256 poolBalance, uint256 nstblYield, uint256 atvlYield);

    /**
     * @dev Emitted when the unclaimed rewards are withdrawn
     * @param user Address of the user
     * @param amount Amount of tokens withdrawn
     */
    event UnclaimedRewardsWithdrawn(address indexed user, uint256 amount);

    /**
     * @dev Emitted when the NSTBL Token is burned
     * @param amount Amount of tokens burned
     * @param poolProduct Product of the pool updated
     * @param poolBalance Balance of the pool updated
     * @param poolEpochId Epoch ID of the pool updated
     */
    event NSTBLBurned(uint256 amount, uint256 poolProduct, uint256 poolBalance, uint256 poolEpochId);

    /**
     * @dev Initializes the stake pool
     * @param _aclManager Address of the ACL manager
     * @param _nstbl Address of the NSTBL token
     * @param _loanManager Address of the loan manager
     * @param _atvl Address of the ATVL
     */
    function initialize(address _aclManager, address _nstbl, address _loanManager, address _atvl) external;

    /**
     * @dev Sets up the tranche fee, unstake fee, and stake time periods
     * @param trancheBaseFee Base fee for each tranche
     * @param earlyUnstakeFee Early unstake fee for each tranche
     * @param stakeTimePeriods Stake time period for each tranche
     */
    function setupStakePool(
        uint16[3] memory trancheBaseFee,
        uint16[3] memory earlyUnstakeFee,
        uint8[3] memory stakeTimePeriods
    ) external;

    /**
     * @dev Sets the ATVL address
     * @param _atvl Address of the ATVL
     */
    function setATVL(address _atvl) external;

    /**
     * @dev Updates the pool from the hub
     * @param redeem Whether or not to redeem the nSTBL tokens
     * @param stablesReceived Amount of stables received
     * @param depositAmount Amount of tokens deposited
     */
    function updatePoolFromHub(bool redeem, uint256 stablesReceived, uint256 depositAmount) external;

    /**
     * @dev Preview the updated pool
     * @return The yield of the pool
     */
    function previewUpdatePool() external view returns (uint256);

    /**
     * @dev Gets the user's available tokens
     * @param _user Address of the user
     * @param _trancheId Tranche ID of the user
     * @return The user's available tokens
     */
    function getUserAvailableTokens(address _user, uint8 _trancheId) external view returns (uint256);

    /**
     * @dev Updates the old maturity value
     * @dev called once from the hub
     */
    function updateMaturityValue() external;

    /**
     * @dev Transfer the unclaimed rewards to the user
     */
    function withdrawUnclaimedRewards() external;

    /**
     * @dev Burns the nSTBL tokens
     * @param _amount Amount of tokens to burn
     */
    function burnNSTBL(uint256 _amount) external;

    /**
     * @dev Stakes the user's tokens
     * @param user Address of the user
     * @param stakeAmount Amount of tokens to stake
     * @param trancheId Tranche ID of the user
     * @param destinationAddress Address of the destination at which tokens are minted
     */
    function stake(address user, uint256 stakeAmount, uint8 trancheId, address destinationAddress) external;

    /**
     * @dev Unstakes the user's tokens
     * @param user Address of the user
     * @param trancheId Tranche ID of the user
     * @param depeg Whether the tokens are depeg or not
     * @param lpOwner Address of the LP tokens owner
     * @return _tokensUnstaked Amount of tokens unstaked
     */
    function unstake(address user, uint8 trancheId, bool depeg, address lpOwner)
        external
        returns (uint256 _tokensUnstaked);

    /**
     * @dev Gets the user's staker info
     * @param user Address of the user
     * @param trancheId Tranche ID of the user
     * @return _amount Amount of tokens staked by the user
     * @return _poolDebt Amount of tokens owed to the pool
     * @return _epochId Epoch ID of the stake
     * @return _lpTokens Amount of LP tokens minted
     * @return _stakerTimeStamp Timestamp of the stake
     */
    function getStakerInfo(address user, uint8 trancheId)
        external
        view
        returns (uint256 _amount, uint256 _poolDebt, uint256 _epochId, uint256 _lpTokens, uint256 _stakerTimeStamp);

    /**
     * @dev Gets the current implementation version
     * @return _version The current implementation version
     */
    function getVersion() external pure returns (uint256 _version);
}
