# erc4626-vault

A minimal ERC-4626 tokenised vault: shares are ERC-20 tokens redeemable for the
underlying asset at the current exchange rate.

ERC-4626 exists so that "deposit into a yield strategy" has one interface instead
of one per protocol. Aggregators, routers and dashboards can then treat every
vault the same way.

## The model in one paragraph

The vault holds an asset and issues shares. The exchange rate is
`totalAssets / totalSupply`. Depositing more assets without minting shares (i.e.
yield arriving) raises the rate, so every existing share is worth more. That is
the whole mechanism; everything else is bookkeeping around it.

## Interface

- `deposit(assets, receiver)` mints `convertToShares(assets)` shares.
- `withdraw(shares, receiver, owner)` burns shares and pays `convertToAssets(shares)`.
- `previewDeposit` / `previewWithdraw` are the off-chain estimates and match the
  executed amounts exactly for this implementation.
- An empty vault reports a rate of `1e18`, the standard convention that avoids a
  division by zero and the classic first-depositor inflation attack setup.

## What it deliberately does not do

- **No yield strategy.** Assets sit idle. A real vault delegates to a strategy
  contract and the exchange rate becomes `totalAssets()` including strategy value.
- **No decimal handling.** Shares are 18 decimals and the asset should be too.
  Mixed decimals need a scaling factor.
- **No donation/inflation-attack mitigation.** Sending assets directly to the
  vault raises the rate; a production vault either mints a dead share amount on
  the first deposit or uses virtual shares.
- **`ERC20.sol` here is a local minimal implementation** so the vault is
  self-contained. Real deployments import a battle-tested token.

## Development

```bash
forge install foundry-rs/forge-std
forge test -vvv
```

## License

MIT
