// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { console } from "forge-std/Test.sol";
import { IERC20Helper, ILoanManager, IACLManager, StakePoolStorage } from "./StakePoolStorage.sol";

contract NSTBLStakePool is StakePoolStorage {
    using SafeERC20 for IERC20Helper;

    uint256 private _locked = 1;

    modifier nonReentrant() {
        require(_locked == 1, "P:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    modifier onlyAdmin() {
        require(msg.sender == IACLManager(aclManager).admin(), "SP: unAuth Admin");
        _;
    }

    modifier authorizedCaller() {
        require(IACLManager(aclManager).authorizedCallersStakePool(msg.sender), "SP: unAuth Hub");
        _;
    }

    constructor(address _aclManager, address _nstbl, address _loanManager) 
    // address _chainLinkPriceFeed
    {
        aclManager = _aclManager;
        nstbl = _nstbl;
        loanManager = _loanManager;
    }

    function init(address _atvl, uint256 _yieldThreshold, uint256 _stakingThreshold) external onlyAdmin {
        atvl = _atvl;
        yieldThreshold = _yieldThreshold;
        stakingThreshold = _stakingThreshold;
    }

    function setATVL(address _atvl) external onlyAdmin {
        atvl = _atvl;
    }

    function _getUnstakeFee(uint64 _stakeTimePeriod, uint256 _stakeTimeStamp, uint64 _earlyUnstakeFee, uint8)
        internal
        view
        returns (uint256 fee)
    {
        uint256 timeElapsed = (block.timestamp - _stakeTimeStamp) / 1 days;
        fee = (timeElapsed < _stakeTimePeriod)
            ? (_earlyUnstakeFee * (_stakeTimePeriod - timeElapsed) / _stakeTimePeriod)
            : 0;
    }

    function getUpdatedYieldParams()
        public
        view
        returns (uint256 _usdcInvestedAmount, uint256 _usdcMaturityAmount, uint256 _nstblYield)
    {
        uint256 investedAssets = ILoanManager(loanManager).getInvestedAssets(usdc);
        uint256 maturedAssets = ILoanManager(loanManager).getMaturedAssets(usdc);

        _usdcInvestedAmount = usdcInvestedAmount;
        _usdcMaturityAmount = usdcMaturityAmount;

        if (_usdcInvestedAmount == 0) {
            _nstblYield = maturedAssets - investedAssets;
        } else {
            if (investedAssets > _usdcInvestedAmount) {
                _nstblYield = maturedAssets - _usdcMaturityAmount - (investedAssets - _usdcInvestedAmount);
            } else if (investedAssets < _usdcInvestedAmount) {
                uint256 r = investedAssets * precision / _usdcInvestedAmount;
                _nstblYield = maturedAssets - (r * usdcMaturityAmount / precision);
            } else {
                _nstblYield = maturedAssets - usdcMaturityAmount;
            }
        }
        _usdcMaturityAmount = maturedAssets;
        _usdcInvestedAmount = investedAssets;
    }

    //TODO: get user staked amount + rewards function

    function getAvailableYield() external view returns (uint256 _totalYield) {
        (,, uint256 nstblYield) = getUpdatedYieldParams();
        uint256 atvlBal = IERC20Helper(nstbl).balanceOf(atvl);
        uint256 atvlYield = nstblYield * atvlBal / (totalStakedAmount + atvlBal);

        nstblYield -= atvlYield;
        uint256 stakersYieldThreshold = yieldThreshold * totalStakedAmount / 10_000;

        if (nstblYield <= stakersYieldThreshold) {
            _totalYield = nstblYield;
        } else {
            _totalYield = stakersYieldThreshold;
        }
    }

    // function burnNstbl(uint256 _amount) external authorizedCaller nonReentrant {
    //     console.log("BURN AMOUNT: ", _amount);
    //     updatePools();
    //     PoolInfo storage pool;
    //     uint256 removeFromStakeAmount;
    //     uint256 stakePoolBal = IERC20Helper(nstbl).balanceOf(address(this));
    //     console.log("BURNING");
    //     console.log("Stake Pool Balance: ", stakePoolBal);

    //     require(_amount <= stakePoolBal, "SP:: Burn amount exceeds staked amount");
    //     IERC20Helper(nstbl).burn(address(this), _amount);
    //     console.log("Rewards: ", stakePoolBal-totalStakedAmount);
    //     if(_amount >= stakePoolBal-totalStakedAmount)
    //     {
    //         removeFromStakeAmount = (_amount - (stakePoolBal-totalStakedAmount));
    //         for(uint256 i = 0; i < poolInfo.length; i++)
    //         {
    //             poolInfo[i].unclaimedRewards = 0;
    //         }

    //     }
    //     else {
    //         removeFromStakeAmount = 0;
    //     }
    //     console.log("Remove From Stake Amount: ", removeFromStakeAmount);

    //     for (uint256 i = 0; i < poolInfo.length; i++) {
    //         pool = poolInfo[i];
    //         pool.stakeAmount -= (removeFromStakeAmount) * pool.stakeAmount / totalStakedAmount;
    //         pool.burnNSTBLPerShare += (_amount * 1e18 / totalStakedAmount);
    //         console.log("Burn NSTBL Per Share: ", pool.burnNSTBLPerShare);
    //         console.log("Stake Amount: ", pool.stakeAmount);
    //     }
    //     totalStakedAmount -= removeFromStakeAmount;
    //     console.log("Total Staked Amount: ", totalStakedAmount);
    //     console.log("Pool Balance", IERC20Helper(nstbl).balanceOf(address(this)));
    //     console.log("END BURNING");

    // }

    function updatePools() public {
        uint256 nstblYield;
        (usdcInvestedAmount, usdcMaturityAmount, nstblYield) = getUpdatedYieldParams();
        if (nstblYield == 0) {
            return;
        }
        uint256 atvlBal = IERC20Helper(nstbl).balanceOf(atvl);
        uint256 atvlYield = nstblYield * atvlBal / (totalStakedAmount + atvlBal);

        nstblYield -= atvlYield;
        IERC20Helper(nstbl).mint(address(this), nstblYield);
        IERC20Helper(nstbl).mint(atvl, atvlYield);
        console.log("NSTBL YIELD: ", nstblYield);
        console.log("ATVL YIELD: ", atvlYield);
        nstblYield *= 1e18;
        uint256 stakersYieldThreshold = yieldThreshold * totalStakedAmount * 1e18 / 10_000;
        uint256 rewards;
        if (nstblYield <= stakersYieldThreshold) {
            rewards = nstblYield;
        } else {
            rewards = stakersYieldThreshold;
            atvlExtraYield += (nstblYield - stakersYieldThreshold);
        }

        if (totalStakedAmount == 0) {
            unclaimedRewards += rewards / 1e18;
            return;
        }
        accNSTBLPerShare = rewards / totalStakedAmount;
        console.log("END UPDATE");
    }

    // function getUnclaimedRewards() external view returns (uint256 _unclaimedRewards) {
    //     PoolInfo memory pool;
    //     for (uint256 i = 0; i < poolInfo.length; i++) {
    //         pool = poolInfo[i];
    //         _unclaimedRewards += pool.unclaimedRewards;
    //     }
    //     _unclaimedRewards /= 1e18;
    // }

    // function withdrawUnclaimedRewards() external authorizedCaller {
    //     uint256 unclaimedRewards;
    //     PoolInfo storage pool;
    //     for (uint256 i = 0; i < poolInfo.length; i++) {
    //         pool = poolInfo[i];
    //         unclaimedRewards += pool.unclaimedRewards;
    //         pool.unclaimedRewards = 0;
    //     }
    //     unclaimedRewards /= 1e18;
    //     IERC20Helper(nstbl).safeTransfer(msg.sender, unclaimedRewards);
    // }

    function stake(uint256 amount, uint8 trancheId, bytes11 stakeId) public authorizedCaller nonReentrant {
        console.log("Stake AMount: ", amount);
        uint256 a1;
        uint256 a2;
        StakerInfo storage staker = stakerInfo[stakeId];

        if (totalStakedAmount != 0) {
            updatePools();
            console.log("HERE");
        }

        IERC20Helper(nstbl).safeTransferFrom(msg.sender, address(this), amount);

        if (staker.amount > 0) {
            console.log("HERE2");
            a1 = staker.burnDebt + (staker.amount * accNSTBLPerShare / 1e18);
            a2 = (staker.amount * burnNSTBLPerShare / 1e18) + (staker.rewardDebt);
            totalStakedAmount += ((staker.amount * accNSTBLPerShare / 1e18) - staker.rewardDebt);
            staker.amount = (staker.amount + a1) - a2;
        } else {
            staker.owner = msg.sender;
            staker.trancheId = trancheId;
            staker.stakeId = stakeId;
        }
        // console.log("HERE3");

        staker.amount += amount;
        staker.rewardDebt = (staker.amount * accNSTBLPerShare) / 1e18;
        staker.burnDebt = (staker.amount * burnNSTBLPerShare) / 1e18;
        staker.stakeTimeStamp = block.timestamp;
        totalStakedAmount += amount;
        emit Stake(stakeId, trancheId, amount);
    }

    function unstake(address _userAddress, uint256 _poolId, bool _depeg) public authorizedCaller {
        require(_poolId < poolInfo.length, "SP::INVALID POOL");
        console.log("UNSTAKING--------------");
        StakerInfo storage staker = stakerInfo[_poolId][_userAddress];
        PoolInfo storage pool = poolInfo[_poolId];
        uint256 unstakeFee;
        updatePools();

        uint256 timeElapsed = (block.timestamp - staker.stakeTimeStamp) / 1 days;
        uint256 a1 = staker.burnDebt + (staker.amount * pool.accNSTBLPerShare / 1e18);
        uint256 a2 = (staker.amount * pool.burnNSTBLPerShare / 1e18) + (staker.rewardDebt);
        uint256 tokensAvailable = staker.amount + a1 - a2;
        console.log(staker.amount, a1, a2);
        console.log("Tokens Available: ", tokensAvailable);
        console.log("TIMES: ", timeElapsed, pool.stakeTimePeriod);
        if (!_depeg) {
            if (timeElapsed <= pool.stakeTimePeriod + 1 ) {
                console.log("Early Unstakingggggg");
                unstakeFee = _getUnstakeFee(pool.stakeTimePeriod, staker.stakeTimeStamp, pool.earlyUnstakeFee)
                    * (tokensAvailable) / 100_000;

            } else {
                //restake
                console.log("Restakingggggg");
                pool.stakeAmount -= staker.amount;
                totalStakedAmount -= staker.amount;
                staker.amount = tokensAvailable;
                pool.stakeAmount += tokensAvailable;
                totalStakedAmount += tokensAvailable;
                staker.rewardDebt = (staker.amount * pool.accNSTBLPerShare) / 1e18;
                staker.burnDebt = (staker.amount * pool.burnNSTBLPerShare) / 1e18;
                staker.stakeTimeStamp = block.timestamp;
                return;
            }
        } else {
            unstakeFee = 0;
        }

        if(_depeg || timeElapsed <= pool.stakeTimePeriod + 1 )
        {
            console.log("Final Unstakingggggg");
            pool.stakeAmount -= staker.amount;
            totalStakedAmount -= staker.amount;
            staker.amount = 0;
            staker.rewardDebt = 0;
            staker.burnDebt = 0;

            IERC20Helper(nstbl).safeTransfer(msg.sender, tokensAvailable - unstakeFee);
            IERC20Helper(nstbl).safeTransfer(atvl, unstakeFee);
        }

    }

    function transferATVLYield(uint256 _poolId) public nonReentrant {
        IERC20Helper(nstbl).safeTransfer(atvl, atvlExtraYield);
        atvlExtraYield = 0;
    }
}
