# GEB

This repository contains the core smart contract code for GEB. GEB is the abbreviation of [Gödel, Escher and Bach](https://en.wikipedia.org/wiki/G%C3%B6del,_Escher,_Bach) as well as the name of an [Egyptian god](https://en.wikipedia.org/wiki/Geb).

Check out the more in-depth [documentation](https://docs.reflexer.finance/).

View [GEB diagram](https://www.figma.com/file/5GL7lVwqNeNKIcANCgCJjl/GEB-Diagram-Share?type=whiteboard&node-id=0-1&t=lRgCKLsTfACuJu1I-0).

## Bug Bounty

There's an [ongoing bug bounty program](https://immunefi.com/bounty/reflexer/) covering contracts from this repo.

## Deployment Instructions

Clone this repo. Run the following commands in terminal:

`yarn install`

`yarn build`

Create a `.env` file and add the variables found in `.env.example`

#

**Testing**

`yarn test` to run all tests, or

`yarn test:e2e`, `yarn test:local`, `yarn test:simulation`, `yarn test:unit`

#

**Deployment**

This repo is setup to run on Arbtirum Mainnet and Testnet. Additional modifications will be needed to deploy on other networks, specifically regarding the token addresses found in the `src/scripts/Registry.s.sol` file, the `OracleRelayer` address, and the `chainId` variables throughout the repo.

To deploy on Arbtirum, run the following commands:

`yarn deploy:mainnet`

`yarn deploy:goerli`

For deployment script errors, you may also try running the script directly in terminal. First, add the env variables into the terminal. Then, run the following script:

`forge script DeployGoerli --with-gas-price 2000000000 -vvvvv --rpc-url $URL --private-key $PK --broadcast --verify --etherscan-api-key $EK`

