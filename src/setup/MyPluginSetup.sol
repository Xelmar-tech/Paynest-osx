// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IPluginSetup} from "@aragon/osx/framework/plugin/setup/IPluginSetup.sol";
import {PluginSetup} from "@aragon/osx/framework/plugin/setup/PluginSetup.sol";
import {MyPlugin} from "../MyPlugin.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {createProxyAndCall} from "../util/proxy.sol";
import {PermissionLib} from "@aragon/osx/core/permission/PermissionLib.sol";

/**
 * @title MyPluginSetup
 * @notice Setup contract for MyPlugin. Deploys and initializes MyPlugin with the given initial number.
 */
contract MyPluginSetup is PluginSetup {
    address public immutable pluginImplementation;

    constructor() {
        pluginImplementation = address(new MyPlugin());
    }

    function implementation() public view returns (address) {
        return pluginImplementation;
    }

    /// @notice Prepares the installation of MyPlugin.
    /// @param _dao The DAO address.
    /// @param _installParameters ABI encoded uint256 representing the initial number.
    /// @return plugin The address of the deployed plugin proxy.
    /// @return preparedSetupData Setup data with empty helpers and permissions.
    function prepareInstallation(
        address _dao,
        bytes calldata _installParameters
    )
        external
        override
        returns (address plugin, PreparedSetupData memory preparedSetupData)
    {
        uint256 initialNumber = abi.decode(_installParameters, (uint256));
        plugin = createProxyAndCall(
            implementation(),
            abi.encodeWithSelector(
                MyPlugin.initialize.selector,
                _dao,
                initialNumber
            )
        );
        preparedSetupData.helpers = new address[](0);
        preparedSetupData
            .permissions = new PermissionLib.MultiTargetPermission[](0);
    }

    /// @notice Prepares the uninstallation of MyPlugin.
    function prepareUninstallation(
        address,
        SetupPayload calldata
    )
        external
        pure
        override
        returns (PermissionLib.MultiTargetPermission[] memory permissions)
    {
        permissions = new PermissionLib.MultiTargetPermission[](0);
    }
}
