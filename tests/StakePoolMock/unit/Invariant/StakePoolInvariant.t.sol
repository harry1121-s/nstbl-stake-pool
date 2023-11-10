// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { ActorManager } from "./ActorManager.sol";
import { BaseTest } from "../BaseTest.t.sol";

contract TestStakePoolInvariant is BaseTest {

    /*//////////////////////////////////////////////////////////////
    Agent handlers
    //////////////////////////////////////////////////////////////*/

    ActorManager public actorManager;

    // Feedback of user addresses for agentHandler 
    address[] public users;

    /*//////////////////////////////////////////////////////////////
    Setup
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
    }
}