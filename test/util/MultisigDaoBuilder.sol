// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {createProxyAndCall} from "../../src/util/proxy.sol";
import {ALICE_ADDRESS} from "../constants.sol";
import {PaymentsPlugin} from "../../src/PaymentsPlugin.sol";
import {Multisig} from "../../lib/osx/packages/contracts/src/plugins/governance/multisig/Multisig.sol";

contract MultisigDaoBuilder is Test {
    // Deploy a new DAO instance as the base
    address immutable DAO_BASE = address(new DAO());
    // Deploy plugin logic contracts as bases
    address immutable PAYMENTS_PLUGIN_BASE = address(new PaymentsPlugin());
    address immutable MULTISIG_PLUGIN_BASE = address(new Multisig());

    // DAO owner defaults to ALICE_ADDRESS
    address owner = ALICE_ADDRESS;
    // Multisig plugin configuration: members and settings
    address[] multisigMembers;
    // Default multisig settings: onlyListed set to false and minApprovals = 1.
    Multisig.MultisigSettings multisigSettings = Multisig.MultisigSettings({
        onlyListed: false,
        minApprovals: 1
    });

    /// @notice Sets the DAO owner.
    /// @param newOwner The address to become the DAO owner.
    function withDaoOwner(address newOwner) public returns (MultisigDaoBuilder) {
        owner = newOwner;
        return this;
    }

    /// @notice Adds a member to the multisig plugin.
    /// @param newMember The address of the new multisig member.
    function withMultisigMember(address newMember) public returns (MultisigDaoBuilder) {
        multisigMembers.push(newMember);
        return this;
    }

    /// @notice Configures multisig settings.
    /// @param onlyListed Whether only listed addresses can create proposals.
    /// @param minApprovals The minimal number of approvals required.
    function withMultisigSettings(bool onlyListed, uint16 minApprovals) public returns (MultisigDaoBuilder) {
        multisigSettings = Multisig.MultisigSettings({onlyListed: onlyListed, minApprovals: minApprovals});
        return this;
    }

    /// @notice Builds and deploys a DAO with a PaymentsPlugin and a Multisig plugin.
    /// @return dao The deployed DAO.
    /// @return paymentsPlugin The deployed PaymentsPlugin.
    /// @return multisigPlugin The deployed Multisig plugin.
    function build() public returns (DAO dao, PaymentsPlugin paymentsPlugin, Multisig multisigPlugin) {
        // Deploy the DAO using a proxy call.
        dao = DAO(
            payable(
                createProxyAndCall(
                    DAO_BASE,
                    abi.encodeCall(DAO.initialize, ("", address(this), address(0), ""))
                )
            )
        );

        // Deploy the PaymentsPlugin via proxy and initialize with the DAO.
        paymentsPlugin = PaymentsPlugin(
            createProxyAndCall(
                PAYMENTS_PLUGIN_BASE,
                abi.encodeCall(PaymentsPlugin.initialize, (IDAO(address(dao))))
            )
        );

        // Ensure there is at least one multisig member; if not, default to the owner.
        if (multisigMembers.length == 0) {
            multisigMembers.push(owner);
        }
        // Deploy the Multisig plugin via proxy and initialize with the DAO, multisig members, and settings.
        multisigPlugin = Multisig(
            createProxyAndCall(
                MULTISIG_PLUGIN_BASE,
                abi.encodeCall(Multisig.initialize, (IDAO(address(dao)), multisigMembers, multisigSettings))
            )
        );

        // Setup permissions for the PaymentsPlugin.
        dao.grant(address(dao), address(paymentsPlugin), dao.EXECUTE_PERMISSION_ID());
        dao.grant(address(paymentsPlugin), address(dao), paymentsPlugin.CREATE_PAYMENT_PERMISSION_ID());
        dao.grant(address(paymentsPlugin), owner, paymentsPlugin.CREATE_PAYMENT_PERMISSION_ID());
        dao.grant(address(paymentsPlugin), address(dao), paymentsPlugin.EDIT_PAYMENT_PERMISSION_ID());
        dao.grant(address(paymentsPlugin), owner, paymentsPlugin.EDIT_PAYMENT_PERMISSION_ID());

        // Setup permissions for the Multisig plugin.
        dao.grant(address(multisigPlugin), address(dao), multisigPlugin.UPDATE_MULTISIG_SETTINGS_PERMISSION_ID());
        dao.grant(address(multisigPlugin), address(dao), multisigPlugin.UPGRADE_PLUGIN_PERMISSION_ID());
        dao.grant(address(dao), address(multisigPlugin), dao.EXECUTE_PERMISSION_ID());

        // Transfer DAO root permission to the designated owner and revoke from this builder.
        dao.grant(address(dao), owner, dao.ROOT_PERMISSION_ID());
        dao.revoke(address(dao), address(this), dao.ROOT_PERMISSION_ID());

        // Label deployed contracts for clarity.
        vm.label(address(dao), "DAO");
        vm.label(address(paymentsPlugin), "PaymentsPlugin");
        vm.label(address(multisigPlugin), "MultisigPlugin");

        // Advance block number and timestamp to ensure consistency.
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        return (dao, paymentsPlugin, multisigPlugin);
    }
}