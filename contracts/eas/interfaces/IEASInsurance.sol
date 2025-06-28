// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/ISchemaRegistry.sol";

/**
 * @title IEASInsurance
 * @dev Interface for EAS integration with crop insurance system
 */
interface IEASInsurance {
    
    // =========================================================================
    // Events
    // =========================================================================
    
    event PolicyAttestationCreated(
        bytes32 indexed uid,
        address indexed policyContract,
        address indexed client,
        bytes32 schemaUID
    );
    
    event WeatherAttestationCreated(
        bytes32 indexed uid,
        string location,
        uint256 rainfall,
        uint256 timestamp,
        bytes32 schemaUID
    );
    
    event ClaimAttestationCreated(
        bytes32 indexed uid,
        address indexed policyContract,
        uint256 claimAmount,
        uint8 claimStatus,
        bytes32 schemaUID
    );
    
    event ComplianceAttestationCreated(
        bytes32 indexed uid,
        address indexed entity,
        string regulationType,
        bool compliant,
        bytes32 schemaUID
    );
    
    event PremiumAttestationCreated(
        bytes32 indexed uid,
        address indexed policyContract,
        address indexed client,
        uint256 amount,
        bytes32 schemaUID
    );
    
    // =========================================================================
    // Schema Management
    // =========================================================================
    
    function getPolicySchemaUID() external view returns (bytes32);
    function getWeatherSchemaUID() external view returns (bytes32);
    function getClaimSchemaUID() external view returns (bytes32);
    function getComplianceSchemaUID() external view returns (bytes32);
    function getPremiumSchemaUID() external view returns (bytes32);
    
    // =========================================================================
    // Attestation Creation
    // =========================================================================
    
    function createPolicyAttestation(
        address policyContract,
        address client,
        uint256 premiumPaid,
        uint256 payoutValue,
        string calldata cropLocation,
        uint256 startDate,
        uint256 duration,
        bool isActive
    ) external returns (bytes32);
    
    function createWeatherAttestation(
        string calldata location,
        uint256 rainfall,
        string calldata dataSource,
        bytes32 oracleRequestId,
        bool verified
    ) external returns (bytes32);
    
    function createClaimAttestation(
        address policyContract,
        uint256 claimAmount,
        uint8 claimStatus,
        string calldata evidence,
        bool droughtConfirmed
    ) external returns (bytes32);
    
    function createComplianceAttestation(
        address entity,
        string calldata regulationType,
        bool compliant,
        string calldata certifyingAuthority
    ) external returns (bytes32);
    
    function createPremiumAttestation(
        address policyContract,
        address client,
        uint256 amount,
        address token,
        bool paid
    ) external returns (bytes32);
    
    // =========================================================================
    // Attestation Queries
    // =========================================================================
    
    function getPolicyAttestations(address policyContract) external view returns (bytes32[] memory);
    function getWeatherAttestations(string calldata location) external view returns (bytes32[] memory);
    function getClientAttestations(address client) external view returns (bytes32[] memory);
    function getComplianceAttestations(address entity) external view returns (bytes32[] memory);
    
    // =========================================================================
    // Verification
    // =========================================================================
    
    function verifyPolicyAttestation(bytes32 uid) external view returns (bool);
    function verifyWeatherAttestation(bytes32 uid) external view returns (bool);
    function verifyClaimAttestation(bytes32 uid) external view returns (bool);
    
    // =========================================================================
    // Revocation
    // =========================================================================
    
    function revokePolicyAttestation(bytes32 uid, string calldata reason) external;
    function revokeWeatherAttestation(bytes32 uid, string calldata reason) external;
    function revokeClaimAttestation(bytes32 uid, string calldata reason) external;
}

/**
 * @title AttestationStructs
 * @dev Gas-optimized structs for different types of attestations with packed storage
 */
