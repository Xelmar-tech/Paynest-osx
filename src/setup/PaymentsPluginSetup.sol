// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPluginSetup} from "@aragon/osx/framework/plugin/setup/IPluginSetup.sol";
import {PluginSetup} from "@aragon/osx/framework/plugin/setup/PluginSetup.sol";
import {PaymentsPlugin} from "../PaymentsPlugin.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {createProxyAndCall} from "../util/proxy.sol";
import {PermissionLib} from "@aragon/osx/core/permission/PermissionLib.sol";

/**
 * @title PaymentsPluginSetup
 * @notice Setup contract for PaymentsPlugin. Deploys and initializes PaymentsPlugin with the required permissions.
 */
contract PaymentsPluginSetup is PluginSetup {
    address public immutable pluginImplementation;

    constructor() {
        pluginImplementation = address(new PaymentsPlugin());
    }

    function implementation() public view returns (address) {
        return pluginImplementation;
    }

    /// @notice Prepares the installation of PaymentsPlugin.
    /// @param _dao The DAO address.
    /// @param _installParameters ABI encoded address[] of payment managers
    /// @return plugin The address of the deployed plugin proxy.
    /// @return preparedSetupData Setup data with permissions for payment management.
    function prepareInstallation(
        address _dao,
        bytes calldata _installParameters
    )
        external
        override
        returns (address plugin, PreparedSetupData memory preparedSetupData)
    {
        // Decode payment managers from installation parameters
        address[] memory paymentManagers = abi.decode(
            _installParameters,
            (address[])
        );

        // Deploy plugin proxy and initialize it
        plugin = createProxyAndCall(
            implementation(),
            abi.encodeWithSelector(PaymentsPlugin.initialize.selector, _dao)
        );

        // Calculate total number of permissions needed
        // 3 base permissions + 2 permissions per payment manager (create and edit)
        uint256 permissionLength = 3 + (paymentManagers.length * 2);

        // Prepare permissions
        PermissionLib.MultiTargetPermission[]
            memory permissions = new PermissionLib.MultiTargetPermission[](
                permissionLength
            );

        // Grant CREATE_PAYMENT_PERMISSION to the DAO
        permissions[0] = PermissionLib.MultiTargetPermission(
            PermissionLib.Operation.Grant,
            plugin, // where
            _dao, // who
            address(0), // condition
            PaymentsPlugin(plugin).CREATE_PAYMENT_PERMISSION_ID() // permissionId
        );

        // Grant EDIT_PAYMENT_PERMISSION to the DAO
        permissions[1] = PermissionLib.MultiTargetPermission(
            PermissionLib.Operation.Grant,
            plugin, // where
            _dao, // who
            address(0), // condition
            PaymentsPlugin(plugin).EDIT_PAYMENT_PERMISSION_ID() // permissionId
        );

        // Grant EXECUTE_PERMISSION on the DAO to the plugin
        permissions[2] = PermissionLib.MultiTargetPermission(
            PermissionLib.Operation.Grant,
            _dao, // where
            plugin, // who
            PermissionLib.NO_CONDITION,
            DAO(payable(_dao)).EXECUTE_PERMISSION_ID() // permissionId
        );

        // Grant permissions to each payment manager
        for (uint256 i = 0; i < paymentManagers.length; i++) {
            // Grant CREATE_PAYMENT_PERMISSION
            permissions[3 + (i * 2)] = PermissionLib.MultiTargetPermission(
                PermissionLib.Operation.Grant,
                plugin, // where
                paymentManagers[i], // who
                address(0), // condition
                PaymentsPlugin(plugin).CREATE_PAYMENT_PERMISSION_ID() // permissionId
            );

            // Grant EDIT_PAYMENT_PERMISSION
            permissions[3 + (i * 2) + 1] = PermissionLib.MultiTargetPermission(
                PermissionLib.Operation.Grant,
                plugin, // where
                paymentManagers[i], // who
                address(0), // condition
                PaymentsPlugin(plugin).EDIT_PAYMENT_PERMISSION_ID() // permissionId
            );
        }

        preparedSetupData.helpers = new address[](0);
        preparedSetupData.permissions = permissions;

        return (plugin, preparedSetupData);
    }

    /// @notice Prepares the uninstallation of PaymentsPlugin.
    /// @dev Revokes all permissions granted on installation.
    function prepareUninstallation(
        address _dao,
        SetupPayload calldata _payload
    )
        external
        view
        override
        returns (PermissionLib.MultiTargetPermission[] memory permissions)
    {
        // Prepare permissions to be revoked
        permissions = new PermissionLib.MultiTargetPermission[](3);

        // Revoke CREATE_PAYMENT_PERMISSION from DAO
        permissions[0] = PermissionLib.MultiTargetPermission(
            PermissionLib.Operation.Revoke,
            _payload.plugin, // where
            _dao, // who
            address(0), // condition
            PaymentsPlugin(_payload.plugin).CREATE_PAYMENT_PERMISSION_ID() // permissionId
        );

        // Revoke EDIT_PAYMENT_PERMISSION from DAO
        permissions[1] = PermissionLib.MultiTargetPermission(
            PermissionLib.Operation.Revoke,
            _payload.plugin, // where
            _dao, // who
            address(0), // condition
            PaymentsPlugin(_payload.plugin).EDIT_PAYMENT_PERMISSION_ID() // permissionId
        );

        // Revoke EXECUTE_PERMISSION from plugin
        permissions[2] = PermissionLib.MultiTargetPermission(
            PermissionLib.Operation.Revoke,
            _dao, // where
            _payload.plugin, // who
            PermissionLib.NO_CONDITION,
            DAO(payable(_dao)).EXECUTE_PERMISSION_ID() // permissionId
        );
    }
}
