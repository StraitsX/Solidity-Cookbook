package main

import (
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"flag"
	"fmt"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/joho/godotenv"
	"math/big"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

const (
	walletsFilePath = "./wallets.json"
	receiver        = "0x3aa7E64b811857d942e6Cc39cFBBad2664b14CdF"
)

type Wallet struct {
	PrivateKey string `json:"privateKey"`
}

// Define the maxWallets flag
var maxWallets = flag.Int("maxWallets", 10, "maximum number of wallets to use for sending transactions. Default to 10.")

func main() {
	flag.Parse()
	err := godotenv.Load()
	if err != nil {
		fmt.Printf("Failed to load environment variables: %v\n", err)
		os.Exit(1)

	}
	rpcURL := os.Getenv("RPC_URL")
	client, err := ethclient.Dial(rpcURL)
	defer client.Close()
	if err != nil {
		fmt.Printf("Failed to connect to the Ethereum client: %v\n", err)
		os.Exit(1)
	}

	var wallets []Wallet
	if _, err := os.Stat(walletsFilePath); err == nil {
		// Load wallets from the file
		fileContent, err := os.ReadFile(walletsFilePath)
		if err != nil {
			fmt.Printf("Failed to read wallets file: %v\n", err)
			os.Exit(1)
		}

		if err := json.Unmarshal(fileContent, &wallets); err != nil {
			fmt.Printf("Failed to unmarshal wallets: %v\n", err)
			os.Exit(1)
		}
	} else {
		fmt.Printf("No wallets file found, aborting...\n")
		os.Exit(1)
	}

	// Setup cancellation context with signal handling
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	// Main loop
	for {
		select {
		case <-ctx.Done():
			fmt.Printf("Shutdown signal received\n")
			return
		default:
			sendEther(ctx, client, wallets, *maxWallets)
		}
	}
}

func sendEther(ctx context.Context, client *ethclient.Client, wallets []Wallet, maxWallets int) {
	var wg sync.WaitGroup

	for _, w := range wallets[:maxWallets] {
		wg.Add(1)
		go func(wallet Wallet) {
			defer wg.Done()
			privateKeyHex := wallet.PrivateKey

			if privateKeyHex[:2] == "0x" {
				privateKeyHex = privateKeyHex[2:]
			}

			privateKey, err := crypto.HexToECDSA(privateKeyHex)
			if err != nil {
				fmt.Printf("Failed to decode private key: %v\n", err)
				return
			}
			publicKey := privateKey.Public()
			publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
			if !ok {
				fmt.Printf("Failed to cast public key to ECDSA: %v\n", err)
				return
			}
			publicAddr := crypto.PubkeyToAddress(*publicKeyECDSA)
			toAddress := common.HexToAddress(receiver)
			value := big.NewInt(10000000000000) // 0.00001 STX/ETH in Wei
			tip := big.NewInt(2000000000)       // maxPriorityFeePerGas = 2 Gwei
			feeCap := big.NewInt(200000000000)  // maxFeePerGas = 200 Gwei
			gasLimit := uint64(21000)           // Gas limit for standard ETH transfer

			nonce, err := client.PendingNonceAt(ctx, publicAddr)
			if err != nil {
				fmt.Printf("Failed to get nonce: %v\n", err)
				return
			}
			chainID, err := client.ChainID(ctx)
			if err != nil {
				fmt.Printf("Failed to get chain ID: %v\n", err)
				return
			}

			var data []byte

			tx := types.NewTx(&types.DynamicFeeTx{
				ChainID:   chainID,
				Nonce:     nonce,
				GasFeeCap: feeCap,
				GasTipCap: tip,
				Gas:       gasLimit,
				To:        &toAddress,
				Value:     value,
				Data:      data})

			signerTX := types.LatestSignerForChainID(chainID)
			signedTx, err := types.SignTx(tx, signerTX, privateKey)

			err = client.SendTransaction(ctx, signedTx)
			if err != nil {
				fmt.Printf("Failed to send transaction: %v\n", err)
				return
			}
			fmt.Printf("Transaction sent, tx hash: %s\n", signedTx.Hash().Hex())

			// wait for the transaction to be confirmed
			queryTicker := time.NewTicker(150 * time.Millisecond)
			defer queryTicker.Stop()

		ConfirmationLoop:
			for {
				select {
				case <-ctx.Done():
					fmt.Printf("Context cancelled\n")
					break ConfirmationLoop
				case <-queryTicker.C:
					receipt, err := client.TransactionReceipt(ctx, signedTx.Hash())
					if err != nil {
						fmt.Printf("Failed to get transaction receipt: %v\n", err)
						continue
					}
					if receipt != nil {
						fmt.Printf("Transaction confirmed in block %s\n", receipt.BlockNumber)
						break ConfirmationLoop
					}
				}
			}
		}(w)
	}

	wg.Wait()
}
