pragma solidity 0.8.21;

interface IStakePool {

    /*//////////////////////////////////////////////////////////////
    Events
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emitted when a user stakes tokens
     * @param user_ Address of the user
     * @param stakeAmount_ Amount of tokens staked
     * @param poolDebt_ Amount of tokens owed to the pool
     * @param epochId_ Epoch ID of the stake
     */
    event Stake(address indexed user_, uint256 stakeAmount_, uint256 poolDebt_, uint256 epochId_);

    /**
     * @dev Emitted when a user unstakes tokens
     * @param user_ Address of the user
     * @param maturityTokens_ Amount of tokens matured
     * @param unstakeFee_ Total amount of fees paid
     */
    event Unstake(address indexed user_, uint256 maturityTokens_, uint256 unstakeFee_);

    /**
     * @dev Emitted to initalize the stake pool
     * @param version_ Version of the stake pool
     * @param aclManager_ Address of the ACL manager
     * @param nstblToken_ Address of the NSTBL token
     * @param loanManager_ Address of the loan manager
     * @param atvl_ Address of the ATVL
     */
    event StakePoolInitialized(
        uint256 version_, address aclManager_, address nstblToken_, address loanManager_, address atvl_
    );

    /**
     * @dev Emitted to setup the tranche stake time periods
     * @param trancheStakeTimePeriod1_ tranche stake time period 1
     * @param trancheStakeTimePeriod2_ tranche stake time period 2
     * @param trancheStakeTimePeriod3_ tranche stake time period 3
     */
    event TrancheStakeTimePeriodUpdated(
        uint64 trancheStakeTimePeriod1_, uint64 trancheStakeTimePeriod2_, uint64 trancheStakeTimePeriod3_
    );

    /**
     * @dev Emitted to setup the tranche base fee
     * @param trancheBaseFee1_ base fee for tranche 1
     * @param trancheBaseFee2_ base fee for tranche 2
     * @param trancheBaseFee3_ base fee for tranche 3
     */
    event TrancheBaseFeeUpdated(uint64 trancheBaseFee1_, uint64 trancheBaseFee2_, uint64 trancheBaseFee3_);

    /**
     * @dev Emitted to setup the tranche early unstake fee
     * @param earlyUnstakeFee1_ early unstake fee for tranche 1
     * @param earlyUnstakeFee2_ early unstake fee for tranche 2
     * @param earlyUnstakeFee3_ early unstake fee for tranche 3
     */
    event TrancheEarlyUnstakeFeeUpdated(uint64 earlyUnstakeFee1_, uint64 earlyUnstakeFee2_, uint64 earlyUnstakeFee3_);

    /**
     * @dev Emitted when the ATVL is updated
     * @param atvl_ Address of the ATVL
     */
    event ATVLUpdated(address atvl_);

    /**
     * @dev Emitted when the pool is updated from the hub
     * @param poolProduct_ Product of the pool
     * @param poolBalance_ Balance of the pool
     * @param nstblYield_ Total NSTBL yield
     * @param atvlYield_ Total yield transferred to the ATVL
     */
    event UpdatedFromHub(uint256 poolProduct_, uint256 poolBalance_, uint256 nstblYield_, uint256 atvlYield_);

    /**
     * @dev Emitted when the unclaimed rewards are withdrawn
     * @param user_ Address of the user
     * @param amount_ Amount of tokens withdrawn
     */
    event UnclaimedRewardsWithdrawn(address indexed user_, uint256 amount_);

    /**
     * @dev Emitted when the NSTBL Token is burned
     * @param amount_ Amount of tokens burned
     * @param poolProduct_ Product of the pool updated
     * @param poolBalance_ Balance of the pool updated
     * @param poolEpochId_ Epoch ID of the pool updated
     */
    event NSTBLBurned(uint256 amount_, uint256 poolProduct_, uint256 poolBalance_, uint256 poolEpochId_);

    /*//////////////////////////////////////////////////////////////
    Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Initializes the stake pool
     * @param aclManager_ Address of the ACL manager
     * @param nstbl_ Address of the NSTBL token
     * @param loanManager_ Address of the loan manager
     * @param atvl_ Address of the ATVL
     */
    function initialize(address aclManager_, address nstbl_, address loanManager_, address atvl_) external;

    /**
     * @dev Sets up the tranche fee, unstake fee, and stake time periods
     * @param trancheBaseFee_ Base fee for each tranche
     * @param earlyUnstakeFee_ Early unstake fee for each tranche
     * @param stakeTimePeriods_ Stake time period for each tranche
     */
    function setupStakePool(
        uint16[3] memory trancheBaseFee_,
        uint16[3] memory earlyUnstakeFee_,
        uint8[3] memory stakeTimePeriods_
    ) external;

    /**
     * @dev Sets the ATVL address
     * @param atvl_ Address of the ATVL
     */
    function setATVL(address atvl_) external;

    /**
     * @dev Updates the pool from the hub
     * @param redeem_ Whether or not to redeem the nSTBL tokens
     * @param stablesReceived_ Amount of stables received
     * @param depositAmount_ Amount of tokens deposited
     */
    function updatePoolFromHub(bool redeem_, uint256 stablesReceived_, uint256 depositAmount_) external;

    /**
     * @dev Preview the updated pool
     * @return The yield of the pool
     */
    function previewUpdatePool() external view returns (uint256);

    /**
     * @dev Gets the user's available tokens
     * @param user_ Address of the user
     * @param trancheId_ Tranche ID of the user
     * @return The user's available tokens
     */
    function getUserAvailableTokens(address user_, uint8 trancheId_) external view returns (uint256);

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
     * @param amount_ Amount of tokens to burn
     */
    function burnNSTBL(uint256 amount_) external;

    /**
     * @dev Stakes the user's tokens
     * @param user_ Address of the user
     * @param stakeAmount_ Amount of tokens to stake
     * @param trancheId_ Tranche ID of the user
     */
    function stake(address user_, uint256 stakeAmount_, uint8 trancheId_) external;

    /**
     * @dev Unstakes the user's tokens
     * @param user_ Address of the user
     * @param trancheId_ Tranche ID of the user
     * @param depeg_ Whether the tokens are depeg or not
     * @param destinationAddress_ receiver address
     * @return tokensUnstaked_ Amount of tokens unstaked
     */
    function unstake(address user_, uint8 trancheId_, bool depeg_, address destinationAddress_)
        external
        returns (uint256 tokensUnstaked_);

    /**
     * @dev Gets the user's staker info
     * @param user_ Address of the user
     * @param trancheId_ Tranche ID of the user
     * @return amount_ Amount of tokens staked by the user
     * @return poolDebt_ Amount of tokens owed to the pool
     * @return epochId_ Epoch ID of the stake
     * @return stakerTimeStamp_ Timestamp of the stake
     */
    function getStakerInfo(address user_, uint8 trancheId_)
        external
        view
        returns (uint256 amount_, uint256 poolDebt_, uint256 epochId_, uint256 stakerTimeStamp_);

    /**
     * @dev Gets the unstake fee for the user
     * @param trancheId_ Tranche ID of the user
     * @param stakeTimeStamp_ timestamp when the user staked NSTBL
     * @return fee_ calculated unstake fee based upon tranche and time-elapsed
     */
    function getUnstakeFee(uint8 trancheId_, uint256 stakeTimeStamp_) external view returns (uint256 fee_);

    /**
     * @dev Gets the current implementation version
     * @return version_ The current implementation version
     */
    function getVersion() external pure returns (uint256 version_);
}
