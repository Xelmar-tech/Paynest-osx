// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {XelamarDAOFactory, DeploymentParameters, Deployment} from "../src/factory/XelamarDAOFactory.sol";
import {MultisigSetup as MultisigPluginSetup} from "@aragon/osx/plugins/governance/multisig/MultisigSetup.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {PluginRepoFactory} from "@aragon/osx/framework/plugin/repo/PluginRepoFactory.sol";
import {PluginSetupProcessor} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessor.sol";
import {PaymentsPluginSetup} from "../src/setup/PaymentsPluginSetup.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract DeployXelamar is Script {
    using SafeCast for uint256;

    /// @dev Thrown when attempting to deploy a multisig with no members
    error EmptyMultisig();

    modifier broadcast() {
        uint256 privKey = vm.envUint("DEPLOYMENT_PRIVATE_KEY");
        vm.startBroadcast(privKey);
        console.log("Deploying from:", vm.addr(privKey));

        _;

        vm.stopBroadcast();
    }

    /// @notice Runs the deployment flow, records the given parameters and artifacts, and it becomes read only
    function run() public broadcast {
        // Prepare all parameters
        DeploymentParameters memory parameters = getDeploymentParameters();

        // Create the DAO
        XelamarDAOFactory factory = new XelamarDAOFactory(parameters);
        factory.deployOnce();

        // Done
        printDeploymentSummary(factory);
    }

    function getDeploymentParameters()
        public
        returns (DeploymentParameters memory parameters)
    {
        address[] memory multisigMembers = readMultisigMembers();

        // Deploy the payments plugin setup
        PaymentsPluginSetup paymentsPluginSetup = new PaymentsPluginSetup();

        parameters = DeploymentParameters({
            // Multisig settings
            minApprovals: vm.envUint("MIN_APPROVALS").toUint16(),
            multisigMembers: multisigMembers,
            // Payments plugin settings
            paymentsPluginEnsSubdomain: vm.envString(
                "PAYMENTS_PLUGIN_REPO_ENS_SUBDOMAIN"
            ),
            // Standard multisig repo
            multisigPluginRepo: PluginRepo(
                vm.envAddress("MULTISIG_PLUGIN_REPO_ADDRESS")
            ),
            multisigPluginRelease: vm
                .envUint("MULTISIG_PLUGIN_RELEASE")
                .toUint8(),
            multisigPluginBuild: vm.envUint("MULTISIG_PLUGIN_BUILD").toUint16(),
            // Payments plugin setup
            paymentsPluginSetup: paymentsPluginSetup,
            // OSx addresses
            osxDaoFactory: vm.envAddress("DAO_FACTORY"),
            pluginSetupProcessor: PluginSetupProcessor(
                vm.envAddress("PLUGIN_SETUP_PROCESSOR")
            ),
            pluginRepoFactory: PluginRepoFactory(
                vm.envAddress("PLUGIN_REPO_FACTORY")
            )
        });
    }

    function readMultisigMembers()
        public
        view
        returns (address[] memory result)
    {
        // JSON list of members
        string memory membersFilePath = vm.envString(
            "MULTISIG_MEMBERS_JSON_FILE_NAME"
        );
        string memory path = string.concat(vm.projectRoot(), membersFilePath);
        string memory strJson = vm.readFile(path);

        bool exists = vm.keyExistsJson(strJson, "$.members");
        if (!exists) revert EmptyMultisig();

        result = vm.parseJsonAddressArray(strJson, "$.members");

        if (result.length == 0) revert EmptyMultisig();
    }

    function printDeploymentSummary(XelamarDAOFactory factory) internal view {
        Deployment memory deployment = factory.getDeployment();

        console.log("");
        console.log("Chain ID:", block.chainid);
        console.log("Factory:", address(factory));
        console.log("");
        console.log("DAO:", address(deployment.dao));
        console.log("");

        console.log("Plugins");
        console.log("- Multisig plugin:", address(deployment.multisigPlugin));
        console.log("- Payments plugin:", address(deployment.paymentsPlugin));
        console.log("");

        console.log("Plugin repositories");
        console.log(
            "- Multisig plugin repository (existing):",
            address(factory.getDeploymentParameters().multisigPluginRepo)
        );
        console.log(
            "- Payments plugin repository:",
            address(deployment.paymentsPluginRepo)
        );
    }
}
