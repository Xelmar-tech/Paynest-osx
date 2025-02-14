// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {createProxyAndCall} from "../../src/util/proxy.sol";
import {ALICE_ADDRESS} from "../constants.sol";
import {PaymentsPlugin} from "../../src/PaymentsPlugin.sol";
import {Admin} from "../../lib/osx/packages/contracts/src/plugins/governance/admin/Admin.sol";

contract AdminDaoBuilder is Test {
    // Deploy a new DAO instance as the base
    address immutable DAO_BASE = address(new DAO());
    // Deploy plugin logic contracts as bases
    address immutable PAYMENTS_PLUGIN_BASE = address(new PaymentsPlugin());
    address immutable ADMIN_PLUGIN_BASE = address(new Admin());

    // DAO admin defaults to ALICE_ADDRESS
    address admin = ALICE_ADDRESS;

    /// @notice Sets the DAO admin.
    /// @param newAdmin The address to become the DAO admin.
    function withAdmin(address newAdmin) public returns (AdminDaoBuilder) {
        admin = newAdmin;
        return this;
    }

    /// @notice Builds and deploys a DAO with a PaymentsPlugin and an Admin plugin.
    /// @return dao The deployed DAO.
    /// @return paymentsPlugin The deployed PaymentsPlugin.
    /// @return adminPlugin The deployed Admin plugin.
    function build()
        public
        returns (DAO dao, PaymentsPlugin paymentsPlugin, Admin adminPlugin)
    {
        // Deploy the DAO using a proxy call.
        dao = DAO(
            payable(
                createProxyAndCall(
                    DAO_BASE,
                    abi.encodeCall(
                        DAO.initialize,
                        ("", address(this), address(0), "")
                    )
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

        // Deploy the Admin plugin via proxy and initialize with the DAO.
        adminPlugin = Admin(
            createProxyAndCall(
                ADMIN_PLUGIN_BASE,
                abi.encodeCall(Admin.initialize, (IDAO(address(dao))))
            )
        );

        // Setup permissions for the PaymentsPlugin.
        dao.grant(
            address(dao),
            address(paymentsPlugin),
            dao.EXECUTE_PERMISSION_ID()
        );
        dao.grant(
            address(paymentsPlugin),
            address(dao),
            paymentsPlugin.CREATE_PAYMENT_PERMISSION_ID()
        );
        dao.grant(
            address(paymentsPlugin),
            admin,
            paymentsPlugin.CREATE_PAYMENT_PERMISSION_ID()
        );
        dao.grant(
            address(paymentsPlugin),
            address(dao),
            paymentsPlugin.EDIT_PAYMENT_PERMISSION_ID()
        );
        dao.grant(
            address(paymentsPlugin),
            admin,
            paymentsPlugin.EDIT_PAYMENT_PERMISSION_ID()
        );
        dao.grant(
            address(paymentsPlugin),
            admin,
            paymentsPlugin.EXECUTE_PAYMENT_PERMISSION_ID()
        );

        // Setup permissions for the Admin plugin.
        dao.grant(
            address(adminPlugin),
            address(dao),
            adminPlugin.EXECUTE_PROPOSAL_PERMISSION_ID()
        );
        dao.grant(
            address(dao),
            address(adminPlugin),
            dao.EXECUTE_PERMISSION_ID()
        );
        dao.grant(
            address(adminPlugin),
            admin,
            adminPlugin.EXECUTE_PROPOSAL_PERMISSION_ID()
        );

        // Transfer DAO root permission to the admin and revoke from this builder.
        dao.grant(address(dao), admin, dao.ROOT_PERMISSION_ID());
        dao.revoke(address(dao), address(this), dao.ROOT_PERMISSION_ID());

        // Label deployed contracts for clarity.
        vm.label(address(dao), "DAO");
        vm.label(address(paymentsPlugin), "PaymentsPlugin");
        vm.label(address(adminPlugin), "AdminPlugin");

        // Advance block number and timestamp to ensure consistency.
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        return (dao, paymentsPlugin, adminPlugin);
    }
}
