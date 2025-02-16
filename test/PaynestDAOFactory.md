# PaynestDAOFactory Test Tree

## Factory Initialization

### Constructor

✓ Factory initializes with correct addresses
✓ Factory initializes with correct plugin versions
✓ Factory initializes with correct permissions
✓ Reverts with zero addresses
✓ Reverts with invalid plugin repos

## DAO Creation

### Basic Creation

✓ Can create DAO with minimum parameters
✓ Creates DAO with correct name and metadata
✓ Deploys both plugins correctly
✓ Sets up correct plugin permissions
✓ Emits correct events

### Multisig Setup

✓ Initializes multisig with correct members
✓ Sets correct minimum approvals
✓ Members can execute proposals
✓ Non-members cannot execute proposals
✓ Handles single member case
✓ Handles multiple members case

### Payments Plugin Setup

✓ Initializes payments plugin with correct managers
✓ Sets up correct payment permissions
✓ Managers can create payment schedules
✓ Managers can execute payments
✓ Non-managers cannot create schedules
✓ Non-managers cannot execute payments

## Post-Deployment Functionality

### Multisig Operations

✓ Can create proposals
✓ Can approve proposals
✓ Can execute approved proposals
✓ Can add new members
✓ Can remove members
✓ Can change minimum approvals
✓ Handles concurrent proposals correctly

### Payment Operations

✓ Can create one-time payment schedule
✓ Can create recurring payment schedule
✓ Can create payment stream
✓ Can execute scheduled payments
✓ Can execute stream payments
✓ Can manage usernames
✓ Can update payment recipients

### Payments Plugin

✓ Can update to new release
✓ Can update to new build
✓ Updates affect new deployments only
✓ Cannot downgrade version
✓ Emits version update events

### Plugin Permissions

✓ Correct permissions are granted on deployment
✓ Permissions are granted to correct entities
✓ Can modify permissions post-deployment
✓ Permission changes are reflected in functionality
✓ Handles permission conflicts

## Edge Cases

### Input Validation

✓ Handles empty member arrays
✓ Handles duplicate members
✓ Handles invalid approval thresholds
✓ Handles maximum member limits
✓ Validates all input parameters

### State Management

✓ Factory state remains consistent after failed deployments
✓ Plugin state remains consistent after failed operations
✓ Handles concurrent deployments
✓ Handles network forks
✓ Handles chain reorganizations

### Gas Optimization

✓ Deployment costs are optimized
✓ Operation costs are reasonable
✓ Batch operations are efficient
✓ Storage slots are optimized
✓ No unnecessary state changes

### Recovery Scenarios

✓ Can recover from failed deployments
✓ Can recover from failed plugin operations
✓ Can recover from permission issues
✓ Can handle unexpected contract states
✓ Provides upgrade paths for fixes

## Post-Deployment Payment Management

### Payment Scheduling

✓ Payment manager can create one-time payment schedule
✓ Payment manager can create recurring payment schedule
✓ Payment manager can create payment stream
✓ Payment manager can execute due payments
✓ Payment manager can execute stream payments
✓ Payment manager can update payment recipients
✓ Payment manager can cancel existing schedules
✓ Payment manager can modify existing schedules

### Permission Management

✓ Multisig can add new payment managers
✓ Multisig can remove payment managers
✓ Removed manager cannot create new schedules
✓ Removed manager cannot execute payments
✓ New manager can create schedules
✓ New manager can execute payments
✓ Multiple managers can manage same schedule

### Username Management

✓ Payment manager can register usernames
✓ Payment manager can update username addresses
✓ Payment manager can create schedules for registered usernames
✓ Removed manager cannot modify usernames
✓ New manager can manage existing usernames

### Payment Execution Scenarios

✓ Can execute payment after manager change
✓ Can execute stream after manager change
✓ Existing schedules continue to work after manager removal
✓ Multiple managers can execute same payment
✓ Payments fail if manager permissions revoked

### Token Management

✓ Can schedule payments in ETH
✓ Can schedule payments in ERC20 tokens
✓ Can handle multiple token types simultaneously
✓ Payments fail if DAO has insufficient balance
✓ Can handle token approval changes

### Multisig Control

✓ Multisig can pause all payments
✓ Multisig can resume payments
✓ Multisig can emergency cancel all schedules
✓ Multisig can upgrade plugins if needed
✓ Multisig can recover from failed operations

### Complex Scenarios

✓ Manager removal during active schedules
✓ Manager addition during active schedules
✓ Concurrent schedule management by multiple managers
✓ Permission changes during pending payments
✓ Recovery from failed payment executions
