// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {PluginUUPSUpgradeable} from "@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol";
import {IPayments} from "./interfaces/IPayments.sol";
import {Errors} from "./util/Errors.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title Payments Plugin
 * @notice A plugin that manages payment schedules and streams, executing them through the DAO.
 */
contract PaymentsPlugin is PluginUUPSUpgradeable, IPayments, Errors {
    using SafeERC20 for IERC20;

    bytes32 public constant CREATE_PAYMENT_PERMISSION_ID =
        keccak256("CREATE_PAYMENT_PERMISSION");

    bytes32 public constant EDIT_PAYMENT_PERMISSION_ID =
        keccak256("EDIT_PAYMENT_PERMISSION");

    bytes32 public constant EXECUTE_PAYMENT_PERMISSION_ID =
        keccak256("EXECUTE_PAYMENT_PERMISSION");

    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping(string => address) private userDirectory;
    mapping(string => Schedule) private schedulePayment;
    mapping(string => Stream) private streamPayment;

    /// @notice Initializes the plugin.
    /// @param _dao The DAO associated with this plugin.
    function initialize(IDAO _dao) external initializer {
        __PluginUUPSUpgradeable_init(_dao);
    }

    function updateUserAddress(
        string calldata username,
        address userAddress
    ) external override {
        if (userDirectory[username] != msg.sender) {
            revert NotAuthorized();
        }

        userDirectory[username] = userAddress;

        emit UserAddressUpdated(username, userAddress);
    }

    function getUserAddress(
        string calldata username
    ) external view override returns (address) {
        return userDirectory[username];
    }

    function createSchedule(
        string calldata username,
        uint256 amount,
        address token,
        uint40 oneTimePayoutDate
    ) external override auth(CREATE_PAYMENT_PERMISSION_ID) {
        address userAddress = userDirectory[username];

        if (userAddress == address(0)) {
            revert UserNotFound(username);
        }

        if (amount == 0) revert InvalidAmount();

        Schedule memory _schedule = schedulePayment[username];
        if (_schedule.active) revert ActivePayment(username);

        uint40 _now = uint40(block.timestamp);
        bool isOneTime = oneTimePayoutDate > _now;
        uint40 nextPayout = isOneTime
            ? oneTimePayoutDate
            : (_now + uint40(30 days));

        schedulePayment[username] = Schedule(
            token,
            nextPayout,
            isOneTime,
            true,
            amount
        );
        emit PaymentScheduleActive(username, token, nextPayout, amount);
    }

    function claimUsername(string calldata username) external override {
        if (bytes(username).length == 0) {
            revert EmptyUsernameNotAllowed();
        }

        if (userDirectory[username] != address(0)) {
            revert UsernameAlreadyClaimed(username);
        }

        userDirectory[username] = msg.sender;
        emit UserAddressUpdated(username, msg.sender);
    }

    function createStream(
        string calldata username,
        uint256 amount,
        address token,
        uint40 endStream
    ) external override auth(CREATE_PAYMENT_PERMISSION_ID) {
        address userAddress = userDirectory[username];

        if (userAddress == address(0)) {
            revert UserNotFound(username);
        }

        if (amount == 0) revert InvalidAmount();

        Stream memory _stream = streamPayment[username];
        if (_stream.active) revert ActivePayment(username);

        uint40 _now = uint40(block.timestamp);
        if (endStream <= _now) revert InvalidEndDate();

        streamPayment[username] = Stream({
            token: token,
            startDate: _now,
            endDate: endStream,
            active: true,
            amount: amount,
            lastPayout: _now
        });
        emit StreamActive(username, token, _now, endStream, amount);
    }

    function executePayment(
        string calldata username
    ) external auth(EXECUTE_PAYMENT_PERMISSION_ID) {
        Schedule memory schedule = schedulePayment[username];
        if (schedule.active && schedule.nextPayout <= block.timestamp) {
            address recipient = userDirectory[username];
            if (recipient == address(0)) revert UserNotFound(username);

            // Create action to be executed by the DAO
            IDAO.Action[] memory actions = new IDAO.Action[](1);

            if (schedule.token == ETH) {
                actions[0] = IDAO.Action({
                    to: recipient,
                    value: schedule.amount,
                    data: ""
                });
            } else {
                actions[0] = IDAO.Action({
                    to: schedule.token,
                    value: 0,
                    data: abi.encodeCall(
                        IERC20.transfer,
                        (recipient, schedule.amount)
                    )
                });
            }

            // Execute the payment through the DAO
            dao().execute({
                _callId: bytes32(0),
                _actions: actions,
                _allowFailureMap: 0
            });

            if (schedule.isOneTime) {
                schedule.active = false;
            } else {
                schedule.nextPayout = uint40(block.timestamp + 30 days);
            }
            schedulePayment[username] = schedule;

            emit PaymentExecuted(username, schedule.token, schedule.amount);
        }
    }

    function executeStream(
        string calldata username
    ) external auth(EXECUTE_PAYMENT_PERMISSION_ID) {
        Stream memory stream = streamPayment[username];
        if (!stream.active) revert NoActivePayment(username);

        uint40 _now = uint40(block.timestamp);
        if (_now > stream.endDate) {
            stream.active = false;
            streamPayment[username] = stream;
            return;
        }

        address recipient = userDirectory[username];
        if (recipient == address(0)) revert UserNotFound(username);

        uint256 elapsedTime = _now - stream.lastPayout;
        uint256 totalDuration = stream.endDate - stream.startDate;
        uint256 amount = (stream.amount * elapsedTime) / totalDuration;

        if (amount > 0) {
            // Create action to be executed by the DAO
            IDAO.Action[] memory actions = new IDAO.Action[](1);

            if (stream.token == ETH) {
                actions[0] = IDAO.Action({
                    to: recipient,
                    value: amount,
                    data: ""
                });
            } else {
                actions[0] = IDAO.Action({
                    to: stream.token,
                    value: 0,
                    data: abi.encodeCall(IERC20.transfer, (recipient, amount))
                });
            }

            // Execute the payment through the DAO
            dao().execute({
                _callId: bytes32(0),
                _actions: actions,
                _allowFailureMap: 0
            });

            stream.lastPayout = _now;
            streamPayment[username] = stream;

            emit StreamPaymentExecuted(username, stream.token, amount);
        }
    }

    /**
     * @notice Retrieves the current stream details for a user.
     * @param username The username to query stream against.
     * @return stream The stream information.
     */
    function getStream(
        string calldata username
    ) external view override returns (Stream memory) {
        return streamPayment[username];
    }

    /**
     * @notice Retrieves the current schedule payment details for a user.
     * @param username The username to query schedule against.
     * @return schedule The schedule information.
     */
    function getSchedule(
        string calldata username
    ) external view override returns (Schedule memory) {
        return schedulePayment[username];
    }
}
