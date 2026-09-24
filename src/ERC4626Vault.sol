// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "./ERC20.sol";

/// @title Minimal ERC-4626 tokenised vault.
/// @notice Shares are ERC-20 tokens redeemable for the underlying asset at the
///         current exchange rate. The vault is deliberately dumb: it holds
///         assets and mints or burns shares, nothing else.
contract ERC4626Vault is ERC20 {
    error ZeroAssets();
    error ZeroShares();
    error InsufficientShares(uint256 available, uint256 needed);
    error AssetTransferFailed();

    ERC20 public immutable asset;

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    constructor(ERC20 asset_, string memory name_, string memory symbol_) ERC20(name_, symbol_, 18) {
        asset = asset_;
    }

    /// @notice Assets per share, scaled by 1e18. Returns 1e18 for an empty vault.
    function exchangeRate() public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0) return 1e18;
        return (totalAssets() * 1e18) / supply;
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return (assets * 1e18) / exchangeRate();
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return (shares * exchangeRate()) / 1e18;
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    function previewWithdraw(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        if (assets == 0) revert ZeroAssets();
        shares = convertToShares(assets);
        if (shares == 0) revert ZeroShares();
        _mint(receiver, shares);
        _pullAssets(msg.sender, assets);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 shares, address receiver, address owner_) external returns (uint256 assets) {
        if (shares == 0) revert ZeroShares();
        if (balanceOf[owner_] < shares) {
            revert InsufficientShares(balanceOf[owner_], shares);
        }
        assets = convertToAssets(shares);
        // spend the allowance before the external transfers
        if (msg.sender != owner_) _spendAllowance(owner_, msg.sender, shares);
        _burn(owner_, shares);
        if (!asset.transfer(receiver, assets)) revert AssetTransferFailed();
        emit Withdraw(msg.sender, receiver, owner_, assets, shares);
    }

    function _pullAssets(address from, uint256 amount) internal {
        if (!asset.transferFrom(from, address(this), amount)) revert AssetTransferFailed();
    }
}
