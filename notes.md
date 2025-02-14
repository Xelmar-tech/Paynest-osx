# Payments Plugin Development Notes

## Project Evolution and Current Status

### 1. Project Structure and Testing Philosophy

- Moved towards a more organized test structure with clear separation of concerns
- Adopted verbose test documentation with detailed natspec comments
- Each test function now includes:
  - Clear `@notice` explaining what is being tested
  - Detailed `@dev` section listing specific verifications
  - Explicit listing of invariants that must hold true
  - Clear separation between setup, execution, and verification

### 2. Contract Changes

#### Username Management

- Added validation to prevent empty usernames
- Created new custom error `EmptyUsernameNotAllowed`
- Updated `claimUsername` function to check for empty strings
- Improved error handling with proper error parameters

### 3. Test Structure Improvements

#### Base Test Contract

- Utilizing `AragonTest` as the base contract
- Properly inheriting test addresses (alice, bob, etc.) instead of redefining them
- Shared setup logic in `PaymentsPluginTest`

#### Test Organization

- Separated tests into logical contracts:
  - `UsernameManagementTest`
  - `PaymentScheduleTest`
  - `StreamManagementTest`
- Each test contract focuses on a specific feature set

### 4. Test Coverage

#### Username Management Tests

- Basic claiming functionality
- Prevention of duplicate claims
- Empty username validation
- Address updates
- Permission checks
- State invariants

#### Payment Schedule Tests

- Schedule creation
- Permission checks
- Payment execution
- Token handling

#### Stream Management Tests

- Stream creation
- Stream parameters validation
- Event emission

### 5. Testing Best Practices Implemented

#### Error Handling

- Proper error expectation with parameters
- Example: `vm.expectRevert(abi.encodeWithSelector(UsernameAlreadyClaimed.selector, username))`

#### State Verification

- Checking invariants after operations
- Verifying no state changes on failed operations
- Checking event emissions

#### Test Documentation

- Clear test names indicating functionality
- Detailed comments explaining test flow
- Explicit listing of invariants

### 6. Current Status

- All tests are passing
- Empty username validation is implemented
- Error handling is properly implemented with parameters
- Test documentation is comprehensive

## Future Development

### 7. Next Steps

- Continue implementing remaining tests from the `.btt` file
- Add more edge cases for payment schedules
- Implement stream management tests
- Consider adding fuzz testing for numeric parameters
- Add integration tests between different features

### 8. Areas for Future Improvement

- Consider adding property-based tests
- Implement more edge cases
- Add stress testing for large numbers
- Consider gas optimization tests
- Add more integration tests between features

## Testing Guidelines

### Writing New Tests

1. Always include detailed natspec comments
2. List all invariants that should hold true
3. Verify state changes (or lack thereof)
4. Include both happy and sad paths
5. Test permission boundaries
6. Verify events are emitted correctly

### Test Structure

```solidity
/// @notice Clear description of what is being tested
/// @dev List of specific verifications:
/// 1. First verification
/// 2. Second verification
/// 3. Third verification
/// Invariants:
/// - First invariant that must hold
/// - Second invariant that must hold
function testSomething() public {
    // Setup
    ...

    // Execution
    ...

    // Verification
    ...
}
```

### Common Patterns

1. Permission Testing:

```solidity
vm.startPrank(alice);
// Test with correct permissions
vm.stopPrank();

vm.startPrank(bob);
vm.expectRevert(NotAuthorized.selector);
// Test with incorrect permissions
vm.stopPrank();
```

2. Error Testing:

```solidity
vm.expectRevert(
    abi.encodeWithSelector(CustomError.selector, param1, param2)
);
// Action that should revert
```

3. Event Testing:

```solidity
vm.expectEmit(true, true, true, true);
emit EventName(param1, param2);
// Action that emits event
```
