// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {DAOFactory} from "@aragon/osx/framework/dao/DAOFactory.sol";
import {PluginSetupProcessor} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessor.sol";
import {hashHelpers, PluginSetupRef} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessorHelpers.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {PluginRepoFactory} from "@aragon/osx/framework/plugin/repo/PluginRepoFactory.sol";
import {IPluginSetup} from "@aragon/osx/framework/plugin/setup/IPluginSetup.sol";
import {Admin} from "@aragon/osx/plugins/governance/admin/Admin.sol";
import {AdminSetup} from "@aragon/osx/plugins/governance/admin/AdminSetup.sol";
import {Multisig} from "@aragon/osx/plugins/governance/multisig/Multisig.sol";
import {PaymentsPluginSetup} from "../setup/PaymentsPluginSetup.sol";

/// @title SimpleDAOFactory
/// @notice A factory contract for creating DAOs with pre-deployed Admin/Multisig and Payments plugins
contract SimpleDAOFactory {
    /// @notice The DAO factory from Aragon OSx framework
    DAOFactory public immutable daoFactory;

    /// @notice The plugin setup processor from Aragon OSx framework
    PluginSetupProcessor public immutable pluginSetupProcessor;

    /// @notice The pre-deployed Admin plugin repository
    PluginRepo public immutable adminPluginRepo;

    /// @notice The pre-deployed Multisig plugin repository
    PluginRepo public immutable multisigPluginRepo;

    /// @notice The Payments plugin repository created and owned by this factory
    PluginRepo public immutable paymentsPluginRepo;

    /// @notice The Payments plugin setup contract
    PaymentsPluginSetup public immutable paymentsPluginSetup;

    /// @notice Emitted when a new Admin-controlled DAO is created
    /// @param dao The address of the created DAO
    /// @param admin The address of the installed Admin plugin
    /// @param payments The address of the installed Payments plugin
    event AdminDAOCreated(
        address indexed dao,
        address indexed admin,
        address indexed payments
    );

    /// @notice Emitted when a new Multisig-controlled DAO is created
    /// @param dao The address of the created DAO
    /// @param multisig The address of the installed Multisig plugin
    /// @param payments The address of the installed Payments plugin
    event MultisigDAOCreated(
        address indexed dao,
        address indexed multisig,
        address indexed payments
    );

    /// @notice Settings for Multisig plugin
    /// @param minApprovals The minimum number of approvals needed
    /// @param members The addresses of multisig members
    struct MultisigSettings {
        uint16 minApprovals;
        address[] members;
    }

    /// @notice Initializes the factory with required contract addresses and creates the Payments plugin repo
    /// @param _daoFactory The Aragon OSx DAO factory
    /// @param _pluginSetupProcessor The Aragon OSx plugin setup processor
    /// @param _pluginRepoFactory The Aragon OSx plugin repo factory
    /// @param _adminPluginRepo The pre-deployed Admin plugin repository
    /// @param _multisigPluginRepo The pre-deployed Multisig plugin repository
    /// @param _paymentsPluginRepoSubdomain The ENS subdomain for the Payments plugin repo
    constructor(
        DAOFactory _daoFactory,
        PluginSetupProcessor _pluginSetupProcessor,
        PluginRepoFactory _pluginRepoFactory,
        PluginRepo _adminPluginRepo,
        PluginRepo _multisigPluginRepo,
        string memory _paymentsPluginRepoSubdomain
    ) {
        daoFactory = _daoFactory;
        pluginSetupProcessor = _pluginSetupProcessor;
        adminPluginRepo = _adminPluginRepo;
        multisigPluginRepo = _multisigPluginRepo;

        // Deploy Payments plugin setup
        paymentsPluginSetup = new PaymentsPluginSetup();

        // Create Payments plugin repo owned by this factory
        paymentsPluginRepo = _pluginRepoFactory
            .createPluginRepoWithFirstVersion(
                _paymentsPluginRepoSubdomain,
                address(paymentsPluginSetup),
                address(this),
                bytes(""), // Empty metadata for now
                bytes("") // Empty build metadata for now
            );
    }

    /// @notice Creates a new Admin-controlled DAO with Admin and Payments plugins installed
    /// @param _daoSettings The settings for the new DAO (name, metadata, etc)
    /// @param _adminSettings The settings for the Admin plugin (admin address)
    /// @return dao The address of the created DAO
    /// @return adminPlugin The address of the installed Admin plugin
    /// @return paymentsPlugin The address of the installed Payments plugin
    function createAdminDAO(
        DAOFactory.DAOSettings calldata _daoSettings,
        bytes calldata _adminSettings
    )
        external
        returns (address dao, address adminPlugin, address paymentsPlugin)
    {
        // Prepare plugin settings
        DAOFactory.PluginSettings[]
            memory pluginSettings = new DAOFactory.PluginSettings[](2);

        // Admin plugin settings
        pluginSettings[0] = DAOFactory.PluginSettings({
            pluginSetupRef: PluginSetupRef({
                versionTag: PluginRepo.Tag(1, 1), // Use latest version
                pluginSetupRepo: adminPluginRepo
            }),
            data: _adminSettings
        });

        // Payments plugin settings (no initialization parameters needed)
        pluginSettings[1] = DAOFactory.PluginSettings({
            pluginSetupRef: PluginSetupRef({
                versionTag: PluginRepo.Tag(1, 1), // Use latest version
                pluginSetupRepo: paymentsPluginRepo
            }),
            data: "" // No initialization parameters needed
        });

        // Create DAO with plugins
        DAO createdDao = daoFactory.createDao(_daoSettings, pluginSettings);
        dao = address(createdDao);

        // Get installed plugin addresses
        adminPlugin = _getPluginInstallationAddress(
            dao,
            adminPluginRepo,
            PluginRepo.Tag(1, 1)
        );
        paymentsPlugin = _getPluginInstallationAddress(
            dao,
            paymentsPluginRepo,
            PluginRepo.Tag(1, 1)
        );

        emit AdminDAOCreated(dao, adminPlugin, paymentsPlugin);
    }

    /// @notice Creates a new Multisig-controlled DAO with Multisig and Payments plugins installed
    /// @param _daoSettings The settings for the new DAO (name, metadata, etc)
    /// @param _multisigSettings The settings for the Multisig plugin
    /// @return dao The address of the created DAO
    /// @return multisigPlugin The address of the installed Multisig plugin
    /// @return paymentsPlugin The address of the installed Payments plugin
    function createMultisigDAO(
        DAOFactory.DAOSettings calldata _daoSettings,
        MultisigSettings calldata _multisigSettings
    )
        external
        returns (address dao, address multisigPlugin, address paymentsPlugin)
    {
        // Prepare plugin settings
        DAOFactory.PluginSettings[]
            memory pluginSettings = new DAOFactory.PluginSettings[](2);

        // Multisig plugin settings
        bytes memory multisigData = abi.encode(
            _multisigSettings.members,
            Multisig.MultisigSettings({
                minApprovals: _multisigSettings.minApprovals,
                onlyListed: true
            })
        );

        pluginSettings[0] = DAOFactory.PluginSettings({
            pluginSetupRef: PluginSetupRef({
                versionTag: PluginRepo.Tag(1, 1), // Use latest version
                pluginSetupRepo: multisigPluginRepo
            }),
            data: multisigData
        });

        // Payments plugin settings (no initialization parameters needed)
        pluginSettings[1] = DAOFactory.PluginSettings({
            pluginSetupRef: PluginSetupRef({
                versionTag: PluginRepo.Tag(1, 1), // Use latest version
                pluginSetupRepo: paymentsPluginRepo
            }),
            data: "" // No initialization parameters needed
        });

        // Create DAO with plugins
        DAO createdDao = daoFactory.createDao(_daoSettings, pluginSettings);
        dao = address(createdDao);

        // Get installed plugin addresses
        multisigPlugin = _getPluginInstallationAddress(
            dao,
            multisigPluginRepo,
            PluginRepo.Tag(1, 1)
        );
        paymentsPlugin = _getPluginInstallationAddress(
            dao,
            paymentsPluginRepo,
            PluginRepo.Tag(1, 1)
        );

        emit MultisigDAOCreated(dao, multisigPlugin, paymentsPlugin);
    }

    /// @notice Helper function to get the address of an installed plugin
    /// @param _dao The DAO address
    /// @param _pluginRepo The plugin repository
    /// @param _versionTag The version tag of the plugin
    /// @return The address of the installed plugin
    function _getPluginInstallationAddress(
        address _dao,
        PluginRepo _pluginRepo,
        PluginRepo.Tag memory _versionTag
    ) internal returns (address) {
        (address plugin, ) = pluginSetupProcessor.prepareInstallation(
            _dao,
            PluginSetupProcessor.PrepareInstallationParams({
                pluginSetupRef: PluginSetupRef({
                    versionTag: _versionTag,
                    pluginSetupRepo: _pluginRepo
                }),
                data: ""
            })
        );

        return plugin;
    }
}
