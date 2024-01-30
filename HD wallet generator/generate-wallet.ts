import { hdkey } from 'ethereumjs-wallet'
import * as bip39 from 'bip39';

function generateWallets(n: number): void {
    // Generate a mnemonic (seed phrase)
    const mnemonic: string = bip39.generateMnemonic();
    console.log('Mnemonic:', mnemonic);

    // Convert the mnemonic into a seed buffer
    const seed: Buffer = bip39.mnemonicToSeedSync(mnemonic);

    // Create an HD wallet from the seed
    const hdWallet: hdkey = hdkey.fromMasterSeed(seed);

    // Ethereum's BIP-44 path
    const pathBase: string = "m/44'/60'/0'/0/";

    for (let i = 0; i < n; i++) {
        const path: string = pathBase + i;
        const wallet = hdWallet.derivePath(path).getWallet();
        const address: string = wallet.getAddressString();
        const privateKey: string = wallet.getPrivateKeyString();
        const timestamp: string = new Date().toISOString();

        console.log(`Wallet ${i + 1}:`);
        console.log('Timestamp:', timestamp);
        console.log('Address:', address);
        console.log('Private Key:', privateKey);
        console.log('--------------------------');
    }
}

generateWallets(10);