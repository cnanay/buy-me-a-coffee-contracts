# ☕ Buy Me A Coffee — smart contract

A simple on-chain tip jar written in Solidity and built with
[Foundry](https://book.getfoundry.sh/). Anyone can send a tip along with a name
and a message (stored permanently on-chain); only the owner can withdraw the
collected funds.

⛓️ **Network:** Ethereum **Sepolia** testnet
📄 **Deployed at:** [`0xf17bf8F6E1Eec4Fdd7EfB9406eA8d7B1Fa8959D4`](https://sepolia.etherscan.io/address/0xf17bf8F6E1Eec4Fdd7EfB9406eA8d7B1Fa8959D4)
🖥️ **Frontend:** [live app](https://buy-me-a-coffee.networktoday.xyz) · [frontend repo](https://github.com/cnanay/buy-me-a-coffee-frontend)

---

## The contract

[`src/BuyMeACoffee.sol`](src/BuyMeACoffee.sol) stores each tip as a `Memo` and
emits an event the frontend listens to.

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

## Tests

A full test suite lives in [`test/BuyMeACoffee.t.sol`](test/BuyMeACoffee.t.sol)
— **10 tests, all passing**, covering:

- Owner is set on deployment; starts with no memos
- `buyCoffee` stores the memo, increases the balance, supports multiple memos,
  emits `NewMemo`, and reverts on a zero-value tip
- `withdrawTips` transfers the balance to the owner, and reverts for non-owners
  and when the balance is empty

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

## Project layout

```
src/BuyMeACoffee.sol              # the contract
test/BuyMeACoffee.t.sol           # forge tests
script/DeployBuyMeACoffee.s.sol   # deploy script
```

## Built with

[Foundry](https://book.getfoundry.sh/) — Forge (testing), Cast (chain
interaction), Anvil (local node), Chisel (Solidity REPL).

## Author

Built by **Chamira Lakmal** ([@cnanay](https://github.com/cnanay)).
