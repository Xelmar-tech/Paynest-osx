// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title Errors
 * @dev Custom error definitions for the Paynest system.
 */
abstract contract Errors {
    // Authorization errors
    error NotAuthorized();

    // Token errors
    error TokenNotSupported();
    error TokenAlreadySupported();
    error InsufficientBalance();

    // Subscription errors
    error InsufficientFee();
    error MaxOrganizationsReached();

    // Directory errors
    error UserNotFound(string username);
    error IncompatibleUserAddress();
    error UsernameAlreadyClaimed(string username);
    error EmptyUsernameNotAllowed();

    // Payment Errors
    error ActivePayment(string username);
    error InActivePayment(string username);
    error NoActivePayment(string username);
    error InvalidAmount();
    error InvalidEndDate();
    error InvalidStreamEnd();
    error NoPayoutDue();
    error NoEditAccess();
    error InvalidSubscriptionPeriod();
}
