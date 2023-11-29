// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenLP is ERC20 {
    address public stakePool;
    address public admin;

    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event StakePoolChanged(address indexed oldStakePool, address indexed newStakePool);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier authorizedCaller() {
        require(msg.sender == stakePool, "Token: StakePool unAuth");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Token: Admin unAuth");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory name_, string memory symbol_, address admin_) ERC20(name_, symbol_) {
        require(admin_ != address(0), "LP: invalid Address");
        admin = admin_;
        stakePool = msg.sender;
        emit AdminChanged(address(0), admin);
        emit StakePoolChanged(address(0), stakePool);
    }

    /*//////////////////////////////////////////////////////////////
                        ACCOUNT MINT/BURN
    //////////////////////////////////////////////////////////////*/

    function mint(address user_, uint256 amount_) external authorizedCaller {
        _mint(user_, amount_);
    }

    function burn(address user_, uint256 amount_) external authorizedCaller {
        _burn(user_, amount_);
    }

    /*//////////////////////////////////////////////////////////////
                               OWNERSHIP
    //////////////////////////////////////////////////////////////*/

    function setStakePool(address stakePool_) external onlyAdmin {
        require(stakePool_ != address(0), "LP: invalid Address");
        address oldStakePool = stakePool;
        stakePool = stakePool_;
        emit StakePoolChanged(oldStakePool, stakePool);
    }

    function setAdmin(address admin_) external onlyAdmin {
        require(admin_ != address(0), "LP: invalid Address");
        address oldAdmin = admin;
        admin = admin_;
        emit AdminChanged(oldAdmin, admin);
    }
}
