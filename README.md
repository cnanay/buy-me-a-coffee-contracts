# ☕ Buy Me A Coffee — smart contract

A simple on-chain tip jar written in Solidity and built with
[Foundry](https://book.getfoundry.sh/). Anyone can send a tip along with a name
and a message (stored permanently on-chain); only the owner can withdraw the
collected funds.

⛓️ **Network:** Ethereum **Sepolia** testnet
📄 **Deployed at:** [`0xf17bf8F6E1Eec4Fdd7EfB9406eA8d7B1Fa8959D4`](https://sepolia.etherscan.io/address/0xf17bf8F6E1Eec4Fdd7EfB9406eA8d7B1Fa8959D4)
🖥️ **Frontend:** [live app](https://buy-me-a-coffee.networktoday.xyz) · [frontend repo](https://github.com/cnanay/buy-me-a-coffee-frontend)

---

## Contracts

This repo contains three contracts:

| Contract | Purpose |
| -------- | ------- |
| [`BuyMeACoffee.sol`](src/BuyMeACoffee.sol) | **V1** — the simple single-owner tip jar. **This is the deployed/live one.** |
| [`BuyMeACoffeeV2.sol`](src/BuyMeACoffeeV2.sol) | Tip jar with an optional **platform fee** split between a platform and the jar owner. |
| [`CoffeeFactory.sol`](src/CoffeeFactory.sol) | A **factory** so anyone can deploy their own V2 jar; the platform earns a fee across all jars. |

> V2 and the Factory are **not deployed** — they're the building blocks for a
> multi-creator "tip platform" earning model.

### BuyMeACoffee (V1 — deployed)

Stores each tip as a `Memo` and emits an event the frontend listens to.

```solidity
struct Memo {
    address from;       // who sent the tip
    uint256 timestamp;  // block time
    string  name;       // their display name
    string  message;    // their message
}

event NewMemo(address indexed from, uint256 timestamp, string name, string message);
```

| Function                          | Access     | Description                                            |
| --------------------------------- | ---------- | ------------------------------------------------------ |
| `buyCoffee(string name, string message)` | `payable`  | Send a tip (must be > 0) with a name and message       |
| `withdrawTips()`                  | owner only | Withdraw the full contract balance to the owner        |
| `getMemos()`                      | `view`     | Return every memo, for the frontend to display         |
| `owner()`                         | `view`     | The deployer / only address allowed to withdraw        |

> **Note:** the `Memo` struct intentionally does **not** store the tip amount —
> it's recoverable from each transaction's value (the frontend reads it via the
> Etherscan API). Withdrawals use the low-level `call` pattern (current best
> practice for sending ETH).

### BuyMeACoffeeV2 — optional platform fee

Same tip jar as V1, but each tip is split: a configurable fee (in basis points,
**capped at 10%**) goes to the `platformOwner`, the rest accrues to the jar
`owner`. Fees are tracked separately so the owner can never withdraw them — the
platform claims them with `withdrawPlatformFees()`. Stays **backwards-compatible
with the frontend** (`owner`, `buyCoffee`, `withdrawTips`, `getMemos`, `NewMemo`
are unchanged, so the fee is invisible to tippers). Set the fee to `0` and it
behaves exactly like V1.

### CoffeeFactory — multi-creator platform

Anyone calls `createJar()` to deploy their own V2 jar (they own and withdraw its
tips); every jar is wired so the **platform** (the factory's deployer) earns the
fee on all tips across all jars. Fees never pass through the factory — each jar
pays the platform directly, which is simpler and safer.

## Tests

**35 tests, all passing**, across the three contracts:

- [`BuyMeACoffee.t.sol`](test/BuyMeACoffee.t.sol) (10) — owner/deployment, tip
  storage & balance, `NewMemo`, zero-tip revert, owner-only withdrawals.
- [`BuyMeACoffeeV2.t.sol`](test/BuyMeACoffeeV2.t.sol) (15) — fee split math, both
  withdrawal paths, access control, fee cap, and zero-fee = V1 behavior.
- [`CoffeeFactory.t.sol`](test/CoffeeFactory.t.sol) (10) — jar creation &
  indexing, multi-creator support, fee cap, and an end-to-end check that fees
  actually reach the platform.

```bash
forge test -vv
```

## Usage

### Build & test

```bash
forge build
forge test
forge fmt          # format
forge snapshot     # gas snapshots
```

### Local node

```bash
anvil
```

### Deploy

Create a `.env` from the example and fill in your values:

```bash
cp .env.example .env
# then edit .env
```

```bash
# .env
SEPOLIA_RPC_URL=https://...      # an RPC endpoint (Alchemy/Infura/etc.)
PRIVATE_KEY=0x...                # deployer key — KEEP SECRET, never commit
ETHERSCAN_API_KEY=...            # for source verification
```

Deploy to Sepolia and verify on Etherscan:

```bash
source .env

forge script script/DeployBuyMeACoffee.s.sol:DeployBuyMeACoffee \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  --verify \
  --etherscan-api-key "$ETHERSCAN_API_KEY"
```

> ⚠️ `.env` is gitignored — never commit your private key or API keys.

To deploy the **factory** instead (deployer becomes the fee-earning platform;
set the default fee via `FACTORY_FEE_BPS`, default 250 = 2.5%):

```bash
source .env

forge script script/DeployCoffeeFactory.s.sol:DeployCoffeeFactory \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  --verify \
  --etherscan-api-key "$ETHERSCAN_API_KEY"
```

## Project layout

```
src/BuyMeACoffee.sol              # V1 — the deployed tip jar
src/BuyMeACoffeeV2.sol            # tip jar with an optional platform fee
src/CoffeeFactory.sol             # factory: one-click jars, one platform fee
test/                             # forge tests (35 total, one file per contract)
script/DeployBuyMeACoffee.s.sol   # deploy V1
script/DeployCoffeeFactory.s.sol  # deploy the factory
```

## Built with

[Foundry](https://book.getfoundry.sh/) — Forge (testing), Cast (chain
interaction), Anvil (local node), Chisel (Solidity REPL).

## Author

Built by **Chamira Lakmal** ([@cnanay](https://github.com/cnanay)).
