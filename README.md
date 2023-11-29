# nstbl-stake-pool

## Overview
This repository contains the core contracts of the nSTBL V1 protocol that are responsible for the staking functionality.

| Contract | Description |
| -------- | ------- |
| [`StakepPool`](https://github.com/nealthy-labs/nSTBL_V1_LoanManager/blob/main/contracts/LoanManager.sol) | Contains the logic for the Loan Manager |
| [`StakepPoolStorage`](https://github.com/nealthy-labs/nSTBL_V1_LoanManager/blob/main/contracts/LoanManager.sol) | Contains the storage for the Loan Manager, decoupled to keep track of upgrades |
| [`IStakepPool`](https://github.com/nealthy-labs/nSTBL_V1_LoanManager/blob/main/contracts/interfaces/ILoanManager.sol) | The interface for the Loan Manager contract |
| [`TokenLP`](https://github.com/nealthy-labs/nSTBL_V1_LoanManager/blob/main/contracts/interfaces/ILoanManager.sol) | The interface for the Loan Manager contract |
| [`TransparentUpgradeableProxy`](https://github.com/nealthy-labs/nSTBL_V1_LoanManager/blob/main/contracts/upgradeable/TransparentUpgradeableProxy.sol) | Transparent upgradeable proxy contract with minor change in constructor where we pass the address of proxy admin instead of deploying a new one |

## Dependencies/Inheritance
Contracts in this repo inherit and import code from:
- [`openzeppelin-contracts`](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [`nSTBL_V1_ACLManager`](https://github.com/nealthy-labs/nSTBL_V1_ACLManager.git)
- [`nSTBL_V1_LoanManager`](https://github.com/nealthy-labs/nSTBL_V1_LoanManager.git)
- [`nSTBL_V1_nSTBLToken`](https://github.com/nealthy-labs/nSTBL_V1_nSTBLToken.git)

## Setup
Run the command ```forge install``` before running any of the make commands. 

## Commands
To make it easier to perform some tasks within the repo, a few commands are available through a makefile:

### Build Commands
| Command | Action |
|---|---|
| `make test` | Run all tests |
| `make debug` | Run all tests with debug traces |
| `make testToken` | Run unit tests for LP Token |
| `make testStakePoolMock` | Run unit tests for the stake pool |
| `make clean` | Delete cached files |
| `make coverage` | Generate coverage report under coverage directory |
| `make slither` | Run static analyzer |

## About Nealthy
[Nealthy](https://www.nealthy.com) is a VARA regulated crypto asset management company. Nealthy provides on-chain index products for KYC/KYB individuals and institutions to invest in.
