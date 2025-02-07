// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {PluginUUPSUpgradeable} from "@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol";
import {IPayments} from "./interfaces/IPayments.sol";
import {Errors} from "./util/Errors.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title My Plugin
 * @notice A plugin that stores a number.
 */
contract PaymentsPlugin is PluginUUPSUpgradeable, IPayments, Errors {
    using SafeERC20 for IERC20;

    bytes32 public constant CREATE_PAYMENT_PERMISSION_ID =
        keccak256("CREATE_PAYMENT_PERMISSION");

    bytes32 public constant EDIT_PAYMENT_PERMISSION_ID =
        keccak256("EDIT_PAYMENT_PERMISSION");

    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping(string => address) private userDirectory;
    mapping(string => Schedule) private schedulePayment;
    mapping(string => Stream) private streamPayment;

    /// @notice Initializes the plugin with a number.
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
    ) external payable override {
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

    function createStream(
        string calldata username,
        uint256 amount,
        address token,
        uint40 endStream
    ) external payable override {
        address userAddress = userDirectory[username];

        if (userAddress == address(0)) {
            revert UserNotFound(username);
        }

        if (amount == 0) revert InvalidAmount();
        if (endStream <= block.timestamp) revert InvalidStreamEnd();

        Stream memory _stream = streamPayment[username];
        if (_stream.active) revert ActivePayment(username);

        uint40 _now = uint40(block.timestamp);

        streamPayment[username] = Stream(amount, token, _now, endStream, true);
        emit PaymentStreamActive(username, token, _now, amount);
    }

    function requestStreamPayout(
        string calldata username
    ) external payable override {
        _streamPayout(username, true);
    }

    function requestSchedulePayout(
        string calldata username
    ) external payable override {
        Schedule memory _schedule = schedulePayment[username];
        if (!_schedule.active) revert InActivePayment(username);

        uint40 currentTime = uint40(block.timestamp);
        if (currentTime < _schedule.nextPayout) revert NoPayoutDue();

        address recipient = userDirectory[username];

        uint256 payoutAmount = _schedule.amount;

        if (_schedule.isOneTime) {
            schedulePayment[username].active = false;
        } else {
            uint40 interval = uint40(30 days);
            uint40 nextPayout = _schedule.nextPayout + interval;

            // Ensure the next payout isn't set in the past and account for missed payouts
            if (nextPayout < currentTime) {
                uint40 missedIntervals = (currentTime - _schedule.nextPayout) /
                    interval;
                payoutAmount += _schedule.amount * missedIntervals;
                nextPayout =
                    _schedule.nextPayout +
                    (missedIntervals + 1) *
                    interval;
            }

            schedulePayment[username].nextPayout = nextPayout;
        }

        if (_schedule.token == ETH) {
            (bool success, ) = payable(recipient).call{value: payoutAmount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(_schedule.token).safeTransfer(recipient, payoutAmount);
        }

        emit Payout(username, _schedule.token, payoutAmount);
    }

    function cancelStream(string calldata username) external override {
        _streamPayout(username, false);

        streamPayment[username].active = false;
        emit PaymentStreamCancelled(username);
    }

    function cancelSchedule(string calldata username) external override {
        // _incompleteSchedulePayout(username);

        schedulePayment[username].active = false;
        emit PaymentScheduleCancelled(username);
    }

    function editStream(
        string calldata username,
        uint amount
    ) external override {
        if (amount == 0) revert InvalidAmount();

        Stream memory _stream = streamPayment[username];
        if (!_stream.active) revert InActivePayment(username);

        streamPayment[username].amount = amount;
        emit StreamUpdated(username, amount);
    }

    function editSchedule(
        string calldata username,
        uint amount
    ) external override {
        if (amount == 0) revert InvalidAmount();

        Schedule memory _schedule = schedulePayment[username];
        if (!_schedule.active) revert InActivePayment(username);

        uint40 currentTimestamp = uint40(block.timestamp);
        if ((_schedule.nextPayout - currentTimestamp) < 3 days)
            revert NoEditAccess();

        schedulePayment[username].amount = amount;
        emit ScheduleUpdated(username, amount);
    }

    function emergencyWithdraw(address tokenAddr) external override {
        if (tokenAddr == ETH) {
            uint amount = address(this).balance;
            (bool success, ) = payable(address(dao())).call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20 token = IERC20(tokenAddr);
            uint amount = token.balanceOf(address(this));
            token.safeTransfer(address(dao()), amount);
        }
    }

    function getStream(
        string calldata username
    ) external view override returns (Stream memory stream) {
        return streamPayment[username];
    }

    function getSchedule(
        string calldata username
    ) external view override returns (Schedule memory schedule) {
        return schedulePayment[username];
    }

    function claimUsername(string calldata username) external override {
        if (userDirectory[username] != address(0)) {
            revert UsernameAlreadyClaimed(username);
        }

        userDirectory[username] = msg.sender;
    }

    function _streamPayout(string calldata username, bool request) private {
        Stream memory _stream = streamPayment[username];
        if (!_stream.active) revert InActivePayment(username);

        uint40 currentTime = uint40(block.timestamp);
        if (request && currentTime < (_stream.lastPayout + 1 days))
            revert NoPayoutDue();

        address recipient = userDirectory[username];
        uint256 payoutAmount;

        if (currentTime >= _stream.endStream) {
            uint40 timeUntilEnd = _stream.endStream - _stream.lastPayout;
            payoutAmount = timeUntilEnd * _stream.amount;
            streamPayment[username].active = false;
        } else {
            uint40 elapsedTime = currentTime - _stream.lastPayout;
            payoutAmount = elapsedTime * _stream.amount;
        }

        streamPayment[username].lastPayout = currentTime;

        if (_stream.token == ETH) {
            (bool success, ) = payable(recipient).call{value: payoutAmount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(_stream.token).safeTransfer(recipient, payoutAmount);
        }
        emit Payout(username, _stream.token, payoutAmount);
    }

    function _incompleteSchedulePayout(string calldata username) private {
        Schedule memory _schedule = schedulePayment[username];
        if (!_schedule.active) revert InActivePayment(username);

        uint40 currentTime = uint40(block.timestamp);
        uint40 elapsedTime = currentTime -
            (_schedule.nextPayout - uint40(30 days));

        // Calculate the prorated payment amount
        uint256 proratedAmount = (elapsedTime * _schedule.amount) /
            uint40(30 days);

        address recipient = userDirectory[username];
        if (proratedAmount > 0) {
            if (_schedule.token == ETH) {
                (bool success, ) = payable(recipient).call{
                    value: proratedAmount
                }("");
                require(success, "ETH transfer failed");
            } else {
                IERC20(_schedule.token).safeTransfer(recipient, proratedAmount);
            }
            emit Payout(username, _schedule.token, proratedAmount);
        }
    }
}
