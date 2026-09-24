// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "../src/ERC20.sol";
import {ERC4626Vault} from "../src/ERC4626Vault.sol";

contract ERC4626VaultTest is Test {
    ERC20 internal asset;
    ERC4626Vault internal vault;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        asset = new ERC20("Mock USD", "mUSD", 18);
        vault = new ERC4626Vault(asset, "Vault mUSD", "vmUSD");
        asset.mint(alice, 1_000e18);
        asset.mint(bob, 1_000e18);
        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        asset.approve(address(vault), type(uint256).max);
    }

    function test_EmptyVaultIsOneToOne() public {
        assertEq(vault.exchangeRate(), 1e18);
        assertEq(vault.previewDeposit(100e18), 100e18);
    }

    function test_DepositMintsShares() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(100e18, alice);
        assertEq(shares, 100e18);
        assertEq(vault.balanceOf(alice), 100e18);
        assertEq(vault.totalAssets(), 100e18);
    }

    function test_SecondDepositorGetsSameRateWhenNoYield() public {
        vm.prank(alice);
        vault.deposit(100e18, alice);
        vm.prank(bob);
        uint256 shares = vault.deposit(50e18, bob);
        assertEq(shares, 50e18);
    }

    function test_YieldRaisesTheExchangeRate() public {
        vm.prank(alice);
        vault.deposit(100e18, alice);
        // simulate yield: assets grow, share supply does not
        asset.mint(address(vault), 100e18);
        assertEq(vault.exchangeRate(), 2e18);
        assertEq(vault.previewWithdraw(100e18), 200e18);
    }

    function test_WithdrawBurnsSharesAndPaysAssets() public {
        vm.prank(alice);
        vault.deposit(100e18, alice);
        uint256 before = asset.balanceOf(alice);
        vm.prank(alice);
        uint256 assets = vault.withdraw(40e18, alice, alice);
        assertEq(assets, 40e18);
        assertEq(asset.balanceOf(alice) - before, 40e18);
        assertEq(vault.balanceOf(alice), 60e18);
    }

    function test_ThirdPartyNeedsAllowance() public {
        vm.prank(alice);
        vault.deposit(100e18, alice);
        vm.prank(bob);
        vm.expectRevert();
        vault.withdraw(10e18, bob, alice);
    }

    function test_RevertOnZeroDeposit() public {
        vm.prank(alice);
        vm.expectRevert(ERC4626Vault.ZeroAssets.selector);
        vault.deposit(0, alice);
    }

    function test_RevertWhenWithdrawingMoreThanOwned() public {
        vm.prank(alice);
        vault.deposit(10e18, alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC4626Vault.InsufficientShares.selector, 10e18, 11e18));
        vault.withdraw(11e18, alice, alice);
    }

    function testFuzz_DepositWithdrawRoundTrip(uint96 amount) public {
        amount = uint96(bound(amount, 1e6, 1_000e18));
        vm.prank(alice);
        uint256 shares = vault.deposit(amount, alice);
        vm.prank(alice);
        uint256 back = vault.withdraw(shares, alice, alice);
        assertEq(back, amount);
    }
}
