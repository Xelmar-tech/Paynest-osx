// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {PaynestDAOFactory, DAOParameters, Deployment} from "../src/factory/PaynestDAOFactory.sol";
import {PaymentsPluginSetup} from "../src/setup/PaymentsPluginSetup.sol";
import {PaymentsPlugin} from "../src/PaymentsPlugin.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {DAOFactory} from "@aragon/osx/framework/dao/DAOFactory.sol";
import {PluginSetupProcessor} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessor.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {PluginRepoFactory} from "@aragon/osx/framework/plugin/repo/PluginRepoFactory.sol";
import {Multisig} from "@aragon/osx/plugins/governance/multisig/Multisig.sol";
import {AragonTest} from "./util/AragonTest.sol";

contract PaynestDAOFactoryTest is Test {
    PaynestDAOFactory factory;
    PaymentsPluginSetup paymentsPluginSetup;
    PluginRepo paymentsPluginRepo;
    address deployer;

    // Core protocol addresses
    address daoFactory;
    address pluginSetupProcessor;
    address multisigPluginRepo;
    address pluginRepoFactory;

    function setUp() public virtual {
        // Fork Sepolia network
        vm.createSelectFork(vm.envString("TESTNET_RPC_URL"));

        // Set up deployer account
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        vm.startPrank(deployer);

        // Get core protocol addresses from environment
        daoFactory = vm.envAddress("DAO_FACTORY");
        pluginSetupProcessor = vm.envAddress("PLUGIN_SETUP_PROCESSOR");
        multisigPluginRepo = vm.envAddress("MULTISIG_PLUGIN_REPO_ADDRESS");
        pluginRepoFactory = vm.envAddress("PLUGIN_REPO_FACTORY");

        // Deploy PaymentsPluginSetup
        paymentsPluginSetup = new PaymentsPluginSetup();

        // Create plugin repo with first version using PluginRepoFactory
        PluginRepoFactory repoFactory = PluginRepoFactory(pluginRepoFactory);

        // Generate a unique subdomain for testing
        string memory testSubdomain = string(
            abi.encodePacked(
                "test-payments-plugin-",
                vm.toString(block.timestamp)
            )
        );

        // Create basic metadata for the release
        bytes memory releaseMetadata = bytes(
            '{"name": "Test Payments Plugin"}'
        );
        bytes memory buildMetadata = bytes('{"ui": false}');

        paymentsPluginRepo = repoFactory.createPluginRepoWithFirstVersion(
            testSubdomain,
            address(paymentsPluginSetup),
            deployer,
            releaseMetadata,
            buildMetadata
        );

        // Deploy the factory
        factory = new PaynestDAOFactory(
            daoFactory,
            PluginSetupProcessor(pluginSetupProcessor),
            PluginRepo(multisigPluginRepo),
            uint8(vm.envUint("MULTISIG_PLUGIN_RELEASE")),
            uint16(vm.envUint("MULTISIG_PLUGIN_BUILD")),
            paymentsPluginSetup,
            paymentsPluginRepo,
            1, // Initial payments release
            1 // Initial payments build
        );

        vm.stopPrank();
    }

    /// @notice Tests that the factory is initialized with correct addresses and settings
    /// @dev This test verifies that:
    /// 1. Factory is initialized with correct core protocol addresses
    /// 2. Factory is initialized with correct plugin repositories
    /// 3. Factory is initialized with correct plugin setups
    /// Invariants:
    /// - All addresses must be non-zero
    /// - All addresses must match the provided configuration
    /// - Plugin repositories must be properly linked
    function test_FactoryInitialization() public view {
        assertEq(
            address(factory.osxDaoFactory()),
            daoFactory,
            "Incorrect DAO factory address"
        );
        assertEq(
            address(factory.pluginSetupProcessor()),
            pluginSetupProcessor,
            "Incorrect PSP address"
        );
        assertEq(
            address(factory.multisigPluginRepo()),
            multisigPluginRepo,
            "Incorrect multisig repo address"
        );
        assertEq(
            address(factory.paymentsPluginSetup()),
            address(paymentsPluginSetup),
            "Incorrect payments setup address"
        );
        assertEq(
            address(factory.paymentsPluginRepo()),
            address(paymentsPluginRepo),
            "Incorrect payments repo address"
        );
    }

    /// @notice Tests the creation of a DAO with all plugins
    function test_CreateDao() public {
        vm.startPrank(deployer);

        // Prepare DAO parameters
        address[] memory multisigMembers = new address[](1);
        multisigMembers[0] = deployer;

        address[] memory paymentManagers = new address[](1);
        paymentManagers[0] = deployer;

        DAOParameters memory params = DAOParameters({
            minApprovals: 1,
            multisigMembers: multisigMembers,
            paymentManagers: paymentManagers
        });

        // Create the DAO
        Deployment memory deployment = factory.createDao(params);

        // Verify DAO creation
        assertTrue(address(deployment.dao) != address(0), "DAO not created");
        assertTrue(
            address(deployment.multisigPlugin) != address(0),
            "Multisig plugin not created"
        );
        assertTrue(
            address(deployment.paymentsPlugin) != address(0),
            "Payments plugin not created"
        );

        vm.stopPrank();
    }

    /// @notice Tests version updates for plugins
    function test_UpdatePluginVersions() public {
        vm.startPrank(deployer);

        // Update multisig version
        uint8 newMultisigRelease = 2;
        uint16 newMultisigBuild = 3;
        factory.updateMultisigVersion(newMultisigRelease, newMultisigBuild);
        assertEq(
            factory.multisigPluginRelease(),
            newMultisigRelease,
            "Multisig release not updated"
        );
        assertEq(
            factory.multisigPluginBuild(),
            newMultisigBuild,
            "Multisig build not updated"
        );

        // Update payments version
        uint8 newPaymentsRelease = 2;
        uint16 newPaymentsBuild = 2;
        factory.updatePaymentsVersion(newPaymentsRelease, newPaymentsBuild);
        assertEq(
            factory.paymentsPluginRelease(),
            newPaymentsRelease,
            "Payments release not updated"
        );
        assertEq(
            factory.paymentsPluginBuild(),
            newPaymentsBuild,
            "Payments build not updated"
        );

        vm.stopPrank();
    }
}
