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
 * @dev Structs for different types of attestations
 */
library AttestationStructs {
    
    struct PolicyAttestationData {
        string policyId;
        address insuranceContract;
        address client;
        uint256 premiumPaid;
        uint256 payoutValue;
        string cropLocation;
        uint256 startDate;
        uint256 duration;
        bool isActive;
    }
    
    struct WeatherAttestationData {
        string location;
        uint256 timestamp;
        uint256 rainfall;
        string dataSource;
        bytes32 oracleRequestId;
        bool verified;
    }
    
    struct ClaimAttestationData {
        string policyId;
        uint256 claimAmount;
        uint256 timestamp;
        uint8 claimStatus; // 0: pending, 1: approved, 2: denied, 3: paid
        string evidence;
        bool droughtConfirmed;
    }
    
    struct ComplianceAttestationData {
        address entity;
        string regulationType;
        bool compliant;
        uint256 verificationDate;
        string certifyingAuthority;
    }
    
    struct PremiumAttestationData {
        string policyId;
        address client;
        uint256 amount;
        address token;
        bool paid;
        uint256 paidAt;
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