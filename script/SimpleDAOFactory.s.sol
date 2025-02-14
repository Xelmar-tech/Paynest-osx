// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {SimpleDAOFactory} from "../src/factory/SimpleDAOFactory.sol";
import {DAOFactory} from "@aragon/osx/framework/dao/DAOFactory.sol";
import {PluginSetupProcessor} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessor.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {PluginRepoFactory} from "@aragon/osx/framework/plugin/repo/PluginRepoFactory.sol";

contract SimpleDAOFactoryScript is Script {
    function run() public {
        // Load private key for deployment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Load contract addresses from environment
        address daoFactoryAddr = vm.envAddress("DAO_FACTORY");
        address pluginSetupProcessorAddr = vm.envAddress(
            "PLUGIN_SETUP_PROCESSOR"
        );
        address pluginRepoFactoryAddr = vm.envAddress("PLUGIN_REPO_FACTORY");
        address adminPluginRepoAddr = vm.envAddress("ADMIN_PLUGIN_REPO");
        address multisigPluginRepoAddr = vm.envAddress("MULTISIG_PLUGIN_REPO");
        string memory paymentsPluginRepoSubdomain = vm.envString(
            "PAYMENTS_PLUGIN_REPO_SUBDOMAIN"
        );

        vm.startBroadcast(deployerPrivateKey);

        // Deploy SimpleDAOFactory
        SimpleDAOFactory factory = new SimpleDAOFactory(
            DAOFactory(daoFactoryAddr),
            PluginSetupProcessor(pluginSetupProcessorAddr),
            PluginRepoFactory(pluginRepoFactoryAddr),
            PluginRepo(adminPluginRepoAddr),
            PluginRepo(multisigPluginRepoAddr),
            paymentsPluginRepoSubdomain
        );

        vm.stopBroadcast();

        // Print deployment summary
        console.log("");
        console.log("Chain ID:", block.chainid);
        console.log("SimpleDAOFactory:", address(factory));
        console.log("");
        console.log("Configuration");
        console.log("- DAO Factory:", daoFactoryAddr);
        console.log("- Plugin Setup Processor:", pluginSetupProcessorAddr);
        console.log("- Plugin Repo Factory:", pluginRepoFactoryAddr);
        console.log("- Admin Plugin Repo:", adminPluginRepoAddr);
        console.log("- Multisig Plugin Repo:", multisigPluginRepoAddr);
        console.log(
            "- Payments Plugin Repo Subdomain:",
            paymentsPluginRepoSubdomain
        );
        console.log(
            "- Payments Plugin Repo:",
            address(factory.paymentsPluginRepo())
        );
        console.log(
            "- Payments Plugin Setup:",
            address(factory.paymentsPluginSetup())
        );
    }
}
