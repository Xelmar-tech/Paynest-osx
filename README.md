# Paynest - Aragon OSx Payment Management System

## Overview

Paynest is a comprehensive payment management system built on top of Aragon OSx, designed to handle scheduled payments and payment streams for DAOs. It provides a flexible and secure way to manage recurring payments, one-time payments, and streaming payments through a DAO structure.

## For Frontend Developers

### Key Integration Points

1. **PaymentsPlugin Contract**: The main contract you'll interact with for payment operations

   - Create and manage scheduled payments
   - Create and manage payment streams
   - Handle username registration
   - Query payment statuses

2. **PaynestDAOFactory**: Used to create new DAOs with the payments plugin installed

### Common Workflows

#### 1. Creating a New DAO

```typescript
// Parameters for creating a new DAO
const daoParams = {
  minApprovals: 2, // Number of required approvals for multisig
  multisigMembers: ["0x123...", "0x456..."], // Array of multisig member addresses
  paymentManagers: ["0x789..."], // Array of addresses that can create/manage payments
};

// Create DAO using the factory
const factory = new ethers.Contract(FACTORY_ADDRESS, FACTORY_ABI);
const tx = await factory.createDao(daoParams);
const receipt = await tx.wait();
// Get deployed addresses from receipt events
```

#### 2. Interacting with Payments Plugin

```typescript
// Initialize plugin contract
const plugin = new ethers.Contract(PLUGIN_ADDRESS, PLUGIN_ABI);

// Claim a username
await plugin.claimUsername("alice");

// Create a scheduled payment
await plugin.createSchedule(
  "bob", // username
  ethers.utils.parseEther("1"), // amount
  ETH_ADDRESS, // token address (ETH or ERC20)
  futureTimestamp // payment date
);

// Create a payment stream
await plugin.createStream(
  "carol", // username
  ethers.utils.parseEther("10"), // total amount
  TOKEN_ADDRESS, // token address
  endTimestamp // when stream ends
);

// Query payment status
const schedule = await plugin.getSchedule("bob");
const stream = await plugin.getStream("carol");
```

## For Smart Contract Engineers

### Core Components

#### 1. PaymentsPlugin (`src/PaymentsPlugin.sol`)

The main plugin contract that handles all payment logic:

```solidity
contract PaymentsPlugin is PluginUUPSUpgradeable, IPayments {
    // Key state variables
    mapping(string => address) private userDirectory;
    mapping(string => Schedule) private schedulePayment;
    mapping(string => Stream) private streamPayment;

    // Key permissions
    bytes32 public constant CREATE_PAYMENT_PERMISSION_ID;
    bytes32 public constant EDIT_PAYMENT_PERMISSION_ID;
    bytes32 public constant EXECUTE_PAYMENT_PERMISSION_ID;
}
```

Key features:

- Username to address mapping
- Schedule and stream payment storage
- Permission-based access control
- Integration with DAO's execute function for payments

#### 2. PaynestDAOFactory (`src/factory/PaynestDAOFactory.sol`)

Factory contract that creates DAOs with the payments plugin pre-installed:

```solidity
contract PaynestDAOFactory {
    struct DAOParameters {
        uint16 minApprovals;
        address[] multisigMembers;
        address[] paymentManagers;
    }

    function createDao(DAOParameters calldata parameters)
        public returns (Deployment memory)
}
```

The factory:

1. Deploys a new DAO
2. Installs the multisig plugin
3. Installs the payments plugin
4. Sets up all required permissions

### Deployment Process

The deployment script (`script/DeployPaynest.s.sol`) handles the full deployment process:

1. Deploys `PaymentsPluginSetup`
2. Creates a plugin repository
3. Deploys `PaynestDAOFactory`

To deploy:

```bash
# For testnet
make deploy-testnet

# For mainnet
make deploy-prodnet
```

Required environment variables (in `.env`):

```bash
DEPLOYMENT_PRIVATE_KEY=""        # Deployer's private key
PLUGIN_REPO_FACTORY=""          # Aragon's plugin repo factory address
DAO_FACTORY=""                  # Aragon's DAO factory address
PLUGIN_SETUP_PROCESSOR=""       # Aragon's plugin setup processor address
MULTISIG_PLUGIN_REPO_ADDRESS="" # Aragon's multisig plugin repo address
```

### Testing and Development

The project includes a comprehensive test suite in `test/`:

1. `PaymentsPlugin.t.sol`: Core plugin functionality tests

   - Username management
   - Schedule creation and execution
   - Stream creation and execution
   - Permission checks

2. Helper contracts:
   - `AdminDaoBuilder.sol`: Utility for creating test DAOs
   - Test fixtures and shared setup

To run tests:

```bash
# Run all tests
make test

# Run specific test
forge test --match-test testFunctionName
```

## Technical Details

### Payment Types

1. **Scheduled Payments**

   - One-time or recurring (30-day interval)
   - Supports ETH and ERC20 tokens
   - Full amount transferred on execution

2. **Payment Streams**
   - Linear payment streaming
   - Amount = (elapsed time / total duration) \* total amount
   - Partial amounts can be claimed during stream

### Permission System

The plugin uses three permission levels:

1. `CREATE_PAYMENT_PERMISSION_ID`: Create new payments
2. `EDIT_PAYMENT_PERMISSION_ID`: Modify existing payments
3. `EXECUTE_PAYMENT_PERMISSION_ID`: Execute payments

Permissions are managed through Aragon's permission system and can be granted to:

- Individual addresses
- Multisig contract
- Other plugins

## Support

For technical support:

- Smart contract issues: Create a detailed issue with relevant transaction hashes
- Integration questions: Check the integration examples in `test/` directory
- General questions: Open an issue in the repository
