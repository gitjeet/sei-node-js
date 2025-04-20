import express from 'express';
import Web3 from 'web3';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const MPContractAddress = process.env.CONTRACT_ADDRESS || "0xeb6De02783be7c72d8c01a29e9e9E49B1326281F";
const app = express();
const PORT = process.env.PORT || 3000;

// Load ABI from environment or config file
const contractABI = JSON.parse(process.env.CONTRACT_ABI || '[]');

async function getKit(addrssofmint, nft) {
    try {
        console.log("Initializing Web3...");
        const web3 = new Web3(process.env.RPC_URL || "https://evm-rpc-testnet.sei-apis.com");
        
        // Initialize account from environment variable
        if (!process.env.PRIVATE_KEY) {
            throw new Error("Private key not configured");
        }
        const account = web3.eth.accounts.privateKeyToAccount(process.env.PRIVATE_KEY);
        web3.eth.accounts.wallet.add(account);
        console.log("Using account:", `${account.address.substring(0, 6)}...${account.address.substring(38)}`);
        
        // Initialize contract
        const contract = new web3.eth.Contract(contractABI, MPContractAddress);
        
        const ipfsMap = {
            'art': process.env.ART_IPFS_URL,
            'cityilluminati': process.env.CITY_IPFS_URL,
            // Add other mappings as environment variables
            // Default fallbacks
            ...(!process.env.ART_IPFS_URL && { 
                'art': 'https://ipfs.io/ipfs/QmQ6pkp4xcdbdabp5XCeJYuQBV5cnQnTf7CVpf34rpHUDN'
            })
        };
        
        const urlofimage = ipfsMap[nft];
        if (!urlofimage) {
            throw new Error(`NFT type ${nft} not found`);
        }
        
        console.log(`Minting to ${addrssofmint.substring(0, 6)}...${addrssofmint.substring(38)}`);
        
        const txObject = contract.methods.safeMint(addrssofmint, urlofimage);
        const gas = await txObject.estimateGas({ from: account.address });
        
        const receipt = await txObject.send({
            from: account.address,
            gas: gas + 10000,
        });
        
        return {
            ...receipt,
            // Hide sensitive details in logs
            from: `${receipt.from.substring(0, 6)}...${receipt.from.substring(38)}`,
            to: `${receipt.to.substring(0, 6)}...${receipt.to.substring(38)}`
        };
        
    } catch (error) {
        console.error("Error in getKit:", error.message);
        throw error;
    }
}

app.get('/mintnft/:address/:nft', async (req, res) => {
    try {
        const detailofnft = await getKit(req.params.address, req.params.nft);
        
        res.send({
            status: "success",
            transactionHash: detailofnft.transactionHash,
            blockNumber: detailofnft.blockNumber,
            nftType: req.params.nft,
            // Don't expose full addresses in response
            recipient: `${req.params.address.substring(0, 6)}...${req.params.address.substring(38)}`
        });
        
    } catch (error) {
        console.error("API Error:", error.message);
        res.status(500).send({
            status: "error",
            message: "Minting failed",
            // Don't expose detailed error to client
            details: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

app.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
    console.log(`Mint endpoint: GET /mintnft/:address/:nft`);
});