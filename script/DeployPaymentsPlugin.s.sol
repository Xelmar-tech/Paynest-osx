// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {PaymentsPluginSetup} from "../src/setup/PaymentsPluginSetup.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {PluginRepoFactory} from "@aragon/osx/framework/plugin/repo/PluginRepoFactory.sol";

contract DeployPaymentsPlugin is Script {
    /// @notice Runs the deployment of PaymentsPlugin and its setup
    function run() public {
        uint256 privKey = vm.envUint("DEPLOYMENT_PRIVATE_KEY");
        vm.startBroadcast(privKey);
        console.log("Deploying from:", vm.addr(privKey));

        // Deploy the payments plugin setup
        PaymentsPluginSetup paymentsPluginSetup = new PaymentsPluginSetup();
        console.log(
            "PaymentsPluginSetup deployed at:",
            address(paymentsPluginSetup)
        );

        // Create plugin repo
        PluginRepoFactory pluginRepoFactory = PluginRepoFactory(
            vm.envAddress("PLUGIN_REPO_FACTORY")
        );

        PluginRepo pluginRepo = pluginRepoFactory
            .createPluginRepoWithFirstVersion(
                vm.envString("PAYMENTS_PLUGIN_REPO_ENS_SUBDOMAIN"),
                address(paymentsPluginSetup),
                vm.addr(privKey), // Owner of the repo
                "0x0000000000000000000000000000000000000000000000000000000000000020", // Temporary metadata
                "0x0000000000000000000000000000000000000000000000000000000000000020" // Temporary build metadata
            );
        console.log("PaymentsPlugin repo deployed at:", address(pluginRepo));

        vm.stopBroadcast();

        // Print summary
        console.log("\nDeployment Summary");
        console.log("------------------");
        console.log("Chain ID:", block.chainid);
        console.log("PaymentsPluginSetup:", address(paymentsPluginSetup));
        console.log("PaymentsPlugin Repo:", address(pluginRepo));
    }
}
