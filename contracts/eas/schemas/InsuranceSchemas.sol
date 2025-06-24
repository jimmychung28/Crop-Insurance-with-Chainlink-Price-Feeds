// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@ethereum-attestation-service/eas-contracts/contracts/ISchemaRegistry.sol";
import "../interfaces/IEASInsurance.sol";

/**
 * @title InsuranceSchemas
 * @dev Contract for managing and registering EAS schemas for crop insurance
 */
contract InsuranceSchemas {
    
    ISchemaRegistry public immutable schemaRegistry;
    
    // Schema UIDs for different attestation types
    bytes32 public policySchemaUID;
    bytes32 public weatherSchemaUID;
    bytes32 public claimSchemaUID;
    bytes32 public complianceSchemaUID;
    bytes32 public premiumSchemaUID;
    
    // Additional specialized schemas
    bytes32 public oracleReliabilitySchemaUID;
    bytes32 public kycSchemaUID;
    bytes32 public auditSchemaUID;
    bytes32 public riskAssessmentSchemaUID;
    
    address public immutable owner;
    bool public schemasRegistered;
    
    event SchemaRegistered(string name, bytes32 uid, string schema);
    event AllSchemasRegistered(uint256 timestamp);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier schemasNotRegistered() {
        require(!schemasRegistered, "Schemas already registered");
        _;
    }
    
    constructor(address _schemaRegistry) {
        schemaRegistry = ISchemaRegistry(_schemaRegistry);
        owner = msg.sender;
    }
    
    /**
     * @dev Register all insurance-related schemas
     * This should be called once during deployment
     */
    function registerAllSchemas() external onlyOwner schemasNotRegistered {
        // Register core insurance schemas
        _registerPolicySchema();
        _registerWeatherSchema();
        _registerClaimSchema();
        _registerComplianceSchema();
        _registerPremiumSchema();
        
        // Register additional specialized schemas
        _registerOracleReliabilitySchema();
        _registerKYCSchema();
        _registerAuditSchema();
        _registerRiskAssessmentSchema();
        
        schemasRegistered = true;
        emit AllSchemasRegistered(block.timestamp);
    }
    
    /**
     * @dev Register policy attestation schema
     * Tracks insurance policy creation and lifecycle
     */
    function _registerPolicySchema() internal {
        string memory schema = EASConstants.POLICY_SCHEMA;
        
        policySchemaUID = schemaRegistry.register(
            schema,
            ISchemaResolver(address(0)), // No resolver initially
            true // Revocable
        );
        
        emit SchemaRegistered("Policy", policySchemaUID, schema);
    }
    
    /**
     * @dev Register weather data attestation schema
     * Tracks weather observations from multiple sources
     */
    function _registerWeatherSchema() internal {
        string memory schema = EASConstants.WEATHER_SCHEMA;
        
        weatherSchemaUID = schemaRegistry.register(
            schema,
            ISchemaResolver(address(0)), // No resolver initially
            true // Revocable
        );
        
        emit SchemaRegistered("Weather", weatherSchemaUID, schema);
    }
    
    /**
     * @dev Register claim attestation schema
     * Tracks insurance claims and payouts
     */
    function _registerClaimSchema() internal {
        string memory schema = EASConstants.CLAIM_SCHEMA;
        
        claimSchemaUID = schemaRegistry.register(
            schema,
            ISchemaResolver(address(0)), // No resolver initially
            false // Non-revocable for audit trail
        );
        
        emit SchemaRegistered("Claim", claimSchemaUID, schema);
    }
    
    /**
     * @dev Register compliance attestation schema
     * Tracks regulatory compliance status
     */
    function _registerComplianceSchema() internal {
        string memory schema = EASConstants.COMPLIANCE_SCHEMA;
        
        complianceSchemaUID = schemaRegistry.register(
            schema,
            ISchemaResolver(address(0)), // No resolver initially
            true // Revocable when compliance status changes
        );
        
        emit SchemaRegistered("Compliance", complianceSchemaUID, schema);
    }
    
    /**
     * @dev Register premium payment attestation schema
     * Tracks premium payments and collection
     */
    function _registerPremiumSchema() internal {
        string memory schema = EASConstants.PREMIUM_SCHEMA;
        
        premiumSchemaUID = schemaRegistry.register(
            schema,
            ISchemaResolver(address(0)), // No resolver initially
            false // Non-revocable for financial audit trail
        );
        
        emit SchemaRegistered("Premium", premiumSchemaUID, schema);
    }
    
    /**
     * @dev Register oracle reliability attestation schema
     * Tracks performance and reliability of weather data oracles
     */
    function _registerOracleReliabilitySchema() internal {
        string memory schema = "address oracle,string dataSource,uint256 timestamp,uint256 responseTime,bool successful,uint256 accuracy,string metrics";
        
        oracleReliabilitySchemaUID = schemaRegistry.register(
            schema,
            ISchemaResolver(address(0)),
            true // Revocable for updates
        );
        
        emit SchemaRegistered("OracleReliability", oracleReliabilitySchemaUID, schema);
    }
    
    /**
     * @dev Register KYC/AML attestation schema
     * Tracks client identity verification
     */
    function _registerKYCSchema() internal {
        string memory schema = "address client,string verificationType,bool verified,uint256 verificationDate,address verifier,string complianceLevel,bytes32 documentHash";
        
        kycSchemaUID = schemaRegistry.register(
            schema,
            ISchemaResolver(address(0)),
            true // Revocable when verification status changes
        );
        
        emit SchemaRegistered("KYC", kycSchemaUID, schema);
    }
    
    /**
     * @dev Register audit trail attestation schema
     * Tracks administrative actions and changes
     */
    function _registerAuditSchema() internal {
        string memory schema = "address actor,string action,uint256 timestamp,string details,bytes32 transactionHash,string category";
        
        auditSchemaUID = schemaRegistry.register(
            schema,
            ISchemaResolver(address(0)),
            false // Non-revocable for audit integrity
        );
        
        emit SchemaRegistered("Audit", auditSchemaUID, schema);
    }
    
    /**
     * @dev Register risk assessment attestation schema
     * Tracks risk analysis for policies and regions
     */
    function _registerRiskAssessmentSchema() internal {
        string memory schema = "string location,uint256 timestamp,uint8 riskLevel,string riskFactors,uint256 historicalLosses,address assessor,bool approved";
        
        riskAssessmentSchemaUID = schemaRegistry.register(
            schema,
            ISchemaResolver(address(0)),
            true // Revocable for risk updates
        );
        
        emit SchemaRegistered("RiskAssessment", riskAssessmentSchemaUID, schema);
    }
    
    /**
     * @dev Get all registered schema UIDs
     * @return Array of all schema UIDs in order
     */
    function getAllSchemaUIDs() external view returns (bytes32[] memory) {
        bytes32[] memory schemas = new bytes32[](9);
        schemas[0] = policySchemaUID;
        schemas[1] = weatherSchemaUID;
        schemas[2] = claimSchemaUID;
        schemas[3] = complianceSchemaUID;
        schemas[4] = premiumSchemaUID;
        schemas[5] = oracleReliabilitySchemaUID;
        schemas[6] = kycSchemaUID;
        schemas[7] = auditSchemaUID;
        schemas[8] = riskAssessmentSchemaUID;
        return schemas;
    }
    
    /**
     * @dev Get schema information by name
     * @param schemaName Name of the schema
     * @return uid Schema UID
     * @return schema Schema definition string
     */
    function getSchemaByName(string calldata schemaName) external view returns (bytes32 uid, string memory schema) {
        bytes32 nameHash = keccak256(bytes(schemaName));
        
        if (nameHash == keccak256(bytes("Policy"))) {
            return (policySchemaUID, EASConstants.POLICY_SCHEMA);
        } else if (nameHash == keccak256(bytes("Weather"))) {
            return (weatherSchemaUID, EASConstants.WEATHER_SCHEMA);
        } else if (nameHash == keccak256(bytes("Claim"))) {
            return (claimSchemaUID, EASConstants.CLAIM_SCHEMA);
        } else if (nameHash == keccak256(bytes("Compliance"))) {
            return (complianceSchemaUID, EASConstants.COMPLIANCE_SCHEMA);
        } else if (nameHash == keccak256(bytes("Premium"))) {
            return (premiumSchemaUID, EASConstants.PREMIUM_SCHEMA);
        } else {
            revert("Schema not found");
        }
    }
    
    /**
     * @dev Check if all schemas are registered and ready
     * @return True if all schemas are registered
     */
    function areSchemasReady() external view returns (bool) {
        return schemasRegistered && 
               policySchemaUID != bytes32(0) &&
               weatherSchemaUID != bytes32(0) &&
               claimSchemaUID != bytes32(0) &&
               complianceSchemaUID != bytes32(0) &&
               premiumSchemaUID != bytes32(0);
    }
    
    /**
     * @dev Get schema registry contract address
     * @return Address of the schema registry
     */
    function getSchemaRegistry() external view returns (address) {
        return address(schemaRegistry);
    }
}

