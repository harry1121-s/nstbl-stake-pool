// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;
import "./TokenLPMock.sol";
contract LoanManagerMock {
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    uint256 public interest = 126840;
    uint256 public startTime;
    TokenLPMock public lUSDC;
    TokenLPMock public lUSDT;
    constructor(address _admin) {
        lUSDC = new TokenLPMock("Loan Manager USDC", "lUSDC", _admin);
        lUSDT = new TokenLPMock("Loan Manager USDT", "lUSDT", _admin);
    }
    function initializeTime() external {
        startTime = block.timestamp;
    }
    function getAssetsWithUnrealisedLosses(address _asset, uint256 _lpTokens)
        external
        view
        returns (uint256)
    {
    
        return (((_lpTokens / 10 ** 12)*(block.timestamp - startTime) * interest) / 10**14);
        
    }

}
