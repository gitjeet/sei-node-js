# GeoLockedNFT - Location-Based ERC721 Smart Contract



 ERC721 contract that binds NFTs to specific geographic locations with cryptographic proof verification.

## Features

-  Geospatial NFT minting with latitude/longitude coordinates
-  Cryptographic location verification using EIP-712 signatures
-  Configurable geofencing parameters (10m-10km radius)
-  Oracle-based location proof system
-  On-chain location history tracking


# README for Express Minting Server


# NFT Minting API Server



Express.js server for minting location-based NFTs on the SEI network.

## Features

-  Simple REST API for NFT minting
-  SEI Testnet integration
-  Pre-configured IPFS metadata
-  Secure private key handling
-  Quick transaction processing

## Environment Setup

1. Rename `.env.example` to `.env`
2. Configure your environment variables:

```ini
SEI_RPC_URL="https://evm-rpc-testnet.sei-apis.com"
CONTRACT_ADDRESS="SEI_ContractAddress"
PRIVATE_KEY="SEI_PrivatedKEY with prefix 0x"
PUBLIC_ADDRESS="SEI_Public Account"
PORT=8080
