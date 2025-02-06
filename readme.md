# Bitcoin Core Automation Script

## Overview
This script automates the process of downloading, verifying, installing, and running a Bitcoin Core node in regtest mode. It also creates wallets, mines blocks, and performs a transaction between two wallets.

## Features
- Downloads and verifies Bitcoin Core binaries (version 28.0).
- Installs and runs Bitcoin Core in regtest mode.
- Creates two wallets: `Miner` and `Trader`.
- Mines up to 1000 blocks to generate an initial balance.
- Sends a transaction from `Miner` to `Trader`, including fee calculation and change handling.
- Logs transaction details to `out.txt`.

## Prerequisites
Ensure you have the following installed on your system:
- `wget`
- `gpg`
- `jq`
- `bc`

## Installation and Usage

1. Clone this repository or download the script.
2. Make the script executable:
   ```bash
   chmod +x script.sh
   ```
3. Run the script:
   ```bash
   ./script.sh
   ```

## Script Breakdown

1. **Downloading and Verifying Bitcoin Core**
   - Downloads Bitcoin Core binaries, SHA256SUMS, and signature files.
   - Imports Bitcoin Core signing keys and verifies signatures.

2. **Installing Bitcoin Core**
   - Extracts and installs Bitcoin Core binaries to `/usr/local/bin/`.

3. **Starting Bitcoin Core in Regtest Mode**
   - Creates a `bitcoin.conf` file with necessary configurations.
   - Runs `bitcoind` in daemon mode.

4. **Wallet Creation & Mining**
   - Creates `Miner` and `Trader` wallets.
   - Mines blocks to earn BTC until a balance is obtained.

5. **Transaction Execution**
   - Constructs a raw transaction sending BTC from `Miner` to `Trader`.
   - Signs and broadcasts the transaction.
   - Mines another block to confirm the transaction.

6. **Logging Transaction Details**
   - Stores transaction details such as TXID, input/output addresses, amounts, fees, and block height in `out.txt`.

## Expected Output
After successful execution, the `out.txt` file will contain:
- Transaction ID (TXID)
- Miner input address and amount
- Trader receiving address and amount
- Miner change address and amount
- Transaction fee
- Block height and block hash of the mined block

## Troubleshooting
- If the script fails at signature verification, check your internet connection and keyserver availability.
- If `bitcoind` does not start, ensure there are no existing Bitcoin processes running.
- If the transaction fails, verify wallet balances and mining progress using:
  ```bash
  bitcoin-cli -rpcwallet=Miner getbalance
  ```

## License
This script is released under the MIT License.