/**
 * @title SchemaEncoders
 * @dev Helper library for encoding attestation data according to schemas
 */
library SchemaEncoders {
    
    /**
     * @dev Encode policy attestation data
     */
    function encodePolicyData(
        AttestationStructs.PolicyAttestationData memory data
    ) internal pure returns (bytes memory) {
        return abi.encode(
            data.policyId,
            data.insuranceContract,
            data.client,
            data.premiumPaid,
            data.payoutValue,
            data.cropLocation,
            data.startDate,
            data.duration,
            data.isActive
        );
    }
    
    /**
     * @dev Encode weather attestation data
     */
    function encodeWeatherData(
        AttestationStructs.WeatherAttestationData memory data
    ) internal pure returns (bytes memory) {
        return abi.encode(
            data.location,
            data.timestamp,
            data.rainfall,
            data.dataSource,
            data.oracleRequestId,
            data.verified
        );
    }
    
    /**
     * @dev Encode claim attestation data
     */
    function encodeClaimData(
        AttestationStructs.ClaimAttestationData memory data
    ) internal pure returns (bytes memory) {
        return abi.encode(
            data.policyId,
            data.claimAmount,
            data.timestamp,
            data.claimStatus,
            data.evidence,
            data.droughtConfirmed
        );
    }
    
    /**
     * @dev Encode compliance attestation data
     */
    function encodeComplianceData(
        AttestationStructs.ComplianceAttestationData memory data
    ) internal pure returns (bytes memory) {
        return abi.encode(
            data.entity,
            data.regulationType,
            data.compliant,
            data.verificationDate,
            data.certifyingAuthority
        );
    }
    
    /**
     * @dev Encode premium attestation data
     */
    function encodePremiumData(
        AttestationStructs.PremiumAttestationData memory data
    ) internal pure returns (bytes memory) {
        return abi.encode(
            data.policyId,
            data.client,
            data.amount,
            data.token,
            data.paid,
            data.paidAt
        );
    }
    
    /**
     * @dev Encode oracle reliability data
     */
    function encodeOracleReliabilityData(
        address oracle,
        string memory dataSource,
        uint256 timestamp,
        uint256 responseTime,
        bool successful,
        uint256 accuracy,
        string memory metrics
    ) internal pure returns (bytes memory) {
        return abi.encode(
            oracle,
            dataSource,
            timestamp,
            responseTime,
            successful,
            accuracy,
            metrics
        );
    }
    
    /**
     * @dev Encode KYC data
     */
    function encodeKYCData(
        address client,
        string memory verificationType,
        bool verified,
        uint256 verificationDate,
        address verifier,
        string memory complianceLevel,
        bytes32 documentHash
    ) internal pure returns (bytes memory) {
        return abi.encode(
            client,
            verificationType,
            verified,
            verificationDate,
            verifier,
            complianceLevel,
            documentHash
        );
    }
    
    /**
     * @dev Encode audit trail data
     */
    function encodeAuditData(
        address actor,
        string memory action,
        uint256 timestamp,
        string memory details,
        bytes32 transactionHash,
        string memory category
    ) internal pure returns (bytes memory) {
        return abi.encode(
            actor,
            action,
            timestamp,
            details,
            transactionHash,
            category
        );
    }
    
    /**
     * @dev Encode risk assessment data
     */
    function encodeRiskAssessmentData(
        string memory location,
        uint256 timestamp,
        uint8 riskLevel,
        string memory riskFactors,
        uint256 historicalLosses,
        address assessor,
        bool approved
    ) internal pure returns (bytes memory) {
        return abi.encode(
            location,
            timestamp,
            riskLevel,
            riskFactors,
            historicalLosses,
            assessor,
            approved
        );
    }
}