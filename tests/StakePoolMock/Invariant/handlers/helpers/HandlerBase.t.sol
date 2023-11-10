// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "forge-std/Test.sol";

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";

contract HandlerBase is CommonBase, StdCheats, StdUtils, Test {
    uint256 internal constant WEIGHTS_RANGE = 100;

    uint256 public numCalls;
    uint256 public totalWeight;

    bytes4[] public selectors;

    mapping(bytes4 => uint256) public weights;
    mapping(bytes32 => uint256) public numberOfCalls;

    /*//////////////////////////////////////////////////////////////
    Weighting setters
    //////////////////////////////////////////////////////////////*/

    function setSelectorWeight(string memory functionSignature_, uint256 weight_) external {
        bytes4 selector_ = bytes4(keccak256(bytes(functionSignature_)));

        weights[selector_] = weight_;

        selectors.push(selector_);

        totalWeight += weight_;
    }

    /*//////////////////////////////////////////////////////////////
    Entry point
    //////////////////////////////////////////////////////////////*/

    function entryPoint(uint256 seed_) external {
        require(totalWeight == WEIGHTS_RANGE, "HB:INVALID_WEIGHTS");
        numCalls++;
        uint256 range_;

        uint256 value_ = uint256(keccak256(abi.encodePacked(seed_))) % WEIGHTS_RANGE + 1; // 1 - 100

        for (uint256 i = 0; i < selectors.length; i++) {
            uint256 weight_ = weights[selectors[i]];
            range_ += weight_;

            if (value_ <= range_ && weight_ != 0) {
                (bool success,) = address(this).call(abi.encodeWithSelector(selectors[i], seed_));
                require(success, "HB:CALL_FAILED");
                break;
            }
        }
    }
}
