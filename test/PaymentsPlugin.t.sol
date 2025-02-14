// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {PaymentsPlugin} from "../src/PaymentsPlugin.sol";
import {IPayments} from "../src/interfaces/IPayments.sol";
import {AdminDaoBuilder} from "./util/AdminDaoBuilder.sol";
import {AragonTest} from "./util/AragonTest.sol";
import {Admin} from "../lib/osx/packages/contracts/src/plugins/governance/admin/Admin.sol";
import {Errors} from "../src/util/Errors.sol";

contract PaymentsPluginTest is AragonTest {
    AdminDaoBuilder builder;
    DAO dao;
    PaymentsPlugin paymentsPlugin;
    Admin adminPlugin;
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    event PaymentScheduleActive(
        string indexed username,
        address token,
        uint40 nextPayout,
        uint256 amount
    );

    event StreamActive(
        string indexed username,
        address token,
        uint40 startDate,
        uint40 endDate,
        uint256 amount
    );

    event PaymentExecuted(
        string indexed username,
        address token,
        uint256 amount
    );

    event StreamPaymentExecuted(
        string indexed username,
        address token,
        uint256 amount
    );

    function setUp() public virtual {
        vm.startPrank(alice);
        vm.warp(10 days);
        vm.roll(100);

        // Use AdminDaoBuilder with alice as the admin
        builder = new AdminDaoBuilder();
        (dao, paymentsPlugin, adminPlugin) = builder.withAdmin(alice).build();
        vm.stopPrank();
    }
}

contract UsernameManagementTest is PaymentsPluginTest, Errors {
    event UserAddressUpdated(string indexed username, address newAddress);

    /// @notice Tests the basic username claiming functionality
    /// @dev This test verifies that:
    /// 1. A user can claim an unclaimed username
    /// 2. The username is correctly mapped to the claimer's address
    /// 3. The UserAddressUpdated event is emitted with correct parameters
    /// Invariants:
    /// - A username can only be mapped to one address at a time
    /// - The mapping username -> address should persist after claiming
    function testClaimUsername() public {
        vm.startPrank(alice);
        string memory username = "alice";

        vm.expectEmit(true, true, true, true);
        emit UserAddressUpdated(username, alice);

        paymentsPlugin.claimUsername(username);
        address claimedAddress = paymentsPlugin.getUserAddress(username);
        assertEq(
            claimedAddress,
            alice,
            "Claimed username should be mapped to claimer's address"
        );
        vm.stopPrank();
    }

    /// @notice Tests that a username cannot be claimed if it's already claimed
    /// @dev This test verifies that:
    /// 1. After a username is claimed, no other address can claim it
    /// 2. The contract reverts with UsernameAlreadyClaimed error
    /// Invariants:
    /// - A username cannot be reassigned without explicit transfer
    /// - The original claimer's ownership persists after failed claim attempts
    function testCannotClaimAlreadyClaimedUsername() public {
        vm.startPrank(alice);
        string memory username = "alice";
        paymentsPlugin.claimUsername(username);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(UsernameAlreadyClaimed.selector, username)
        );
        paymentsPlugin.claimUsername(username);

        // Verify invariant: original claim persists
        assertEq(
            paymentsPlugin.getUserAddress(username),
            alice,
            "Username ownership should not change after failed claim"
        );
        vm.stopPrank();
    }

    /// @notice Tests that empty string cannot be used as a username
    /// @dev This test verifies that:
    /// 1. Empty string is not a valid username
    /// 2. The contract reverts with EmptyUsernameNotAllowed error
    /// Invariants:
    /// - Empty string usernames are never allowed
    /// - No state changes occur when attempting to claim empty username
    function testCannotClaimEmptyString() public {
        vm.startPrank(alice);
        string memory username = "";

        vm.expectRevert(EmptyUsernameNotAllowed.selector);
        paymentsPlugin.claimUsername(username);

        // Verify invariant: no state changes occurred
        assertEq(
            paymentsPlugin.getUserAddress(username),
            address(0),
            "Empty username should not be mapped to any address"
        );
        vm.stopPrank();
    }

    /// @notice Tests the ability to update a username's associated address
    /// @dev This test verifies that:
    /// 1. The owner of a username can update its associated address
    /// 2. The UserAddressUpdated event is emitted with new address
    /// 3. The mapping is updated correctly
    /// Invariants:
    /// - Only the current owner can update the address
    /// - The username->address mapping is updated atomically
    function testUpdateUserAddress() public {
        vm.startPrank(alice);
        string memory username = "alice";
        paymentsPlugin.claimUsername(username);

        address newAddress = address(0x123);
        vm.expectEmit(true, true, true, true);
        emit UserAddressUpdated(username, newAddress);

        paymentsPlugin.updateUserAddress(username, newAddress);
        assertEq(
            paymentsPlugin.getUserAddress(username),
            newAddress,
            "Username should be mapped to the new address"
        );
        vm.stopPrank();
    }

    /// @notice Tests that non-owners cannot update a username's address
    /// @dev This test verifies that:
    /// 1. Only the current owner can update the address
    /// 2. The contract reverts with NotAuthorized when non-owner attempts update
    /// 3. The original mapping persists after failed update attempts
    /// Invariants:
    /// - Username ownership cannot be changed by non-owners
    /// - Failed updates do not modify state
    function testUpdateUserAddressRevertsIfNotOwner() public {
        vm.startPrank(alice);
        string memory username = "bob";
        paymentsPlugin.claimUsername(username);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(NotAuthorized.selector);
        paymentsPlugin.updateUserAddress(username, bob);

        // Verify invariant: original ownership persists
        assertEq(
            paymentsPlugin.getUserAddress(username),
            alice,
            "Username ownership should not change after failed update"
        );
        vm.stopPrank();
    }

    /// @notice Tests that address updates on non-existent usernames revert
    /// @dev This test verifies that:
    /// 1. Cannot update address for username that hasn't been claimed
    /// 2. Contract reverts with NotAuthorized error
    /// Invariants:
    /// - Only claimed usernames can have their addresses updated
    function testCannotUpdateAddressForNonExistentUsername() public {
        vm.startPrank(alice);
        string memory username = "nonexistent";
        vm.expectRevert(NotAuthorized.selector);
        paymentsPlugin.updateUserAddress(username, alice);
        vm.stopPrank();
    }

    /// @notice Tests that an address can be updated to the same value
    /// @dev This test verifies that:
    /// 1. Updating to the same address is valid operation
    /// 2. The UserAddressUpdated event is still emitted
    /// 3. The operation is idempotent
    /// Invariants:
    /// - State remains consistent after redundant updates
    /// - Events are emitted even for redundant updates
    function testCanUpdateToSameAddress() public {
        vm.startPrank(alice);
        string memory username = "alice";
        paymentsPlugin.claimUsername(username);

        vm.expectEmit(true, true, true, true);
        emit UserAddressUpdated(username, alice);

        paymentsPlugin.updateUserAddress(username, alice);
        assertEq(
            paymentsPlugin.getUserAddress(username),
            alice,
            "Address should remain unchanged after redundant update"
        );
        vm.stopPrank();
    }

    /// @notice Tests the behavior of getUserAddress for unclaimed usernames
    /// @dev This test verifies that:
    /// 1. Querying unclaimed username returns zero address
    /// 2. Zero address return reliably indicates unclaimed status
    /// Invariants:
    /// - Unclaimed usernames always return zero address
    /// - Zero address return implies username is unclaimed
    function testGetUserAddressReturnsZeroForUnclaimed() public view {
        string memory username = "unclaimed";
        assertEq(
            paymentsPlugin.getUserAddress(username),
            address(0),
            "Unclaimed username should return zero address"
        );
    }
}

