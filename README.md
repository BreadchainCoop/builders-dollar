<img src="https://raw.githubusercontent.com/defi-wonderland/brand/v1.0.0/external/solidity-foundry-boilerplate-banner.png" alt="wonderland banner" align="center" />
<br />

<div align="center"><strong>Start your next Solidity project with Foundry in seconds</strong></div>
<div align="center">A highly scalable foundation focused on DX and best practices</div>

<br />

<div align="center">Forked by Breadchain</div>

## Breadchain Developers

<dl>
  <dt>Basic Setup</dt>
  <li>Use `yarn add`, not `forge install`</li>
  <li>Use yarn scripts, not forge scripts (Look at the `package.json`!).</li>
  <li>Add scripts to the `package.json` as needed.</li>

  <dt>Required Contracts</dt>
  <li>Every contract is required to have a full interface.</li>
  <li>The contract should inherit it's own interface.</li>
  <li>The contract should reference it's interface with `@inheritdoc`</li>
  <li>The interface should contain other tags, including `@notice, @param, @return, @dev`</li>
  <li>The contract should be free of clutter, whereas the interface should act as a guide to the contract.</li>
  <li>Errors, Events, and Structs should be located in interfaces, not in contracts.</li>

  <dt>Required Testing</dt>
  <li><b>Integration/E2E</b> - should fork chain intended for deployment (likely gnosis or optimism) and should use the deploy script found in `Script/Common.sol` in the `test/integration/IntegrationBase.sol`.</li>
  <li><b>Unit</b> - should test and branch all contract functionality, with mock contracts or mock function calls added as needed to mock inter-contract calls. `.tree` files are there for example, but not necessary.</li>

  <dt>Test Coverage</dt>
  <li>Run `yarn coverage` to generate a coverage report for tests</li>
  <li>Unit and Integration should be 100%, with branch testing reasonably high</li>

  <dt>Advice for Writing Tests</dt>
  <li>Make use of `setUp` overrides and inheritance to cut down on redundant setups.</li>
  <li>Make use of helper functions with obvious names (e.g. `_fundUsersWithTokens()`) to reduce complexity for other developers that will review the code.</li>
  <li>Make use of Modifiers within test contracts to constrain fuzzing variables or any other use case</li>
  <li>Make multiple testing contracts in one file that all test the same contract (e.g. E2EGreeterTestSetup, E2EGreeterTestAccessControl, E2EGreeterTestCore, etc.) where contracts inherit the same base setup.</li>
  <li>Make use of constant variables placed in base test setup, so that updating test variables is simple and easy.</li>
  <li>Keep tests organized! Break complexity down and make it readable!</li>

  <dt>Required Formatting</dt>
  <li>Commits cannot be made without passing the linter!</li>
  <li>Run `yarn lint:check`</li>
  <li>Check `package.json` for more linter commands</li>
  <li>Internal variables start with an underscore ('_exampleOfInternalVar').</li>
  <li>Run `lint:natspec` to check contracts and interfaces for correct natspec.</li>

  <dt>Commit Messages</dt>
  <li>Example: `feat: added liquidation method to buttered-bread contract`</dt>
  <li>Example: `test: added unit tests`</dt>
  <li>List of commit types: `[build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test]`</dt>
  <li>For more specific details, checkout `https://www.conventionalcommits.org/en/v1.0.0-beta.4/`</li>
</dl>

<div align="center">End of Breadchain Notes</div>
<div align="center">Continue Reading Wonderland Outline</div>

## Features

