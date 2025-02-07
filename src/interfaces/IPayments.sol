// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/**
 * @title Payments Interface
 * @dev Interface for interacting with the Payments contract, which handles payments and subscription management.
 */
interface IPayments {
    // Event for address update
    event UserAddressUpdated(string indexed username, address newAddress);

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
     * @dev Represents a real-time payment stream.
     * @param amount The rate of payment in tokens per second.
     * @param token The token address used for the stream payments.
     * @param lastPayout The timestamp of the last payment update.
     * @param endStream The timestamp when the stream ends.
     * @param active Indicates whether the stream is currently active.
     */
    struct Stream {
        uint256 amount;
        address token;
        uint40 lastPayout;
        uint40 endStream;
        bool active;
    }

    /**
     * @dev Emitted when a payment schedule becomes active.
     * @param username The username associated with the payment schedule.
     * @param token The address of the token used for the payments.
     * @param nextPayout The timestamp of the next scheduled payout.
     * @param amount The amount to be paid at the next payout.
     */
    event PaymentScheduleActive(
        string indexed username,
        address indexed token,
        uint40 indexed nextPayout,
        uint256 amount
    );

    /**
     * @dev Emitted when a payment stream becomes active.
     * @param username The username associated with the payment stream.
     * @param token The address of the token used for the payments.
     * @param startStream The timestamp of the stream payout.
     * @param amount The amount to be paid at the next payout.
     */
    event PaymentStreamActive(
        string indexed username,
        address indexed token,
        uint40 indexed startStream,
        uint256 amount
    );

    /**
     * @dev Emitted when a payout is successfully processed.
     * @param username The username associated with the stream.
     * @param token The token address used for the payout.
     * @param amount The amount paid out.
     */
    event Payout(
        string indexed username,
        address indexed token,
        uint256 amount
    );

    /**
     * @dev Emitted when a payment stream is canceled.
     * @param username The username associated with the canceled stream.
     */
    event PaymentStreamCancelled(string indexed username);

    /**
     * @dev Emitted when a payment schedule is canceled.
     * @param username The username associated with the canceled schedule.
     */
    event PaymentScheduleCancelled(string indexed username);

    /**
     * @dev Emitted when a stream is updated with a new amount.
     * This event logs the updated stream information for a given username.
     *
     * @param username The username of the user whose stream has been updated.
     * @param amount The new amount set for the stream.
     */
    event StreamUpdated(string indexed username, uint amount);

    /**
     * @dev Emitted when a payment schedule is updated with a new amount.
     * This event logs the updated schedule information for a given username.
     *
     * @param username The username of the user whose schedule has been updated.
     * @param amount The new amount set for the schedule.
     */
    event ScheduleUpdated(string indexed username, uint amount);

    /**
     * @notice Event for Organization Name tracking Off chain
     * @param name The new name of the org
     */
    event OrgNameChange(string name);
    event ETHReceived(string name, uint amount);

    /**
     * @notice Creates a payment stream or schedule for an employee or recipient.
     * @dev This function allows an organization to set up recurring payments to an address.
     *      It supports both stream (for payments every second) and schedule (for monthly payments).
     * @param username The username of the recipient who will receive the payment.
     * @param amount The amount to be paid on a scheduled basis.
     * @param token Address of token to pay in
     * @param oneTimePayoutDate Timestamp of a payment to be made once
            As would a contractor payment would be made.
     */
    function createSchedule(
        string calldata username,
        uint256 amount,
        address token,
        uint40 oneTimePayoutDate
    ) external payable;

    /**
     * @notice Creates a real-time payment stream for a recipient.
     * @dev Sets up a stream that pays tokens to a recipient every second, starting immediately and ending at a specified time.
     * @param username The username of the recipient who will receive the stream.
     * @param amount The amount of tokens paid to the recipient every second.
     * @param token The address of the token to be streamed.
     * @param endStream The timestamp when the stream ends.
     */
    function createStream(
        string calldata username,
        uint256 amount,
        address token,
        uint40 endStream
    ) external payable;

    /**
     * @notice Requests a payout of accumulated funds.
     * @dev Allows anyone to request a payout of funds from the contract.
     * @param username The username of the recipient who will receive the payment.
     */
    function requestStreamPayout(string calldata username) external payable;

    /**
     * @notice Requests a payout of scheduled funds.
     * @dev Allows anyone to request a payout of funds from the contract.
     * @param username The username of the recipient who will receive the payment.
     */
    function requestSchedulePayout(string calldata username) external payable;

    /**
     * @notice Cancels an active payment stream.
     * @dev Disables the specified stream and stops further payouts.
     * @param username The username associated with the payment stream.
     */
    function cancelStream(string calldata username) external;

    /**
     * @notice Cancels an active payment schedule with prorated payout for the current interval.
     * @dev Computes and transfers the prorated amount for the current interval, then disables the schedule.
     * @param username The username associated with the payment schedule.
     */
    function cancelSchedule(string calldata username) external;

    /**
     * @dev Edits the amount for an active stream for a given user.
     * Only the owner can call this function.
     * Reverts if the amount is zero or the payment stream is not active.
     *
     * @param username The username of the user whose stream is to be edited.
     * @param amount The new amount to set for the stream.
     *
     * Requirements:
     * - The caller must be the owner of the contract.
     * - The amount must be non-zero.
     * - The stream for the given username must be active.
     *
     * Emits:
     * - A `StreamUpdated` event with the updated stream information.
     */
    function editStream(string calldata username, uint amount) external;

    /**
     * @dev Edits the amount for a schedule payment for a given user.
     * Only the owner can call this function.
     * Reverts if the amount is zero, the payment schedule is not active, or the next payout is within 3 days.
     *
     * @param username The username of the user whose schedule is to be edited.
     * @param amount The new amount to set for the schedule.
     *
     * Requirements:
     * - The caller must be the owner of the contract.
     * - The amount must be non-zero.
     * - The schedule for the given username must be active.
     * - The time difference between the current timestamp and the next payout must be greater than 3 days.
     *
     * Emits:
     * - A `ScheduleUpdated` event with the updated schedule information.
     */
    function editSchedule(string calldata username, uint amount) external;

    /**
     * @notice Allows the Payments owner to withdraw any funds that were accidentally sent to the Payments contract.
     * @dev This function can be called by anyone to withdraw tokens to the DAO.
     * @param tokenAddr The address of the token to be withdrawn.
     */
    function emergencyWithdraw(address tokenAddr) external;

    /**
     * @notice Retrieves the current stream details for a user.
     * @dev This function can be used in the frontend to revalidate data.
     * @param username The username to query stream against.
     * @return stream The stream information.
     */
    function getStream(
        string calldata username
    ) external view returns (Stream memory stream);

    /**
     * @notice Retrieves the current schedule payment details for a user.
     * @dev This function can be used in the frontend to revalidate data.
     * @param username The username to query schedule against.
     * @return schedule The schedule information.
     */
    function getSchedule(
        string calldata username
    ) external view returns (Schedule memory schedule);
}