contract PaymentScheduleTest is PaymentsPluginTest, Errors {
    address executor;
    address paymentCreator;

    function setUp() public override {
        super.setUp();

        // Create additional test addresses for different permission holders
        (executor, ) = getWallet("payment_executor");
        (paymentCreator, ) = getWallet("payment_creator");

        // Grant specific permissions to different addresses
        vm.startPrank(alice);
        dao.grant(
            address(paymentsPlugin),
            paymentCreator,
            paymentsPlugin.CREATE_PAYMENT_PERMISSION_ID()
        );
        dao.grant(
            address(paymentsPlugin),
            executor,
            paymentsPlugin.EXECUTE_PAYMENT_PERMISSION_ID()
        );
        vm.stopPrank();
    }

    /// @notice Tests the creation of a one-time payment schedule
    /// @dev This test verifies that:
    /// 1. Admin can create a one-time payment schedule
    /// 2. Schedule parameters are set correctly
    /// 3. PaymentScheduleActive event is emitted with correct parameters
    /// Invariants:
    /// - Schedule is marked as one-time
    /// - Schedule is active after creation
    /// - Next payout is set to specified date
    function testCreateOneTimeSchedule() public {
        vm.startPrank(alice);
        string memory username = "alice_schedule";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100;
        address token = address(0x123);
        uint40 oneTimePayoutDate = uint40(block.timestamp + 1 days);

        vm.expectEmit(true, true, true, true);
        emit PaymentScheduleActive(username, token, oneTimePayoutDate, amount);

        paymentsPlugin.createSchedule(
            username,
            amount,
            token,
            oneTimePayoutDate
        );

        IPayments.Schedule memory schedule = paymentsPlugin.getSchedule(
            username
        );
        assertEq(schedule.token, token, "Schedule token mismatch");
        assertTrue(schedule.active, "Schedule should be active");
        assertEq(schedule.amount, amount, "Schedule amount mismatch");
        assertEq(
            schedule.nextPayout,
            oneTimePayoutDate,
            "Schedule payout date mismatch"
        );
        assertTrue(schedule.isOneTime, "Schedule should be one-time");
        vm.stopPrank();
    }

    /// @notice Tests the creation of a recurring payment schedule
    /// @dev This test verifies that:
    /// 1. Admin can create a recurring payment schedule
    /// 2. Schedule parameters are set correctly for recurring payments
    /// 3. PaymentScheduleActive event is emitted with correct parameters
    /// Invariants:
    /// - Schedule is marked as recurring (not one-time)
    /// - Schedule is active after creation
    /// - Next payout is set to 30 days from creation
    function testCreateRecurringSchedule() public {
        vm.startPrank(alice);
        string memory username = "alice_schedule";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100;
        address token = address(0x123);

        // Pass 0 for oneTimePayoutDate to create recurring schedule
        uint40 nextPayout = uint40(block.timestamp + 30 days);

        vm.expectEmit(true, true, true, true);
        emit PaymentScheduleActive(username, token, nextPayout, amount);

        paymentsPlugin.createSchedule(username, amount, token, 0);

        IPayments.Schedule memory schedule = paymentsPlugin.getSchedule(
            username
        );
        assertEq(schedule.token, token, "Schedule token mismatch");
        assertTrue(schedule.active, "Schedule should be active");
        assertEq(schedule.amount, amount, "Schedule amount mismatch");
        assertEq(
            schedule.nextPayout,
            nextPayout,
            "Schedule payout date mismatch"
        );
        assertFalse(schedule.isOneTime, "Schedule should be recurring");
        vm.stopPrank();
    }

    /// @notice Tests that schedule creation fails for non-admin users
    /// @dev This test verifies that:
    /// 1. Non-admin users cannot create payment schedules
    /// 2. The contract reverts with DaoUnauthorized error from Aragon framework
    /// Invariants:
    /// - Only admin can create schedules
    /// - Failed attempts do not modify state
    function testCreateScheduleRevertsIfNotAdmin() public {
        vm.startPrank(alice);
        string memory username = "bob_schedule";
        paymentsPlugin.claimUsername(username);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 amount = 100;
        address token = address(0x123);
        uint40 oneTimePayoutDate = uint40(block.timestamp + 1 days);

        // The Aragon framework reverts with DaoUnauthorized when permissions are missing
        vm.expectRevert();
        paymentsPlugin.createSchedule(
            username,
            amount,
            token,
            oneTimePayoutDate
        );

        // Verify no schedule was created
        IPayments.Schedule memory schedule = paymentsPlugin.getSchedule(
            username
        );
        assertFalse(schedule.active, "Schedule should not be created");
        vm.stopPrank();
    }

    /// @notice Tests that schedule creation fails for non-existent usernames
    /// @dev This test verifies that:
    /// 1. Cannot create schedule for unclaimed username
    /// 2. Contract reverts with UserNotFound error
    /// Invariants:
    /// - Only existing usernames can have schedules
    function testCreateScheduleRevertsForNonExistentUser() public {
        vm.startPrank(alice);
        string memory username = "nonexistent";
        uint256 amount = 100;
        address token = address(0x123);
        uint40 oneTimePayoutDate = uint40(block.timestamp + 1 days);

        vm.expectRevert(
            abi.encodeWithSelector(UserNotFound.selector, username)
        );
        paymentsPlugin.createSchedule(
            username,
            amount,
            token,
            oneTimePayoutDate
        );
        vm.stopPrank();
    }

    /// @notice Tests that schedule creation fails with zero amount
    /// @dev This test verifies that:
    /// 1. Cannot create schedule with zero payment amount
    /// 2. Contract reverts with InvalidAmount error
    /// Invariants:
    /// - Payment amount must be greater than zero
    function testCreateScheduleRevertsWithZeroAmount() public {
        vm.startPrank(alice);
        string memory username = "alice_schedule";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 0;
        address token = address(0x123);
        uint40 oneTimePayoutDate = uint40(block.timestamp + 1 days);

        vm.expectRevert(InvalidAmount.selector);
        paymentsPlugin.createSchedule(
            username,
            amount,
            token,
            oneTimePayoutDate
        );
        vm.stopPrank();
    }

    /// @notice Tests that schedule creation fails when active schedule exists
    /// @dev This test verifies that:
    /// 1. Cannot create new schedule when user has active schedule
    /// 2. Contract reverts with ActivePayment error
    /// Invariants:
    /// - Only one active schedule per username
    function testCreateScheduleRevertsWhenActiveScheduleExists() public {
        vm.startPrank(alice);
        string memory username = "alice_schedule";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100;
        address token = address(0x123);
        uint40 oneTimePayoutDate = uint40(block.timestamp + 1 days);

        // Create first schedule
        paymentsPlugin.createSchedule(
            username,
            amount,
            token,
            oneTimePayoutDate
        );

        // Attempt to create second schedule
        vm.expectRevert(
            abi.encodeWithSelector(ActivePayment.selector, username)
        );
        paymentsPlugin.createSchedule(
            username,
            amount,
            token,
            oneTimePayoutDate
        );
        vm.stopPrank();
    }

    /// @notice Tests successful execution of a one-time payment
    /// @dev This test verifies that:
    /// 1. Payment executes correctly on exact date
    /// 2. Tokens are transferred from DAO to recipient
    /// 3. Schedule is deactivated after payment
    /// 4. PaymentExecuted event is emitted
    /// Invariants:
    /// - Schedule is deactivated after one-time payment
    /// - Correct amount is transferred
    /// - Event is emitted with correct parameters
    function testExecuteOneTimePayment() public {
        vm.startPrank(alice);
        string memory username = "alice_payment";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100;
        uint40 oneTimePayoutDate = uint40(block.timestamp + 1 days);

        // Create and fund mock token
        MockERC20 mockToken = new MockERC20();
        mockToken.mint(address(dao), amount);
        address token = address(mockToken);

        // Create schedule
        paymentsPlugin.createSchedule(
            username,
            amount,
            token,
            oneTimePayoutDate
        );

        // Advance time to payment date
        vm.warp(oneTimePayoutDate);

        // Execute payment
        vm.expectEmit(true, true, true, true);
        emit PaymentExecuted(username, token, amount);

        paymentsPlugin.executePayment(username);

        // Verify payment and schedule state
        assertEq(
            mockToken.balanceOf(alice),
            amount,
            "Payment amount not received"
        );

        IPayments.Schedule memory schedule = paymentsPlugin.getSchedule(
            username
        );
        assertFalse(
            schedule.active,
            "Schedule should be inactive after one-time payment"
        );
        vm.stopPrank();
    }

    /// @notice Tests successful execution of a recurring payment
    /// @dev This test verifies that:
    /// 1. Payment executes correctly on schedule
    /// 2. Next payout date is updated correctly
    /// 3. Schedule remains active after payment
    /// Invariants:
    /// - Schedule remains active after payment
    /// - Next payout is updated to current time + 30 days
    /// - Correct amount is transferred
    function testExecuteRecurringPayment() public {
        vm.startPrank(alice);
        string memory username = "alice_payment";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100;

        // Create and fund mock token
        MockERC20 mockToken = new MockERC20();
        mockToken.mint(address(dao), amount * 2); // Fund for multiple payments
        address token = address(mockToken);

        // Create recurring schedule (oneTimePayoutDate = 0)
        paymentsPlugin.createSchedule(username, amount, token, 0);

        // Advance time to first payout
        vm.warp(block.timestamp + 30 days);

        // Execute first payment
        paymentsPlugin.executePayment(username);

        // Verify schedule state
        IPayments.Schedule memory schedule = paymentsPlugin.getSchedule(
            username
        );
        assertTrue(schedule.active, "Schedule should remain active");
        assertEq(
            schedule.nextPayout,
            uint40(block.timestamp + 30 days),
            "Next payout should be updated"
        );

        // Verify payment was made
        assertEq(
            mockToken.balanceOf(alice),
            amount,
            "Payment amount not received"
        );
        vm.stopPrank();
    }

    /// @notice Tests that accounts with CREATE_PAYMENT_PERMISSION can create schedules
    /// @dev This test verifies that:
    /// 1. Account with CREATE_PAYMENT_PERMISSION can create schedules
    /// 2. Schedule parameters are set correctly
    /// 3. Event is emitted correctly
    /// Invariants:
    /// - Any account with CREATE_PAYMENT_PERMISSION can create schedules
    /// - Permissions are checked at the function level
    function testCreateScheduleWithPermission() public {
        vm.startPrank(paymentCreator);
        string memory username = "user_schedule";

        // First claim a username
        vm.stopPrank();
        vm.startPrank(alice);
        paymentsPlugin.claimUsername(username);
        vm.stopPrank();
        vm.startPrank(paymentCreator);

        uint256 amount = 100;
        address token = address(0x123);
        uint40 oneTimePayoutDate = uint40(block.timestamp + 1 days);

        vm.expectEmit(true, true, true, true);
        emit PaymentScheduleActive(username, token, oneTimePayoutDate, amount);

        paymentsPlugin.createSchedule(
            username,
            amount,
            token,
            oneTimePayoutDate
        );

        IPayments.Schedule memory schedule = paymentsPlugin.getSchedule(
            username
        );
        assertEq(schedule.token, token, "Schedule token mismatch");
        assertTrue(schedule.active, "Schedule should be active");
        assertEq(schedule.amount, amount, "Schedule amount mismatch");
        assertEq(
            schedule.nextPayout,
            oneTimePayoutDate,
            "Schedule payout date mismatch"
        );
        assertTrue(schedule.isOneTime, "Schedule should be one-time");
        vm.stopPrank();
    }

    /// @notice Tests that accounts with EXECUTE_PAYMENT_PERMISSION can execute payments
    /// @dev This test verifies that:
    /// 1. Account with EXECUTE_PAYMENT_PERMISSION can execute payments
    /// 2. Payment is processed correctly
    /// 3. Events are emitted correctly
    /// Invariants:
    /// - Any account with EXECUTE_PAYMENT_PERMISSION can execute payments
    /// - Permissions are checked at the function level
    function testExecutePaymentWithPermission() public {
        // Setup payment schedule
        vm.startPrank(alice);
        string memory username = "user_payment";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100;
        uint40 oneTimePayoutDate = uint40(block.timestamp + 1 days);

        // Create and fund mock token
        MockERC20 mockToken = new MockERC20();
        mockToken.mint(address(dao), amount);
        address token = address(mockToken);

        paymentsPlugin.createSchedule(
            username,
            amount,
            token,
            oneTimePayoutDate
        );
        vm.stopPrank();

        // Advance time to payment date
        vm.warp(oneTimePayoutDate);

        // Execute payment with executor account
        vm.startPrank(executor);
        vm.expectEmit(true, true, true, true);
        emit PaymentExecuted(username, token, amount);

        paymentsPlugin.executePayment(username);

        // Verify payment was executed
        assertEq(
            mockToken.balanceOf(alice),
            amount,
            "Payment amount not received"
        );

        IPayments.Schedule memory schedule = paymentsPlugin.getSchedule(
            username
        );
        assertFalse(
            schedule.active,
            "Schedule should be inactive after one-time payment"
        );
        vm.stopPrank();
    }

    /// @notice Tests that accounts without CREATE_PAYMENT_PERMISSION cannot create schedules
    /// @dev This test verifies that:
    /// 1. Account without CREATE_PAYMENT_PERMISSION cannot create schedules
    /// 2. The contract reverts with DaoUnauthorized
    /// 3. No state changes occur
    /// Invariants:
    /// - Only accounts with CREATE_PAYMENT_PERMISSION can create schedules
    /// - Failed attempts do not modify state
    function testCreateScheduleRevertsWithoutPermission() public {
        vm.startPrank(executor); // executor has EXECUTE_PAYMENT_PERMISSION but not CREATE_PAYMENT_PERMISSION
        string memory username = "user_schedule";

        // First claim a username
        vm.stopPrank();
        vm.startPrank(alice);
        paymentsPlugin.claimUsername(username);
        vm.stopPrank();
        vm.startPrank(executor);

        uint256 amount = 100;
        address token = address(0x123);
        uint40 oneTimePayoutDate = uint40(block.timestamp + 1 days);

        vm.expectRevert(); // Expect DaoUnauthorized
        paymentsPlugin.createSchedule(
            username,
            amount,
            token,
            oneTimePayoutDate
        );

        // Verify no schedule was created
        IPayments.Schedule memory schedule = paymentsPlugin.getSchedule(
            username
        );
        assertFalse(schedule.active, "Schedule should not be created");
        vm.stopPrank();
    }

    /// @notice Tests that accounts without EXECUTE_PAYMENT_PERMISSION cannot execute payments
    /// @dev This test verifies that:
    /// 1. Account without EXECUTE_PAYMENT_PERMISSION cannot execute payments
    /// 2. The contract reverts with DaoUnauthorized
    /// 3. No state changes occur
    /// Invariants:
    /// - Only accounts with EXECUTE_PAYMENT_PERMISSION can execute payments
    /// - Failed attempts do not modify state
    function testExecutePaymentRevertsWithoutPermission() public {
        // Setup payment schedule
        vm.startPrank(alice);
        string memory username = "user_payment";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100;
        uint40 oneTimePayoutDate = uint40(block.timestamp + 1 days);

        // Create and fund mock token
        MockERC20 mockToken = new MockERC20();
        mockToken.mint(address(dao), amount);
        address token = address(mockToken);

        paymentsPlugin.createSchedule(
            username,
            amount,
            token,
            oneTimePayoutDate
        );
        vm.stopPrank();

        // Advance time to payment date
        vm.warp(oneTimePayoutDate);

        // Attempt to execute payment with paymentCreator account (has CREATE_PAYMENT_PERMISSION but not EXECUTE_PAYMENT_PERMISSION)
        vm.startPrank(paymentCreator);
        vm.expectRevert(); // Expect DaoUnauthorized
        paymentsPlugin.executePayment(username);

        // Verify payment was not executed
        assertEq(
            mockToken.balanceOf(alice),
            0,
            "Payment should not be executed"
        );

        IPayments.Schedule memory schedule = paymentsPlugin.getSchedule(
            username
        );
        assertTrue(schedule.active, "Schedule should remain active");
        vm.stopPrank();
    }

    /// @notice Tests ETH payment execution
    /// @dev This test verifies that:
    /// 1. ETH payments are handled correctly
    /// 2. ETH is transferred from DAO to recipient
    /// 3. Events are emitted correctly
    /// Invariants:
    /// - ETH balance changes match payment amount
    /// - Schedule state is updated correctly
    function testExecuteETHPayment() public {
        vm.startPrank(alice);
        string memory username = "eth_payment";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 1 ether;
        uint40 oneTimePayoutDate = uint40(block.timestamp + 1 days);

        // Fund DAO with ETH
        vm.deal(address(dao), amount);

        // Create ETH payment schedule
        paymentsPlugin.createSchedule(username, amount, ETH, oneTimePayoutDate);
        vm.stopPrank();

        // Advance time to payment date
        vm.warp(oneTimePayoutDate);

        // Record initial balances
        uint256 initialRecipientBalance = alice.balance;
        uint256 initialDaoBalance = address(dao).balance;

        // Execute payment with executor account
        vm.startPrank(executor);
        vm.expectEmit(true, true, true, true);
        emit PaymentExecuted(username, ETH, amount);

        paymentsPlugin.executePayment(username);

        // Verify ETH transfer
        assertEq(
            alice.balance - initialRecipientBalance,
            amount,
            "Recipient should receive correct ETH amount"
        );
        assertEq(
            initialDaoBalance - address(dao).balance,
            amount,
            "DAO balance should decrease by correct amount"
        );

        // Verify schedule state
        IPayments.Schedule memory schedule = paymentsPlugin.getSchedule(
            username
        );
        assertFalse(
            schedule.active,
            "Schedule should be inactive after one-time payment"
        );
        vm.stopPrank();
    }

    /// @notice Tests that payment execution is skipped when not due
    /// @dev This test verifies that:
    /// 1. Payments cannot be executed before due date
    /// 2. No state changes occur on early execution attempt
    /// Invariants:
    /// - Schedule state remains unchanged
    /// - No transfers occur
    function testPaymentExecutionSkippedWhenNotDue() public {
        vm.startPrank(alice);
        string memory username = "future_payment";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100;
        uint40 oneTimePayoutDate = uint40(block.timestamp + 1 days);

        // Create and fund mock token
        MockERC20 mockToken = new MockERC20();
        mockToken.mint(address(dao), amount);
        address token = address(mockToken);

        paymentsPlugin.createSchedule(
            username,
            amount,
            token,
            oneTimePayoutDate
        );
        vm.stopPrank();

        // Try to execute payment before due date
        vm.startPrank(executor);
        paymentsPlugin.executePayment(username);

        // Verify no payment was made
        assertEq(
            mockToken.balanceOf(alice),
            0,
            "No payment should be made before due date"
        );

        // Verify schedule remains active
        IPayments.Schedule memory schedule = paymentsPlugin.getSchedule(
            username
        );
        assertTrue(schedule.active, "Schedule should remain active");
        assertEq(
            schedule.nextPayout,
            oneTimePayoutDate,
            "Next payout date should not change"
        );
        vm.stopPrank();
    }

    /// @notice Tests payment execution when user address becomes zero
    /// @dev This test verifies that:
    /// 1. Payment execution reverts if user address becomes zero
    /// 2. Contract reverts with UserNotFound error
    /// Invariants:
    /// - Zero address check is enforced during execution
    function testExecutePaymentRevertsWhenUserAddressZero() public {
        vm.startPrank(alice);
        string memory username = "zero_address_test";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100;
        uint40 oneTimePayoutDate = uint40(block.timestamp + 1 days);

        // Create and fund mock token
        MockERC20 mockToken = new MockERC20();
        mockToken.mint(address(dao), amount);
        address token = address(mockToken);

        // Create schedule
        paymentsPlugin.createSchedule(
            username,
            amount,
            token,
            oneTimePayoutDate
        );

        // Update user address to zero
        paymentsPlugin.updateUserAddress(username, address(0));
        vm.stopPrank();

        // Advance time to payment date
        vm.warp(oneTimePayoutDate);

        // Try to execute payment
        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(UserNotFound.selector, username)
        );
        paymentsPlugin.executePayment(username);
        vm.stopPrank();
    }
}