library AttestationStructs {
    
    // Gas-optimized with packed layout
    struct PolicyAttestationData {
        // Slot 1: Fixed-size numeric data (32 bytes)
        uint128 premiumPaid;      // 16 bytes - sufficient for premium amounts
        uint128 payoutValue;      // 16 bytes - sufficient for payout amounts
        
        // Slot 2: Addresses and small values (32 bytes)
        address insuranceContract; // 20 bytes
        address client;           // 20 bytes - this will use part of next slot
        
        // Slot 3: Timestamps and flags (32 bytes)
        uint64 startDate;         // 8 bytes - sufficient for timestamps
        uint64 duration;          // 8 bytes - sufficient for durations
        bool isActive;            // 1 byte
        // 15 bytes remaining for future use
        
        // Dynamic data (separate storage slots)
        string policyId;
        string cropLocation;
    }
    
    // Gas-optimized weather data
    struct WeatherAttestationData {
        // Slot 1: Fixed data (32 bytes)
        uint64 timestamp;         // 8 bytes
        uint64 rainfall;          // 8 bytes - sufficient for rainfall measurements (in mm * 100)
        bytes32 oracleRequestId;  // Uses remaining 16 bytes of this slot + full next slot
        
        // Slot 2: Continued from above + flags
        bool verified;            // 1 byte
        // 23 bytes remaining
        
        // Dynamic data
        string location;
        string dataSource;
    }
    
    // Gas-optimized claim data
    struct ClaimAttestationData {
        // Slot 1: Amounts and timestamps (32 bytes)
        uint128 claimAmount;      // 16 bytes
        uint64 timestamp;         // 8 bytes
        uint8 claimStatus;        // 1 byte - 0: pending, 1: approved, 2: denied, 3: paid
        bool droughtConfirmed;    // 1 byte
        // 6 bytes remaining
        
        // Dynamic data
        string policyId;
        string evidence;
    }
    
    // Gas-optimized compliance data
    struct ComplianceAttestationData {
        // Slot 1: Address and timestamp (32 bytes)
        address entity;           // 20 bytes
        uint64 verificationDate;  // 8 bytes
        bool compliant;          // 1 byte
        // 3 bytes remaining
        
        // Dynamic data
        string regulationType;
        string certifyingAuthority;
    }
    
    // Gas-optimized premium data
    struct PremiumAttestationData {
        // Slot 1: Addresses (32 bytes)
        address client;           // 20 bytes
        address token;           // 20 bytes - this will use part of next slot
        
        // Slot 2: Amounts and timestamps (32 bytes)
        uint128 amount;          // 16 bytes
        uint64 paidAt;           // 8 bytes
        bool paid;               // 1 byte
        // 7 bytes remaining
        
        // Dynamic data
        string policyId;
    }
}

/**
 * @title EASConstants
 * @dev Constants for EAS integration
 */
library EASConstants {
    
    // Schema definitions following Solidity ABI encoding
    string constant POLICY_SCHEMA = "string policyId,address insuranceContract,address client,uint256 premiumPaid,uint256 payoutValue,string cropLocation,uint256 startDate,uint256 duration,bool isActive";
    
    string constant WEATHER_SCHEMA = "string location,uint256 timestamp,uint256 rainfall,string dataSource,bytes32 oracleRequestId,bool verified";
    
    string constant CLAIM_SCHEMA = "string policyId,uint256 claimAmount,uint256 timestamp,uint8 claimStatus,string evidence,bool droughtConfirmed";
    
    string constant COMPLIANCE_SCHEMA = "address entity,string regulationType,bool compliant,uint256 verificationDate,string certifyingAuthority";
    
    string constant PREMIUM_SCHEMA = "string policyId,address client,uint256 amount,address token,bool paid,uint256 paidAt";
    
    // Network-specific EAS contract addresses
    address constant EAS_SEPOLIA = 0xC2679fBD37d54388Ce493F1DB75320D236e1815e;
    address constant SCHEMA_REGISTRY_SEPOLIA = 0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0;
    
    address constant EAS_MAINNET = 0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587;
    address constant SCHEMA_REGISTRY_MAINNET = 0xA7b39296258348C78294F95B872b282326A97BDF;
    
    address constant EAS_OPTIMISM = 0x4200000000000000000000000000000000000021;
    address constant SCHEMA_REGISTRY_OPTIMISM = 0x4200000000000000000000000000000000000020;
    
    address constant EAS_BASE = 0x4200000000000000000000000000000000000021;
    address constant SCHEMA_REGISTRY_BASE = 0x4200000000000000000000000000000000000020;
    
    // Attestation status constants
    uint8 constant CLAIM_STATUS_PENDING = 0;
    uint8 constant CLAIM_STATUS_APPROVED = 1;
    uint8 constant CLAIM_STATUS_DENIED = 2;
    uint8 constant CLAIM_STATUS_PAID = 3;
    
    // Common expiration time (0 = no expiration)
    uint64 constant NO_EXPIRATION_TIME = 0;
    
    // Revocable flag
    bool constant REVOCABLE = true;
    bool constant NON_REVOCABLE = false;
}