// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/**
 * @title Payments Interface
 * @dev Interface for interacting with the Payments contract, which handles payments and subscription management.
 */
interface IPayments {
    // Events
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
    event UserAddressUpdated(string indexed username, address newAddress);

    /**
     * @dev Represents a scheduled payment, including both recurring and one-time payments.
        A mapping of username to this struct defines the payment
     * @param token The token address used for the payment.
     * @param nextPayout The timestamp when the next payment is due.
     * @param isOneTime Indicates whether the payment is a one-time occurrence.
     * @param active Indicates whether the payment is active 
     * @param amount The amount to be paid per interval (e.g., monthly).
     */
    struct Schedule {
        address token;
        uint40 nextPayout;
        bool isOneTime;
        bool active;
        uint256 amount;
    }

    /**
     * @dev Represents a stream payment.
        A mapping of username to this struct defines the payment stream
     * @param token The token address used for the payment.
     * @param startDate The timestamp when the stream starts.
     * @param endDate The timestamp when the stream ends.
     * @param active Indicates whether the stream is active.
     * @param amount The amount to be streamed per second.
     * @param lastPayout The timestamp of the last payout.
     */
    struct Stream {
        address token;
        uint40 startDate;
        uint40 endDate;
        bool active;
        uint256 amount;
        uint40 lastPayout;
    }

    /**
     * @notice Allows a user to claim a username.
     * @dev This function allows a user to claim a username.
     * @param username The username to claim.
     */
    function claimUsername(string calldata username) external;

    /**
     * @notice Updates the wallet address for a given username.
     * @dev This function allows an authorized address to update the mapping of username to wallet address.
     *      Only specific addresses (e.g., admin or authorized addresses) can call this function.
     * @param username The username whose wallet address needs to be updated.
     * @param userAddress The new wallet address to associate with the username.
     */
    function updateUserAddress(
        string calldata username,
        address userAddress
    ) external;

    /**
     * @notice Retrieves the wallet address associated with a given username.
     * @dev This function allows anyone to check the wallet address associated with a specific username.
     * @param username The username whose wallet address is to be retrieved.
     * @return The wallet address associated with the username.
     */
    function getUserAddress(
        string calldata username
    ) external view returns (address);

    /**
     * @notice Creates a scheduled payment for a username
     * @param username The username to create the schedule for
     * @param amount The amount to be paid
     * @param token The token address to be used for payment
     * @param oneTimePayoutDate If non-zero, creates a one-time payment at this date
     */
    function createSchedule(
        string calldata username,
        uint256 amount,
        address token,
        uint40 oneTimePayoutDate
    ) external;

    /**
     * @notice Creates a stream payment for a username
     * @param username The username to create the stream for
     * @param amount The amount to be streamed
     * @param token The token address to be used for payment
     * @param endStream The timestamp when the stream should end
     */
    function createStream(
        string calldata username,
        uint256 amount,
        address token,
        uint40 endStream
    ) external;

    /**
     * @notice Executes a scheduled payment if due
     * @param username The username whose payment to execute
     */
    function executePayment(string calldata username) external;

    /**
     * @notice Executes a stream payment
     * @param username The username whose stream to execute
     */
    function executeStream(string calldata username) external;

    /**
     * @notice Retrieves the current stream details for a user.
     * @param username The username to query stream against.
     * @return stream The stream information.
     */
    function getStream(
        string calldata username
    ) external view returns (Stream memory stream);

    /**
     * @notice Retrieves the current schedule payment details for a user.
     * @param username The username to query schedule against.
     * @return schedule The schedule information.
     */
    function getSchedule(
        string calldata username
    ) external view returns (Schedule memory schedule);
}