contract StreamManagementTest is PaymentsPluginTest, Errors {
    address executor;

    function setUp() public override {
        super.setUp();

        // Create additional test addresses for different permission holders
        (executor, ) = getWallet("payment_executor");

        // Grant specific permissions to different addresses
        vm.startPrank(alice);
        dao.grant(
            address(paymentsPlugin),
            executor,
            paymentsPlugin.EXECUTE_PAYMENT_PERMISSION_ID()
        );
        vm.stopPrank();
    }

    function testCreateStream() public {
        vm.startPrank(alice);
        string memory username = "alice_stream";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100;
        address token = address(0x123);
        uint40 endStream = uint40(block.timestamp + 30 days);

        vm.expectEmit(true, true, true, true);
        emit StreamActive(
            username,
            token,
            uint40(block.timestamp),
            endStream,
            amount
        );

        paymentsPlugin.createStream(username, amount, token, endStream);

        IPayments.Stream memory stream = paymentsPlugin.getStream(username);
        assertEq(stream.token, token, "Stream token mismatch");
        assertTrue(stream.active, "Stream should be active");
        assertEq(stream.amount, amount, "Stream amount mismatch");
        assertEq(stream.endDate, endStream, "Stream end date mismatch");
        assertEq(
            stream.startDate,
            uint40(block.timestamp),
            "Stream start date mismatch"
        );
        vm.stopPrank();
    }

    /// @notice Tests stream execution with pro-rata calculations
    /// @dev This test verifies that:
    /// 1. Pro-rata amount is calculated correctly
    /// 2. Tokens are transferred correctly
    /// 3. Stream state is updated
    /// Invariants:
    /// - Pro-rata calculation is accurate
    /// - Stream remains active during duration
    /// - Last payout timestamp is updated
    function testExecuteStreamWithProRataCalculation() public {
        vm.startPrank(alice);
        string memory username = "alice_stream";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100 ether; // Large amount for precise calculations
        uint40 streamDuration = uint40(30 days);
        uint40 endStream = uint40(block.timestamp + streamDuration);

        // Create and fund mock token
        MockERC20 mockToken = new MockERC20();
        mockToken.mint(address(dao), amount);
        address token = address(mockToken);

        paymentsPlugin.createStream(username, amount, token, endStream);

        // Advance time by 1/3 of the duration
        vm.warp(block.timestamp + 10 days);

        // Expected pro-rata amount for 10 days
        uint256 expectedAmount = (amount * 10 days) / streamDuration;

        vm.stopPrank();
        vm.startPrank(executor);
        vm.expectEmit(true, true, true, true);
        emit StreamPaymentExecuted(username, token, expectedAmount);

        paymentsPlugin.executeStream(username);

        // Verify payment amount
        assertEq(
            mockToken.balanceOf(alice),
            expectedAmount,
            "Pro-rata payment amount incorrect"
        );

        // Verify stream state
        IPayments.Stream memory stream = paymentsPlugin.getStream(username);
        assertTrue(stream.active, "Stream should remain active");
        assertEq(
            stream.lastPayout,
            uint40(block.timestamp),
            "Last payout should be updated"
        );
        vm.stopPrank();
    }

    /// @notice Tests stream deactivation after end date
    /// @dev This test verifies that:
    /// 1. Stream is deactivated when current time exceeds end date
    /// 2. No payments are made after deactivation
    /// Invariants:
    /// - Stream is deactivated after end date
    /// - No transfers occur after deactivation
    function testStreamDeactivationAfterEndDate() public {
        vm.startPrank(alice);
        string memory username = "alice_stream";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100;
        uint40 endStream = uint40(block.timestamp + 30 days);

        // Create and fund mock token
        MockERC20 mockToken = new MockERC20();
        mockToken.mint(address(dao), amount);
        address token = address(mockToken);

        paymentsPlugin.createStream(username, amount, token, endStream);
        vm.stopPrank();

        // Advance time beyond end date
        vm.warp(endStream + 1);

        vm.startPrank(executor);
        paymentsPlugin.executeStream(username);

        // Verify stream is deactivated
        IPayments.Stream memory stream = paymentsPlugin.getStream(username);
        assertFalse(stream.active, "Stream should be deactivated");

        // Verify no payment was made
        assertEq(
            mockToken.balanceOf(alice),
            0,
            "No payment should be made after end date"
        );
        vm.stopPrank();
    }

    /// @notice Tests ETH stream execution
    /// @dev This test verifies that:
    /// 1. ETH streams are handled correctly
    /// 2. Pro-rata ETH amounts are calculated and transferred
    /// 3. Stream state is updated correctly
    /// Invariants:
    /// - ETH transfers are accurate
    /// - Stream state updates are correct
    function testExecuteETHStream() public {
        vm.startPrank(alice);
        string memory username = "eth_stream";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 1 ether;
        uint40 streamDuration = uint40(30 days);
        uint40 endStream = uint40(block.timestamp + streamDuration);

        // Fund DAO with ETH
        vm.deal(address(dao), amount);

        paymentsPlugin.createStream(username, amount, ETH, endStream);

        // Advance time by 15 days (half duration)
        vm.warp(block.timestamp + 15 days);

        // Expected pro-rata amount for 15 days
        uint256 expectedAmount = amount / 2;

        vm.stopPrank();
        vm.startPrank(executor);

        // Record initial balances
        uint256 initialRecipientBalance = alice.balance;
        uint256 initialDaoBalance = address(dao).balance;

        vm.expectEmit(true, true, true, true);
        emit StreamPaymentExecuted(username, ETH, expectedAmount);

        paymentsPlugin.executeStream(username);

        // Verify ETH transfer
        assertEq(
            alice.balance - initialRecipientBalance,
            expectedAmount,
            "Recipient should receive correct ETH amount"
        );
        assertEq(
            initialDaoBalance - address(dao).balance,
            expectedAmount,
            "DAO balance should decrease by correct amount"
        );

        // Verify stream state
        IPayments.Stream memory stream = paymentsPlugin.getStream(username);
        assertTrue(stream.active, "Stream should remain active");
        assertEq(
            stream.lastPayout,
            uint40(block.timestamp),
            "Last payout should be updated"
        );
        vm.stopPrank();
    }

    /// @notice Tests stream execution when user address becomes zero
    /// @dev This test verifies that:
    /// 1. Stream execution reverts if user address becomes zero
    /// 2. Contract reverts with UserNotFound error
    /// Invariants:
    /// - Zero address check is enforced during stream execution
    function testExecuteStreamRevertsWhenUserAddressZero() public {
        vm.startPrank(alice);
        string memory username = "zero_address_stream";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100 ether;
        uint40 streamDuration = uint40(30 days);
        uint40 endStream = uint40(block.timestamp + streamDuration);

        // Create and fund mock token
        MockERC20 mockToken = new MockERC20();
        mockToken.mint(address(dao), amount);
        address token = address(mockToken);

        // Create stream
        paymentsPlugin.createStream(username, amount, token, endStream);

        // Update user address to zero
        paymentsPlugin.updateUserAddress(username, address(0));
        vm.stopPrank();

        // Advance time
        vm.warp(block.timestamp + 10 days);

        // Try to execute stream
        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(UserNotFound.selector, username)
        );
        paymentsPlugin.executeStream(username);
        vm.stopPrank();
    }

    /// @notice Tests stream execution with zero elapsed time
    /// @dev This test verifies that:
    /// 1. No payment is made when elapsed time is zero
    /// 2. Stream state remains unchanged
    /// Invariants:
    /// - No transfers occur with zero elapsed time
    /// - Stream state remains unchanged
    function testExecuteStreamWithZeroElapsedTime() public {
        vm.startPrank(alice);
        string memory username = "zero_time_stream";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100 ether;
        uint40 streamDuration = uint40(30 days);
        uint40 endStream = uint40(block.timestamp + streamDuration);

        // Create and fund mock token
        MockERC20 mockToken = new MockERC20();
        mockToken.mint(address(dao), amount);
        address token = address(mockToken);

        // Create stream
        paymentsPlugin.createStream(username, amount, token, endStream);
        vm.stopPrank();

        // Execute stream immediately (zero elapsed time)
        vm.startPrank(executor);
        paymentsPlugin.executeStream(username);

        // Verify no payment was made
        assertEq(
            mockToken.balanceOf(alice),
            0,
            "No payment should be made with zero elapsed time"
        );

        // Verify stream state remains unchanged
        IPayments.Stream memory stream = paymentsPlugin.getStream(username);
        assertTrue(stream.active, "Stream should remain active");
        assertEq(
            stream.lastPayout,
            uint40(block.timestamp),
            "Last payout should not change"
        );
        vm.stopPrank();
    }

    /// @notice Tests stream execution with minimum pro-rata amount
    /// @dev This test verifies that:
    /// 1. Minimum pro-rata amount (1 wei) is handled correctly
    /// 2. Small time intervals are calculated correctly
    /// Invariants:
    /// - Minimum amounts are transferred correctly
    /// - No rounding errors in small calculations
    function testExecuteStreamWithMinimumProRata() public {
        vm.startPrank(alice);
        string memory username = "min_prorata_stream";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100; // Small amount for minimum calculations
        uint40 streamDuration = uint40(100 days); // Long duration for small per-second rate
        uint40 endStream = uint40(block.timestamp + streamDuration);

        // Create and fund mock token
        MockERC20 mockToken = new MockERC20();
        mockToken.mint(address(dao), amount);
        address token = address(mockToken);

        // Create stream
        paymentsPlugin.createStream(username, amount, token, endStream);
        vm.stopPrank();

        // Advance time by 1 day (should result in 1 token due to rounding)
        vm.warp(block.timestamp + 1 days);

        // Expected pro-rata amount for 1 day
        uint256 expectedAmount = (amount * 1 days) / streamDuration;

        vm.startPrank(executor);
        vm.expectEmit(true, true, true, true);
        emit StreamPaymentExecuted(username, token, expectedAmount);

        paymentsPlugin.executeStream(username);

        // Verify minimum payment
        assertEq(
            mockToken.balanceOf(alice),
            expectedAmount,
            "Minimum pro-rata payment incorrect"
        );

        // Verify stream state
        IPayments.Stream memory stream = paymentsPlugin.getStream(username);
        assertTrue(stream.active, "Stream should remain active");
        assertEq(
            stream.lastPayout,
            uint40(block.timestamp),
            "Last payout should be updated"
        );
        vm.stopPrank();
    }
}

// Mock ERC20 token for testing
contract MockERC20 {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
