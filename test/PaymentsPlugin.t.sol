// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {PaymentsPlugin} from "../src/PaymentsPlugin.sol";
import {IPayments} from "../src/interfaces/IPayments.sol";
import {MultisigDaoBuilder} from "./util/MultisigDaoBuilder.sol";
import {AragonTest} from "./util/AragonTest.sol";

contract PaymentsPluginTest is AragonTest {
    MultisigDaoBuilder builder;
    DAO dao;
    PaymentsPlugin paymentsPlugin;

    // The multisig plugin instance is deployed too but is not needed for these stub tests.

    function setUp() public virtual {
        vm.startPrank(alice);
        vm.warp(10 days);
        vm.roll(100);

        // Use MultisigDaoBuilder with alice as the DAO owner and as a multisig member.
        builder = new MultisigDaoBuilder();
        (dao, paymentsPlugin, ) = builder
            .withDaoOwner(alice)
            .withMultisigMember(alice)
            .build();
        vm.stopPrank();
    }

    function testClaimUsername() public {
        vm.startPrank(alice);
        string memory username = "alice";
        paymentsPlugin.claimUsername(username);
        address claimedAddress = paymentsPlugin.getUserAddress(username);
        assertEq(claimedAddress, alice, "Claimed username should be alice");
        vm.stopPrank();
    }

    function testUpdateUserAddressRevertsIfNotOwner() public {
        // alice claims a username, then bob attempts to update it, which should revert.
        vm.startPrank(alice);
        string memory username = "bob";
        paymentsPlugin.claimUsername(username);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(); // Expect revert due to caller not being the username owner.
        paymentsPlugin.updateUserAddress(username, bob);
        vm.stopPrank();
    }

    function testCreateScheduleStub() public {
        vm.startPrank(alice);
        string memory username = "alice_schedule";
        paymentsPlugin.claimUsername(username);
        uint256 amount = 100;
        address token = address(0x123);
        uint40 oneTimePayoutDate = uint40(block.timestamp + 1 days);
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
        vm.stopPrank();
    }

    // Additional stub tests for other functions (e.g., createStream) can be added here.
}
