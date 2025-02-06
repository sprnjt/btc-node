#!/bin/bash

# Download and verify Bitcoin Core binaries
echo "Downloading the latest Bitcoin Core binaries..."
BITCOIN_VERSION="28.0"
wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz
wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS
wget https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS.asc

echo "Importing Bitcoin Core release signing keys..."
gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys $(curl -s https://raw.githubusercontent.com/bitcoin/bitcoin/master/contrib/builder-keys/keys.txt | awk '{print $1}')

echo "Verifying binary signatures..."
gpg --verify SHA256SUMS.asc SHA256SUMS
if [ $? -ne 0 ]; then
    echo "Error: Signature verification failed."
    exit 1
fi
echo "Binary signature verification successful."

# Extract and install binaries
echo "Extracting binaries..."
tar -xzf bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz
sudo cp bitcoin-${BITCOIN_VERSION}/bin/* /usr/local/bin/

# Start Bitcoin Node
mkdir -p ~/.bitcoin
echo -e "regtest=1\nfallbackfee=0.0001\nserver=1\nrest=1\ntxindex=1\nrpcauth=alice:88cae77e34048eff8b9f0be35527dd91\$d5c4e7ff4dfe771808e9c00a1393b90d498f54dcab0ee74a2d77bd01230cd4cc" > ~/.bitcoin/bitcoin.conf
echo "Starting Bitcoin Core daemon..."
bitcoind -daemon
sleep 5

# Create wallets and mine blocks
echo "Creating wallets..."
bitcoin-cli createwallet "Miner"
bitcoin-cli createwallet "Trader"

mining_address=$(bitcoin-cli -rpcwallet=Miner getnewaddress "Mining Reward")
balance=0
block_count=0
max_blocks=1000

while [ $block_count -lt $max_blocks ]; do
    result=$(bitcoin-cli -rpcwallet=Miner generatetoaddress 1 "$mining_address")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to mine block."
        exit 1
    fi
    balance=$(bitcoin-cli -rpcwallet=Miner getbalance)
    block_count=$((block_count + 1))
    echo "Block $block_count mined. Current balance: $balance BTC"
    balance_satoshis=$(echo "$balance * 100000000" | awk '{print int($1)}')
    if [ "$balance_satoshis" -gt 0 ]; then
        break
    fi
    sleep 1
done

if [ $block_count -eq $max_blocks ]; then
    echo "Warning: Mined $max_blocks blocks without a positive balance. Exiting."
    exit 1
fi

echo "Miner wallet balance: $balance BTC"
echo "It took $block_count blocks to get a positive balance."

# Perform transaction
miner_input=$(bitcoin-cli -rpcwallet=Miner listunspent | jq -r '.[0]')
miner_input_txid=$(echo "$miner_input" | jq -r '.txid')
miner_input_vout=$(echo "$miner_input" | jq -r '.vout')
miner_input_address=$(echo "$miner_input" | jq -r '.address')
miner_input_amount=$(echo "$miner_input" | jq -r '.amount')

trader_receive_address=$(bitcoin-cli -rpcwallet=Trader getnewaddress "Received")
miner_change_address=$(bitcoin-cli -rpcwallet=Miner getnewaddress "Miner Change")

trader_output_amount=20
estimated_fee=0.0001
miner_change_amount=$(echo "$miner_input_amount - $trader_output_amount - $estimated_fee" | bc)

raw_tx=$(bitcoin-cli -rpcwallet=Miner createrawtransaction \
  "[{\"txid\":\"$miner_input_txid\",\"vout\":$miner_input_vout}]" \
  "{\"$trader_receive_address\":$trader_output_amount, \"$miner_change_address\":$miner_change_amount}")

signed_tx=$(bitcoin-cli -rpcwallet=Miner signrawtransactionwithwallet "$raw_tx" | jq -r '.hex')
txid=$(bitcoin-cli -rpcwallet=Miner sendrawtransaction "$signed_tx")

block_hash=$(bitcoin-cli -rpcwallet=Miner generatetoaddress 1 "$mining_address" | jq -r '.[0]')
block_height=$(bitcoin-cli getblock "$block_hash" | jq -r '.height')
tx_details=$(bitcoin-cli -rpcwallet=Trader gettransaction "$txid" true)
transaction_fee=$(echo "$tx_details" | jq -r '.fee')

decoded_tx=$(bitcoin-cli decoderawtransaction $(bitcoin-cli getrawtransaction "$txid"))
trader_output_amount=$(echo "$decoded_tx" | jq --arg addr "$trader_receive_address" '.vout[] | select(.scriptPubKey.address == $addr) | .value')
miner_change_amount=$(echo "$decoded_tx" | jq --arg addr "$miner_change_address" '.vout[] | select(.scriptPubKey.address == $addr) | .value')

{
  echo "$txid"
  echo "$miner_input_address"
  echo "$miner_input_amount"
  echo "$trader_receive_address"
  echo "$trader_output_amount"
  echo "$miner_change_address"
  echo "$miner_change_amount"
  echo "$transaction_fee"
  echo "$block_height"
  echo "$block_hash"
} > out.txt

echo "Transaction details written to out.txt"