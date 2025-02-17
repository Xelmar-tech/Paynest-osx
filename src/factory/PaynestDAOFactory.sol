// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {DAOFactory} from "@aragon/osx/framework/dao/DAOFactory.sol";
import {PluginSetupProcessor} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessor.sol";
import {hashHelpers, PluginSetupRef} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessorHelpers.sol";
import {PluginRepoFactory} from "@aragon/osx/framework/plugin/repo/PluginRepoFactory.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {IPluginSetup} from "@aragon/osx/framework/plugin/setup/IPluginSetup.sol";
import {Multisig} from "@aragon/osx/plugins/governance/multisig/Multisig.sol";
import {MultisigSetup as MultisigPluginSetup} from "@aragon/osx/plugins/governance/multisig/MultisigSetup.sol";
import {createERC1967Proxy} from "@aragon/osx/utils/Proxy.sol";
import {PermissionLib} from "@aragon/osx/core/permission/PermissionLib.sol";
import {PaymentsPluginSetup} from "../setup/PaymentsPluginSetup.sol";
import {PaymentsPlugin} from "../PaymentsPlugin.sol";

/// @notice Parameters needed for each new DAO deployment
struct DAOParameters {
    // Multisig settings
    uint16 minApprovals;
    address[] multisigMembers;
    // Payments plugin settings
    address[] paymentManagers;
}

/// @notice Contains the artifacts that resulted from running a deployment
struct Deployment {
    DAO dao;
    // Plugins
    Multisig multisigPlugin;
    PaymentsPlugin paymentsPlugin;
}

