// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts@4.9.3/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.9.3/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GeoLockedNFT is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    
    Counters.Counter private _tokenIdCounter;
    
    // Geospatial data structures
    struct GeoCoordinate {
        int32 latitude;  // Scaled by 1e6 (e.g., 40.7128° = 40712800)
        int32 longitude; // Scaled by 1e6
        uint16 radius;   // In meters
    }
    
    struct LocationProof {
        bytes32 witnessHash;
        uint256 timestamp;
    }
    
    // Token geospatial data
    mapping(uint256 => GeoCoordinate) private _tokenGeoData;
    mapping(uint256 => LocationProof) private _locationProofs;
    
    // Geofencing parameters
    uint256 public constant MAX_GEO_RADIUS = 10000; // 10km maximum radius
    uint256 public constant MIN_GEO_RADIUS = 10;    // 10 meters minimum radius
    
    // Oracle management
    address private _geoOracle;
    bool private _oracleEnabled;
    
    // Cryptographic parameters
    bytes32 private _domainSeparator;
    bytes32 private constant GEO_PERMIT_TYPEHASH = 
        keccak256("GeoPermit(address minter,uint256 tokenId,int32 latitude,int32 longitude,uint16 radius,uint256 nonce,uint256 deadline)");
    mapping(address => uint256) public nonces;
    
    event GeoNFTMinted(uint256 indexed tokenId, address indexed minter, int32 latitude, int32 longitude, uint16 radius);
    event GeoOracleUpdated(address indexed newOracle);
    event LocationVerified(uint256 indexed tokenId, bytes32 witnessHash);
    
    constructor() ERC721("GeoLockedNFT", "GLNFT") {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        _domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("GeoLockedNFT")),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }
    
    // Modified safeMint with geolock
    function safeMint(
        address to,
        string memory uri,
        int32 latitude,
        int32 longitude,
        uint16 radius,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 deadline
    ) public {
        require(radius >= MIN_GEO_RADIUS && radius <= MAX_GEO_RADIUS, "Invalid radius");
        require(block.timestamp <= deadline, "GeoPermit expired");
        
        // Verify geolocation signature
        bytes32 structHash = keccak256(
            abi.encode(
                GEO_PERMIT_TYPEHASH,
                msg.sender,
                _tokenIdCounter.current(),
                latitude,
                longitude,
                radius,
                nonces[msg.sender]++,
                deadline
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _domainSeparator,
                structHash
            )
        );
        
        address signer = ecrecover(digest, v, r, s);
        require(signer == _geoOracle || !_oracleEnabled, "Invalid geo signature");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
        _tokenGeoData[tokenId] = GeoCoordinate(latitude, longitude, radius);
        
        emit GeoNFTMinted(tokenId, to, latitude, longitude, radius);
    }
    
    // Verify location proof for a token
    function verifyLocation(
        uint256 tokenId,
        int32 userLatitude,
        int32 userLongitude,
        bytes32 witnessHash
    ) public {
        require(_exists(tokenId), "Token does not exist");
        
        GeoCoordinate memory geo = _tokenGeoData[tokenId];
        bool isWithinRadius = _checkGeoProximity(
            geo.latitude,
            geo.longitude,
            userLatitude,
            userLongitude,
            geo.radius
        );
        
        require(isWithinRadius, "Location verification failed");
        
        _locationProofs[tokenId] = LocationProof(witnessHash, block.timestamp);
        emit LocationVerified(tokenId, witnessHash);
    }
    
    // Set the geo oracle address
    function setGeoOracle(address newOracle) public onlyOwner {
        _geoOracle = newOracle;
        _oracleEnabled = true;
        emit GeoOracleUpdated(newOracle);
    }
    
    // Toggle oracle requirement
    function toggleOracleRequirement(bool enabled) public onlyOwner {
        _oracleEnabled = enabled;
    }
    
    // Get token geodata
    function getTokenGeoData(uint256 tokenId) public view returns (GeoCoordinate memory) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenGeoData[tokenId];
    }
    
    // Get location proof
    function getLocationProof(uint256 tokenId) public view returns (LocationProof memory) {
        require(_exists(tokenId), "Token does not exist");
        return _locationProofs[tokenId];
    }
    
    // Internal function to check geo proximity using Haversine formula
    function _checkGeoProximity(
        int32 lat1,
        int32 long1,
        int32 lat2,
        int32 long2,
        uint16 radius
    ) private pure returns (bool) {
        // Convert to radians (scaled by 1e6)
        int32 lat1Rad = lat1 * 314159265 / 1800000000;
        int32 lat2Rad = lat2 * 314159265 / 1800000000;
        int32 deltaLat = (lat2 - lat1) * 314159265 / 1800000000;
        int32 deltaLong = (long2 - long1) * 314159265 / 1800000000;
        
        // Haversine formula
        int32 a = (deltaLat/2).sin() ** 2 + 
                 lat1Rad.cos() * lat2Rad.cos() * 
                 (deltaLong/2).sin() ** 2;
        int32 c = 2 * a.sqrt().asin();
        
        // Earth radius in meters (6371000) scaled by 1e6
        int32 distance = (6371000 * 1e6) * c / 1e6;
        
        return uint32(distance) <= radius;
    }
    
    // The following functions are overrides required by Solidity
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
        delete _tokenGeoData[tokenId];
        delete _locationProofs[tokenId];
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}