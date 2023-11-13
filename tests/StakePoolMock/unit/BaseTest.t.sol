// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Helper } from "../../../contracts/interfaces/IERC20Helper.sol";
// import { INSTBLToken } from "../../../contracts/interfaces/INSTBLToken.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "../../../contracts/upgradeable/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "../../../contracts/upgradeable/ProxyAdmin.sol";
import { ACLManager } from "@nstbl-acl-manager/contracts/ACLManager.sol";
import { NSTBLToken } from "@nstbl-token/contracts/NSTBLToken.sol";
import { LZEndpointMock } from "@layerzerolabs/contracts/mocks/LZEndpointMock.sol";
import { NSTBLStakePool } from "../../../contracts/StakePool.sol";
import { LoanManagerMock } from "../../../contracts/mocks/LoanManagerMock.sol";

contract BaseTest is Test {
    using SafeERC20 for IERC20Helper;
    /*//////////////////////////////////////////////////////////////
    Contract instances
    //////////////////////////////////////////////////////////////*/

    // Token setup
    ACLManager public aclManager;
    NSTBLToken public token_src;
    NSTBLToken public token_dst;

    LZEndpointMock public LZEndpoint_src;
    LZEndpointMock public LZEndpoint_dst;

    //Proxy setup
    ProxyAdmin public proxyAdmin;
    TransparentUpgradeableProxy public stakePoolProxy;
    NSTBLStakePool public stakePoolImpl;

    // Staking setup
    NSTBLStakePool public stakePool;
    NSTBLToken public nstblToken;

    // Mocks
    LoanManagerMock public loanManager;
    /*//////////////////////////////////////////////////////////////
    Testing constants
    //////////////////////////////////////////////////////////////*/

    uint16 chainId_src = 1;
    uint16 chainId_dst = 2;

    // Token details
    string public symbol = "NSTBL";
    string public name = "NSTBL Token";
    uint8 public sharedDecimals = 5;

    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /*//////////////////////////////////////////////////////////////
    Addresses for testing
    //////////////////////////////////////////////////////////////*/

    address public owner = vm.addr(123);
    address public deployer = vm.addr(456);
    address public atvl = address(10);
    address public destinationAddress = vm.addr(123_444);

    address public user1 = vm.addr(1);
    address public user2 = vm.addr(2);
    address public user3 = vm.addr(3);
    address public user4 = vm.addr(4);
    address public compliance = vm.addr(5);
    address public MULTISIG = vm.addr(6);
    address public NSTBL_HUB = vm.addr(456);

    /*//////////////////////////////////////////////////////////////
    Setup
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        uint256 mainnetFork = vm.createFork("https://eth-mainnet.g.alchemy.com/v2/CFhLkcCEs1dFGgg0n7wu3idxcdcJEgbW");
        vm.selectFork(mainnetFork);
        // Deploy mock LZEndpoints
        LZEndpoint_src = new LZEndpointMock(chainId_src);
        LZEndpoint_dst = new LZEndpointMock(chainId_dst);

        vm.startPrank(deployer);
        // Deploy ACLManager
        aclManager = new ACLManager();

        // Deploy tokens
        token_src = new NSTBLToken(name, symbol, sharedDecimals, address(LZEndpoint_src), address(aclManager));
        token_dst = new NSTBLToken(name, symbol, sharedDecimals, address(LZEndpoint_dst), address(aclManager));

        // LayerZero configurations
        LZEndpoint_src.setDestLzEndpoint(address(token_dst), address(LZEndpoint_dst));
        LZEndpoint_dst.setDestLzEndpoint(address(token_src), address(LZEndpoint_src));

        bytes memory path_dst = abi.encodePacked(address(token_dst), address(token_src));
        bytes memory path_src = abi.encodePacked(address(token_src), address(token_dst));
        token_src.setTrustedRemote(chainId_dst, path_dst);
        token_dst.setTrustedRemote(chainId_src, path_src);

        token_src.setAuthorizedChain(block.chainid, true);

        // Set authorized caller in ACLManager
        // Token
        aclManager.setAuthorizedCallerToken(NSTBL_HUB, true);
        aclManager.setAuthorizedCallerToken(owner, true);
        aclManager.setAuthorizedCallerBlacklister(compliance, true);
        // StakePool
        aclManager.setAuthorizedCallerStakePool(NSTBL_HUB, true);

        // Deploy StakePool requirements

        loanManager = new LoanManagerMock(owner);
        nstblToken = token_src;

        // Deploy ProxyAdmin
        proxyAdmin = new ProxyAdmin(deployer);
        assertEq(proxyAdmin.owner(), deployer);
        stakePoolImpl = new NSTBLStakePool();
        bytes memory data = abi.encodeCall(
            stakePoolImpl.initialize, (address(aclManager), address(nstblToken), address(loanManager), atvl)
        );
        stakePoolProxy = new TransparentUpgradeableProxy(address(stakePoolImpl), address(proxyAdmin), data);
        stakePool = NSTBLStakePool(address(stakePoolProxy));

        aclManager.setAuthorizedCallerToken(address(stakePoolProxy), true);
        stakePool.setupStakePool([300, 200, 100], [700, 500, 300], [30, 90, 180]);
        loanManager.initializeTime();
        vm.stopPrank();
    }

    function erc20_transfer(address asset_, address account_, address destination_, uint256 amount_) internal {
        vm.startPrank(account_);
        IERC20Helper(asset_).safeTransfer(destination_, amount_);
        vm.stopPrank();
    }

    function _stakeNSTBL(address _user, uint256 _amount, uint8 _trancheId) internal {
        // Add nSTBL balance to NSTBL_HUB
        deal(address(nstblToken), NSTBL_HUB, _amount);
        assertEq(IERC20Helper(address(nstblToken)).balanceOf(NSTBL_HUB), _amount);

        // Action = Stake
        vm.startPrank(NSTBL_HUB);
        nstblToken.sendOrReturnPool(NSTBL_HUB, address(stakePool), _amount);
        stakePool.stake(_user, _amount, _trancheId, destinationAddress);
        vm.stopPrank();
    }

    function _randomizeStakeIdAndIndex(bytes11 _stakeId, uint256 len)
        internal
        view
        returns (bytes11 randomStakeId, uint256 index)
    {
        bytes32 hashedVal = keccak256(abi.encodePacked(_stakeId, block.timestamp));
        randomStakeId = bytes11(hashedVal);
        index = uint256(hashedVal) % len;
        return (randomStakeId, index);
    }
}