/// @notice A factory contract that can create multiple DAOs with payments and multisig plugins
contract PaynestDAOFactory {
    // Immutable state set at deployment
    address public immutable osxDaoFactory;
    PluginSetupProcessor public immutable pluginSetupProcessor;

    // Multisig plugin state
    PluginRepo public immutable multisigPluginRepo;
    uint8 public multisigPluginRelease; // Made mutable
    uint16 public multisigPluginBuild; // Made mutable

    // Payments plugin state
    PaymentsPluginSetup public immutable paymentsPluginSetup;
    PluginRepo public immutable paymentsPluginRepo;
    uint8 public paymentsPluginRelease; // Added
    uint16 public paymentsPluginBuild; // Added

    // Events for version updates
    event MultisigVersionUpdated(uint8 release, uint16 build);
    event PaymentsVersionUpdated(uint8 release, uint16 build);

    /// @notice Initializes the factory with the core infrastructure addresses
    constructor(
        address _osxDaoFactory,
        PluginSetupProcessor _pluginSetupProcessor,
        PluginRepo _multisigPluginRepo,
        uint8 _multisigPluginRelease,
        uint16 _multisigPluginBuild,
        PaymentsPluginSetup _paymentsPluginSetup,
        PluginRepo _paymentsPluginRepo,
        uint8 _paymentsPluginRelease,
        uint16 _paymentsPluginBuild
    ) {
        osxDaoFactory = _osxDaoFactory;
        pluginSetupProcessor = _pluginSetupProcessor;
        multisigPluginRepo = _multisigPluginRepo;
        multisigPluginRelease = _multisigPluginRelease;
        multisigPluginBuild = _multisigPluginBuild;
        paymentsPluginSetup = _paymentsPluginSetup;
        paymentsPluginRepo = _paymentsPluginRepo;
        paymentsPluginRelease = _paymentsPluginRelease;
        paymentsPluginBuild = _paymentsPluginBuild;
    }

    /// @notice Updates the multisig plugin version
    /// @param newRelease The new release version
    /// @param newBuild The new build version
    function updateMultisigVersion(uint8 newRelease, uint16 newBuild) external {
        // TODO: Add access control
        multisigPluginRelease = newRelease;
        multisigPluginBuild = newBuild;
        emit MultisigVersionUpdated(newRelease, newBuild);
    }

    /// @notice Updates the payments plugin version
    /// @param newRelease The new release version
    /// @param newBuild The new build version
    function updatePaymentsVersion(uint8 newRelease, uint16 newBuild) external {
        // TODO: Add access control
        paymentsPluginRelease = newRelease;
        paymentsPluginBuild = newBuild;
        emit PaymentsVersionUpdated(newRelease, newBuild);
    }

    /// @notice Creates a new DAO with the specified parameters
    function createDao(
        DAOParameters calldata parameters
    ) public returns (Deployment memory deployment) {
        // Deploy the DAO (this contract is the interim owner)
        DAO dao = prepareDao();
        deployment.dao = dao;

        // Deploy and install the plugins
        grantApplyInstallationPermissions(dao);

        // MULTISIG
        {
            IPluginSetup.PreparedSetupData memory preparedMultisigSetupData;

            PluginRepo.Tag memory repoTag = PluginRepo.Tag(
                multisigPluginRelease,
                multisigPluginBuild
            );

            (
                deployment.multisigPlugin,
                preparedMultisigSetupData
            ) = prepareMultisig(dao, repoTag, parameters);

            applyPluginInstallation(
                dao,
                address(deployment.multisigPlugin),
                multisigPluginRepo,
                repoTag,
                preparedMultisigSetupData
            );
        }

        // PAYMENTS PLUGIN
        {
            IPluginSetup.PreparedSetupData memory preparedPaymentsSetupData;
            PluginRepo.Tag memory repoTag = PluginRepo.Tag(
                paymentsPluginRelease,
                paymentsPluginBuild
            );

            // Prepare and install plugin
            (
                deployment.paymentsPlugin,
                preparedPaymentsSetupData
            ) = preparePaymentsPlugin(
                dao,
                paymentsPluginRepo,
                repoTag,
                parameters
            );

            applyPluginInstallation(
                dao,
                address(deployment.paymentsPlugin),
                paymentsPluginRepo,
                repoTag,
                preparedPaymentsSetupData
            );
        }

        // Clean up
        revokeApplyInstallationPermissions(dao);
        revokeOwnerPermission(dao);

        return deployment;
    }

    function prepareDao() internal returns (DAO dao) {
        address daoBase = DAOFactory(osxDaoFactory).daoBase();

        dao = DAO(
            payable(
                createERC1967Proxy(
                    address(daoBase),
                    abi.encodeCall(
                        DAO.initialize,
                        (
                            "", // Metadata URI
                            address(this), // initialOwner
                            address(0x0), // Trusted forwarder
                            "" // DAO URI
                        )
                    )
                )
            )
        );

        // Grant DAO all the needed permissions on itself
        PermissionLib.SingleTargetPermission[]
            memory items = new PermissionLib.SingleTargetPermission[](3);
        items[0] = PermissionLib.SingleTargetPermission(
            PermissionLib.Operation.Grant,
            address(dao),
            dao.ROOT_PERMISSION_ID()
        );
        items[1] = PermissionLib.SingleTargetPermission(
            PermissionLib.Operation.Grant,
            address(dao),
            dao.UPGRADE_DAO_PERMISSION_ID()
        );
        items[2] = PermissionLib.SingleTargetPermission(
            PermissionLib.Operation.Grant,
            address(dao),
            dao.REGISTER_STANDARD_CALLBACK_PERMISSION_ID()
        );

        dao.applySingleTargetPermissions(address(dao), items);
    }

    function prepareMultisig(
        DAO dao,
        PluginRepo.Tag memory repoTag,
        DAOParameters calldata parameters
    ) internal returns (Multisig, IPluginSetup.PreparedSetupData memory) {
        bytes memory settingsData = abi.encode(
            parameters.multisigMembers,
            Multisig.MultisigSettings(
                true, // onlyListed
                parameters.minApprovals
            )
        );

        (
            address plugin,
            IPluginSetup.PreparedSetupData memory preparedSetupData
        ) = pluginSetupProcessor.prepareInstallation(
                address(dao),
                PluginSetupProcessor.PrepareInstallationParams(
                    PluginSetupRef(repoTag, multisigPluginRepo),
                    settingsData
                )
            );

        return (Multisig(plugin), preparedSetupData);
    }

    function preparePaymentsPlugin(
        DAO dao,
        PluginRepo pluginRepo,
        PluginRepo.Tag memory repoTag,
        DAOParameters calldata parameters
    ) internal returns (PaymentsPlugin, IPluginSetup.PreparedSetupData memory) {
        // Encode the payment managers for initialization
        bytes memory settingsData = abi.encode(parameters.paymentManagers);

        (
            address plugin,
            IPluginSetup.PreparedSetupData memory preparedSetupData
        ) = pluginSetupProcessor.prepareInstallation(
                address(dao),
                PluginSetupProcessor.PrepareInstallationParams(
                    PluginSetupRef(repoTag, pluginRepo),
                    settingsData
                )
            );

        return (PaymentsPlugin(plugin), preparedSetupData);
    }

    function applyPluginInstallation(
        DAO dao,
        address plugin,
        PluginRepo pluginRepo,
        PluginRepo.Tag memory pluginRepoTag,
        IPluginSetup.PreparedSetupData memory preparedSetupData
    ) internal {
        pluginSetupProcessor.applyInstallation(
            address(dao),
            PluginSetupProcessor.ApplyInstallationParams(
                PluginSetupRef(pluginRepoTag, pluginRepo),
                plugin,
                preparedSetupData.permissions,
                hashHelpers(preparedSetupData.helpers)
            )
        );
    }

    function grantApplyInstallationPermissions(DAO dao) internal {
        // The PSP can manage permissions on the new DAO
        dao.grant(
            address(dao),
            address(pluginSetupProcessor),
            dao.ROOT_PERMISSION_ID()
        );

        // This factory can call applyInstallation() on the PSP
        dao.grant(
            address(pluginSetupProcessor),
            address(this),
            pluginSetupProcessor.APPLY_INSTALLATION_PERMISSION_ID()
        );
    }

    function revokeApplyInstallationPermissions(DAO dao) internal {
        // Revoking the permission for the factory to call applyInstallation() on the PSP
        dao.revoke(
            address(pluginSetupProcessor),
            address(this),
            pluginSetupProcessor.APPLY_INSTALLATION_PERMISSION_ID()
        );

        // Revoke the PSP permission to manage permissions on the new DAO
        dao.revoke(
            address(dao),
            address(pluginSetupProcessor),
            dao.ROOT_PERMISSION_ID()
        );
    }

    function revokeOwnerPermission(DAO dao) internal {
        dao.revoke(address(dao), address(this), dao.ROOT_PERMISSION_ID());
    }
}
