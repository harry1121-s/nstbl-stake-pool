// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { ActorManager } from "./ActorManager.sol";
import { BaseTest } from "../unit/BaseTest.t.sol";
import { HandlerHub } from "./handlers/HandlerHub.t.sol";
import { HandlerStaker } from "./handlers/HandlerStaker.t.sol";

contract TestStakePoolInvariant is BaseTest {
    /*//////////////////////////////////////////////////////////////
    Agent handlers
    //////////////////////////////////////////////////////////////*/
    HandlerHub public hub;
    HandlerStaker public staker1;
    HandlerStaker public staker2;
    ActorManager public actorManager;

    // Feedback of user addresses for agentHandler
    address[] public users;

    /*//////////////////////////////////////////////////////////////
    Setup
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        hub = new HandlerHub(address(nstblToken), address(stakePool), address(loanManager), address(this), atvl);
        staker1 = new HandlerStaker(address(nstblToken), address(stakePool), address(loanManager), address(this), atvl);

        vm.startPrank(deployer);
        aclManager.setAuthorizedCallerStakePool(address(hub), true);
        aclManager.setAuthorizedCallerStakePool(address(staker1), true);
        vm.stopPrank();

        // Set weights for user actions
        // hub.setSelectorWeight("deposit(uint256)", 50);
        // hub.setSelectorWeight("redeemMaple(uint256)", 50);
        // hub.setSelectorWeight("burnNSTBL(uint256)", 100);

        staker1.setSelectorWeight("stake(uint256)", 50);
        staker1.setSelectorWeight("unstake(uint256)", 50);

        uint256[] memory weightsActorManager = new uint256[](1);
        // weightsActorManager[0] = 100; // hub
        weightsActorManager[0] = 100; // staker1

        address[] memory targetContracts = new address[](1);
        // targetContracts[0] = address(hub);
        targetContracts[0] = address(staker1);

        actorManager = new ActorManager(targetContracts, weightsActorManager);

        targetContract(address(actorManager));
        targetSender(address(0xdeed));

        loanManager.updateInvestedAssets(15e5 * 1e18);
        vm.prank(NSTBL_HUB);
        stakePool.updateMaturityValue();
    }

    function invariant_stakePool() public { }

    function numOfUsers() public view returns (uint256) {
        return users.length;
    }
}
