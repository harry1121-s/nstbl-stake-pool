# Build and test

profile ?=default

build:
	@FOUNDRY_PROFILE=production forge build

test:
	forge test

testToken:
	forge test --match-path ./tests/unit/Token.t.sol

testStakePoolMock:
	forge test --match-path ./tests/StakePoolMock/unit/StakePoolMock.t.sol -vvv 

testStakePool:
	forge test --match-path ./tests/StakePool/unit/StakePool.t.sol -vvvvv 

debug: 
	forge test -vvvvv

clean:
	@forge clean