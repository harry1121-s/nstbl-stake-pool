install:
	@mkdir modules && \
	cd modules && \
	git submodule add https://github.com/foundry-rs/forge-std.git && \
	git submodule add https://github.com/OpenZeppelin/openzeppelin-contracts.git && \
	git submodule add https://github.com/nealthy-labs/nSTBL_V1_ACLManager.git && \
	git submodule add https://github.com/nealthy-labs/nSTBL_V1_LoanManager.git && \
	git submodule add https://github.com/nealthy-labs/nSTBL_V1_nSTBLToken.git&& \
	cd ..

update:
	@cd modules && \
	git submodule update --remote nstbl-acl-manager && \
	cd ..

build:
	@forge build --sizes

update:
	@cd modules && \
	git submodule update --remote --init nstbl-token nstbl-acl-manager nstbl-loan-manager && \
	cd ..

test:
	@forge test

testToken:
	@forge test --match-path ./tests/unit/Token.t.sol

testStakePoolUnit:
	@forge test --match-path ./tests/StakePoolMock/unit/StakePool.unit.t.sol -vvv --gas-report

testStakePoolFuzz:
	@forge test --match-path ./tests/StakePoolMock/unit/StakePool.fuzz.t.sol -vvv --gas-report

testInvariant:
	@forge test --match-path ./tests/StakePoolMock/Invariant/StakePoolInvariant.t.sol -vvvvv

debug: 
	forge test -vvvvv

clean:
	@forge clean && \
	rm -rf coverage && \
	rm lcov.info

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
