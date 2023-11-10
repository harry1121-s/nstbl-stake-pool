// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { ActorManager } from "./ActorManager.sol";
import { BaseTest } from "../unit/BaseTest.t.sol";
import { HandlerHub } from "./handlers/HandlerHub.t.sol";

contract TestStakePoolInvariant is BaseTest {

    /*//////////////////////////////////////////////////////////////
    Agent handlers
    //////////////////////////////////////////////////////////////*/
    HandlerHub public hub;
    ActorManager public actorManager;

    // Feedback of user addresses for agentHandler 
    address[] public users;

    /*//////////////////////////////////////////////////////////////
    Setup
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        hub = new HandlerHub(address(nstblToken), address(stakePool), address(loanManager), address(this));
        vm.prank(deployer);
        aclManager.setAuthorizedCallerStakePool(address(hub), true);

        // Set weights for user actions
        hub.setSelectorWeight("deposit(uint256)", 100);

        uint256[] memory weightsActorManager = new uint256[](1);
        weightsActorManager[0] = 100; // hub

        address[] memory targetContracts = new address[](1);
        targetContracts[0] = address(hub);

        actorManager = new ActorManager(targetContracts, weightsActorManager);

        targetContract(address(actorManager));
        targetSender(address(0xdeed));

        loanManager.updateInvestedAssets(15e5 * 1e18);
        stakePool.updateMaturyValue();
    }

    function invariant_stakePool() public {

    }

    function numOfUsers() public view returns (uint256) {
        return users.length;
    }


}