// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";

import {MyPluginSetup} from "../src/setup/MyPluginSetup.sol";
import {PluginRepoFactory} from "@aragon/osx/framework/plugin/repo/PluginRepoFactory.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {PluginSetupProcessor} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessor.sol";
import {TestToken} from "../test/mocks/TestToken.sol";
import {PaymentsPlugin} from "../src/PaymentsPlugin.sol";

contract Deploy is Script {
    modifier broadcast() {
        uint256 privKey = vm.envUint("DEPLOYMENT_PRIVATE_KEY");
        vm.startBroadcast(privKey);
        console.log("Deploying from:", vm.addr(privKey));

        _;

        vm.stopBroadcast();
    }

    function run() public broadcast {
        address maintainer = vm.envAddress("PLUGIN_MAINTAINER");
        address pluginRepoFactory = vm.envAddress("PLUGIN_REPO_FACTORY");
        string memory myPluginEnsSubdomain = vm.envString(
            "MY_PLUGIN_REPO_ENS_SUBDOMAIN"
        );
        string memory paymentsPluginEnsSubdomain = vm.envString(
            "PAYMENTS_PLUGIN_REPO_ENS_SUBDOMAIN"
        );

        // Deploy the plugin setup's
        (address myPluginSetup, PluginRepo myPluginRepo) = prepareMyPlugin(
            maintainer,
            PluginRepoFactory(pluginRepoFactory),
            myPluginEnsSubdomain
        );

        // Deploy the payments plugin setup
        (
            address paymentsPluginSetup,
            PluginRepo paymentsPluginRepo
        ) = preparePaymentsPlugin(
                maintainer,
                PluginRepoFactory(pluginRepoFactory),
                paymentsPluginEnsSubdomain
            );

        console.log("Chain ID:", block.chainid);

        console.log("");

        console.log("Plugins");
        console.log("- MyPluginSetup:", myPluginSetup);
        console.log("- PaymentsPluginSetup:", paymentsPluginSetup);
        console.log("");

        console.log("Plugin repositories");
        console.log("- MyPlugin repository:", address(myPluginRepo));
        console.log(
            "- PaymentsPlugin repository:",
            address(paymentsPluginRepo)
        );
    }

    function prepareMyPlugin(
        address maintainer,
        PluginRepoFactory pluginRepoFactory,
        string memory ensSubdomain
    ) internal returns (address pluginSetup, PluginRepo) {
        // Publish repo
        MyPluginSetup _pluginSetup = new MyPluginSetup();

        PluginRepo pluginRepo = pluginRepoFactory
            .createPluginRepoWithFirstVersion(
                ensSubdomain, // ENS repo subdomain left empty
                address(_pluginSetup),
                maintainer,
                " ",
                " "
            );
        return (address(_pluginSetup), pluginRepo);
    }

    function preparePaymentsPlugin(
        address maintainer,
        PluginRepoFactory pluginRepoFactory,
        string memory ensSubdomain
    ) internal returns (address pluginSetup, PluginRepo) {
        // Deploy plugin setup
        PaymentsPlugin _pluginSetup = new PaymentsPlugin();

        // Create plugin repo with first version
        PluginRepo pluginRepo = pluginRepoFactory
            .createPluginRepoWithFirstVersion(
                ensSubdomain,
                address(_pluginSetup),
                maintainer,
                "", // Replace with actual IPFS hash for metadata
                "" // Replace with actual IPFS hash for build
            );

        return (address(_pluginSetup), pluginRepo);
    }
}
