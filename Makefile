# Build and test

profile ?=default

build:
	@FOUNDRY_PROFILE=production forge build

install:
	cd modules && \
	git submodule update --remote nstbl-token nstbl-acl-manager nstbl-loan-manager && \
	cd ..

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

git:
	@git add .
	git commit -m "$m"
	git push

coverage:
	@forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage

slither:
	@solc-select use 0.8.21 && \
	slither . 

.PHONY: install build test debug clean git coverage slither
