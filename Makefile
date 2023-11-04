# Build and test

profile ?=default

build:
	@FOUNDRY_PROFILE=production forge build

test:
	forge test

testToken:
	forge test --match-path ./tests/unit/Token.t.sol

testStakePoolMock:
	forge test --match-path ./tests/StakePoolMock/unit/StakePoolMock.t.sol -vvv --gas-report

testStakePool:
	forge test --match-path ./tests/StakePool/unit/StakePool.t.sol -vvv

debug: 
	forge test -vvvvv

clean:
	@forge clean