<dl>
  <dt>Sample contracts</dt>
  <dd>Basic Greeter contract with an external interface.</dd>

  <dt>Foundry setup</dt>
  <dd>Foundry configuration with multiple custom profiles and remappings.</dd>

  <dt>Deployment scripts</dt>
  <dd>Sample scripts to deploy contracts on both mainnet and testnet.</dd>

  <dt>Sample Integration, Unit, Property-based fuzzed and symbolic tests</dt>
  <dd>Example tests showcasing mocking, assertions and configuration for mainnet forking. As well it includes everything needed in order to check code coverage.</dd>
  <dd>Unit tests are built based on the <a href="https://twitter.com/PaulRBerg/status/1682346315806539776">Branched-Tree Technique</a>, using <a href="https://github.com/alexfertel/bulloak">Bulloak</a>.
  <dd>Formal verification and property-based fuzzing are achieved with <a href="https://github.com/a16z/halmos">Halmos</a> and <a href="https://github.com/crytic/echidna">Echidna</a> (resp.).

  <dt>Linter</dt>
  <dd>Simple and fast solidity linting thanks to forge fmt.</dd>
  <dd>Find missing natspec automatically.</dd>

  <dt>Github workflows CI</dt>
  <dd>Run all tests and see the coverage as you push your changes.</dd>
  <dd>Export your Solidity interfaces and contracts as packages, and publish them to NPM.</dd>
</dl>

## Setup

1. Install Foundry by following the instructions from [their repository](https://github.com/foundry-rs/foundry#installation).
2. Copy the `.env.example` file to `.env` and fill in the variables.
3. Install the dependencies by running: `yarn install`. In case there is an error with the commands, run `foundryup` and try them again.

## Build

The default way to build the code is suboptimal but fast, you can run it via:

```bash
yarn build
```

In order to build a more optimized code ([via IR](https://docs.soliditylang.org/en/v0.8.15/ir-breaking-changes.html#solidity-ir-based-codegen-changes)), run:

```bash
yarn build:optimized
```

## Running tests

Unit tests should be isolated from any externalities, while Integration usually run in a fork of the blockchain. In this boilerplate you will find example of both.

In order to run both unit and integration tests, run:

```bash
yarn test
```

In order to just run unit tests, run:

```bash
yarn test:unit
```

In order to run unit tests and run way more fuzzing than usual (5x), run:

```bash
yarn test:unit:deep
```

In order to just run integration tests, run:

```bash
yarn test:integration
```

In order to just run the echidna fuzzing campaign (requires [Echidna](https://github.com/crytic/building-secure-contracts/blob/master/program-analysis/echidna/introduction/installation.md) installed), run:

```bash
yarn test:fuzz
```

In order to just run the symbolic execution tests (requires [Halmos](https://github.com/a16z/halmos/blob/main/README.md#installation) installed), run:

```bash
yarn test:symbolic
```

In order to check your current code coverage, run:

```bash
yarn coverage
```

<br>

## Deploy & verify

### Setup

Configure the `.env` variables and source them:

```bash
source .env
```

Import your private keys into Foundry's encrypted keystore:

```bash
cast wallet import $OPTIMISM_DEPLOYER_NAME --interactive
```

```bash
cast wallet import $SEPOLIA_DEPLOYER_NAME --interactive
```

### Sepolia

```bash
yarn deploy:sepolia
```

### Mainnet

```bash
yarn deploy:mainnet
```

The deployments are stored in ./broadcast

See the [Foundry Book for available options](https://book.getfoundry.sh/reference/forge/forge-create.html).

## Export And Publish

Export TypeScript interfaces from Solidity contracts and interfaces providing compatibility with TypeChain. Publish the exported packages to NPM.

To enable this feature, make sure you've set the `NPM_TOKEN` on your org's secrets. Then set the job's conditional to `true`:

```yaml
jobs:
  export:
    name: Generate Interfaces And Contracts
    # Remove the following line if you wish to export your Solidity contracts and interfaces and publish them to NPM
    if: true
    ...
```

Also, remember to update the `package_name` param to your package name:

```yaml
- name: Export Solidity - ${{ matrix.export_type }}
  uses: defi-wonderland/solidity-exporter-action@1dbf5371c260add4a354e7a8d3467e5d3b9580b8
  with:
    # Update package_name with your package name
    package_name: "my-cool-project"
    ...


- name: Publish to NPM - ${{ matrix.export_type }}
  # Update `my-cool-project` with your package name
  run: cd export/my-cool-project-${{ matrix.export_type }} && npm publish --access public
  ...
```

You can take a look at our [solidity-exporter-action](https://github.com/defi-wonderland/solidity-exporter-action) repository for more information and usage examples.

## Licensing
The primary license for the boilerplate is MIT, see [`LICENSE`](https://github.com/defi-wonderland/solidity-foundry-boilerplate/blob/main/LICENSE)