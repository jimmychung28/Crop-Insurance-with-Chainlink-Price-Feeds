// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/ISchemaRegistry.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/Common.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./interfaces/IEASInsurance.sol";
import "./schemas/InsuranceSchemas.sol";

/**
 * @title EASInsuranceManager
 * @dev Central contract for managing EAS attestations in the crop insurance system
 */
contract EASInsuranceManager is IEASInsurance, Ownable, ReentrancyGuard {
    
    IEAS public immutable eas;
    ISchemaRegistry public immutable schemaRegistry;
    InsuranceSchemas public immutable schemas;
    
    // Mapping to track attestations by type and entity
    mapping(address => bytes32[]) private policyAttestations;
    mapping(string => bytes32[]) private weatherAttestations; // location => UIDs
    mapping(address => bytes32[]) private clientAttestations;
    mapping(address => bytes32[]) private complianceAttestations;
    mapping(address => bytes32[]) private premiumAttestations;
    
    // Mapping for quick attestation verification
    mapping(bytes32 => bool) private validAttestations;
    
    // Access control for attestation creation
    mapping(address => bool) public authorizedAttestors;
    mapping(address => bool) public oracleNodes;
    mapping(address => bool) public complianceProviders;
    
    // Attestation counters for analytics
    uint256 public totalPolicyAttestations;
    uint256 public totalWeatherAttestations;
    uint256 public totalClaimAttestations;
    uint256 public totalComplianceAttestations;
    uint256 public totalPremiumAttestations;
    
    // Events for attestation tracking
    event AttestorAuthorized(address indexed attestor, bool authorized);
    event OracleNodeRegistered(address indexed node, bool registered);
    event ComplianceProviderRegistered(address indexed provider, bool registered);
    
    modifier onlyAuthorizedAttestor() {
        require(authorizedAttestors[msg.sender] || msg.sender == owner(), "Not authorized to create attestations");
        _;
    }
    
    modifier onlyOracleNode() {
        require(oracleNodes[msg.sender] || msg.sender == owner(), "Not authorized oracle node");
        _;
    }
    
    modifier onlyComplianceProvider() {
        require(complianceProviders[msg.sender] || msg.sender == owner(), "Not authorized compliance provider");
        _;
    }
    
    constructor(
        address _eas,
        address _schemaRegistry,
        address _schemas
    ) {
        eas = IEAS(_eas);
        schemaRegistry = ISchemaRegistry(_schemaRegistry);
        schemas = InsuranceSchemas(_schemas);
        
        // Owner is automatically authorized
        authorizedAttestors[msg.sender] = true;
    }
    
    // =========================================================================
    // Access Control Management
    // =========================================================================
    
    function authorizeAttestor(address attestor, bool authorized) external onlyOwner {
        authorizedAttestors[attestor] = authorized;
        emit AttestorAuthorized(attestor, authorized);
    }
    
    function registerOracleNode(address node, bool registered) external onlyOwner {
        oracleNodes[node] = registered;
        emit OracleNodeRegistered(node, registered);
    }
    
    function registerComplianceProvider(address provider, bool registered) external onlyOwner {
        complianceProviders[provider] = registered;
        emit ComplianceProviderRegistered(provider, registered);
    }
    
    // =========================================================================
    // Schema UID Getters
    // =========================================================================
    
    function getPolicySchemaUID() external view override returns (bytes32) {
        return schemas.policySchemaUID();
    }
    
    function getWeatherSchemaUID() external view override returns (bytes32) {
        return schemas.weatherSchemaUID();
    }
    
    function getClaimSchemaUID() external view override returns (bytes32) {
        return schemas.claimSchemaUID();
    }
    
    function getComplianceSchemaUID() external view override returns (bytes32) {
        return schemas.complianceSchemaUID();
    }
    
    function getPremiumSchemaUID() external view override returns (bytes32) {
        return schemas.premiumSchemaUID();
    }
    
    // =========================================================================
    // Policy Attestations
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
    ) external override onlyAuthorizedAttestor returns (bytes32) {
        
        // Create policy ID from contract address and timestamp
        string memory policyId = string(abi.encodePacked(
            Strings.toHexString(uint256(uint160(policyContract)), 20),
            "_",
            Strings.toString(block.timestamp)
        ));
        
        AttestationStructs.PolicyAttestationData memory data = AttestationStructs.PolicyAttestationData({
            policyId: policyId,
            insuranceContract: policyContract,
            client: client,
            premiumPaid: premiumPaid,
            payoutValue: payoutValue,
            cropLocation: cropLocation,
            startDate: startDate,
            duration: duration,
            isActive: isActive
        });
        
        bytes memory encodedData = SchemaEncoders.encodePolicyData(data);
        
        AttestationRequest memory request = AttestationRequest({
            schema: schemas.policySchemaUID(),
            data: AttestationRequestData({
                recipient: client,
                expirationTime: NO_EXPIRATION_TIME,
                revocable: true,
                refUID: EMPTY_UID,
                data: encodedData,
                value: 0
            })
        });
        
        bytes32 uid = eas.attest(request);
        
        // Track the attestation
        policyAttestations[policyContract].push(uid);
        clientAttestations[client].push(uid);
        validAttestations[uid] = true;
        totalPolicyAttestations++;
        
        emit PolicyAttestationCreated(uid, policyContract, client, schemas.policySchemaUID());
        
        return uid;
    }
    
    // =========================================================================
    // Weather Attestations
    // =========================================================================
    
    function createWeatherAttestation(
        string calldata location,
        uint256 rainfall,
        string calldata dataSource,
        bytes32 oracleRequestId,
        bool verified
    ) external override onlyOracleNode returns (bytes32) {
        
        AttestationStructs.WeatherAttestationData memory data = AttestationStructs.WeatherAttestationData({
            location: location,
            timestamp: block.timestamp,
            rainfall: rainfall,
            dataSource: dataSource,
            oracleRequestId: oracleRequestId,
            verified: verified
        });
        
        bytes memory encodedData = SchemaEncoders.encodeWeatherData(data);
        
        AttestationRequest memory request = AttestationRequest({
            schema: schemas.weatherSchemaUID(),
            data: AttestationRequestData({
                recipient: address(0), // No specific recipient for weather data
                expirationTime: block.timestamp + 7 days, // Weather data expires after 7 days
                revocable: true,
                refUID: EMPTY_UID,
                data: encodedData,
                value: 0
            })
        });
        
        bytes32 uid = eas.attest(request);
        
        // Track the attestation
        weatherAttestations[location].push(uid);
        validAttestations[uid] = true;
        totalWeatherAttestations++;
        
        emit WeatherAttestationCreated(uid, location, rainfall, block.timestamp, schemas.weatherSchemaUID());
        
        return uid;
    }
    
    // =========================================================================
    // Claim Attestations
    // =========================================================================
    
    function createClaimAttestation(
        address policyContract,
        uint256 claimAmount,
        uint8 claimStatus,
        string calldata evidence,
        bool droughtConfirmed
    ) external override onlyAuthorizedAttestor returns (bytes32) {
        
        // Create claim ID from policy contract and timestamp
        string memory policyId = string(abi.encodePacked(
            Strings.toHexString(uint256(uint160(policyContract)), 20),
            "_claim_",
            Strings.toString(block.timestamp)
        ));
        
        AttestationStructs.ClaimAttestationData memory data = AttestationStructs.ClaimAttestationData({
            policyId: policyId,
            claimAmount: claimAmount,
            timestamp: block.timestamp,
            claimStatus: claimStatus,
            evidence: evidence,
            droughtConfirmed: droughtConfirmed
        });
        
        bytes memory encodedData = SchemaEncoders.encodeClaimData(data);
        
        // Get the client from policy attestations for recipient
        address client = address(0);
        bytes32[] memory policyUIDs = policyAttestations[policyContract];
        if (policyUIDs.length > 0) {
            Attestation memory policyAttestation = eas.getAttestation(policyUIDs[0]);
            client = policyAttestation.recipient;
        }
        
        AttestationRequest memory request = AttestationRequest({
            schema: schemas.claimSchemaUID(),
            data: AttestationRequestData({
                recipient: client,
                expirationTime: NO_EXPIRATION_TIME,
                revocable: false, // Claims should not be revocable for audit trail
                refUID: policyUIDs.length > 0 ? policyUIDs[0] : EMPTY_UID, // Reference to policy
                data: encodedData,
                value: 0
            })
        });
        
        bytes32 uid = eas.attest(request);
        
        // Track the attestation
        if (client != address(0)) {
            clientAttestations[client].push(uid);
        }
        validAttestations[uid] = true;
        totalClaimAttestations++;
        
        emit ClaimAttestationCreated(uid, policyContract, claimAmount, claimStatus, schemas.claimSchemaUID());
        
        return uid;
    }
    
    // =========================================================================
    // Compliance Attestations
    // =========================================================================
    
    function createComplianceAttestation(
        address entity,
        string calldata regulationType,
        bool compliant,
        string calldata certifyingAuthority
    ) external override onlyComplianceProvider returns (bytes32) {
        
        AttestationStructs.ComplianceAttestationData memory data = AttestationStructs.ComplianceAttestationData({
            entity: entity,
            regulationType: regulationType,
            compliant: compliant,
            verificationDate: block.timestamp,
            certifyingAuthority: certifyingAuthority
        });
        
        bytes memory encodedData = SchemaEncoders.encodeComplianceData(data);
        
        AttestationRequest memory request = AttestationRequest({
            schema: schemas.complianceSchemaUID(),
            data: AttestationRequestData({
                recipient: entity,
                expirationTime: block.timestamp + 365 days, // Compliance valid for 1 year
                revocable: true,
                refUID: EMPTY_UID,
                data: encodedData,
                value: 0
            })
        });
        
        bytes32 uid = eas.attest(request);
        
        // Track the attestation
        complianceAttestations[entity].push(uid);
        validAttestations[uid] = true;
        totalComplianceAttestations++;
        
        emit ComplianceAttestationCreated(uid, entity, regulationType, compliant, schemas.complianceSchemaUID());
        
        return uid;
    }
    
    // =========================================================================
    // Premium Attestations
    // =========================================================================
    
    function createPremiumAttestation(
        address policyContract,
        address client,
        uint256 amount,
        address token,
        bool paid
    ) external override onlyAuthorizedAttestor returns (bytes32) {
        
        // Create premium ID from policy contract
        string memory policyId = string(abi.encodePacked(
            Strings.toHexString(uint256(uint160(policyContract)), 20),
            "_premium"
        ));
        
        AttestationStructs.PremiumAttestationData memory data = AttestationStructs.PremiumAttestationData({
            policyId: policyId,
            client: client,
            amount: amount,
            token: token,
            paid: paid,
            paidAt: paid ? block.timestamp : 0
        });
        
        bytes memory encodedData = SchemaEncoders.encodePremiumData(data);
        
        // Reference to policy attestation if available
        bytes32 refUID = EMPTY_UID;
        bytes32[] memory policyUIDs = policyAttestations[policyContract];
        if (policyUIDs.length > 0) {
            refUID = policyUIDs[0];
        }
        
        AttestationRequest memory request = AttestationRequest({
            schema: schemas.premiumSchemaUID(),
            data: AttestationRequestData({
                recipient: client,
                expirationTime: NO_EXPIRATION_TIME,
                revocable: false, // Premium payments should not be revocable
                refUID: refUID,
                data: encodedData,
                value: 0
            })
        });
        
        bytes32 uid = eas.attest(request);
        
        // Track the attestation
        premiumAttestations[policyContract].push(uid);
        clientAttestations[client].push(uid);
        validAttestations[uid] = true;
        totalPremiumAttestations++;
        
        emit PremiumAttestationCreated(uid, policyContract, client, amount, schemas.premiumSchemaUID());
        
        return uid;
    }
    
    // =========================================================================
    // Attestation Queries
    // =========================================================================
    
    function getPolicyAttestations(address policyContract) external view override returns (bytes32[] memory) {
        return policyAttestations[policyContract];
    }
    
    function getWeatherAttestations(string calldata location) external view override returns (bytes32[] memory) {
        return weatherAttestations[location];
    }
    
    function getClientAttestations(address client) external view override returns (bytes32[] memory) {
        return clientAttestations[client];
    }
    
    function getComplianceAttestations(address entity) external view override returns (bytes32[] memory) {
        return complianceAttestations[entity];
    }
    
    function getPremiumAttestations(address policyContract) external view returns (bytes32[] memory) {
        return premiumAttestations[policyContract];
    }
    
    // =========================================================================
    // Verification Functions
    // =========================================================================
    
    function verifyPolicyAttestation(bytes32 uid) external view override returns (bool) {
        return _verifyAttestation(uid, schemas.policySchemaUID());
    }
    
    function verifyWeatherAttestation(bytes32 uid) external view override returns (bool) {
        return _verifyAttestation(uid, schemas.weatherSchemaUID());
    }
    
    function verifyClaimAttestation(bytes32 uid) external view override returns (bool) {
        return _verifyAttestation(uid, schemas.claimSchemaUID());
    }
    
    function _verifyAttestation(bytes32 uid, bytes32 expectedSchema) internal view returns (bool) {
        if (!validAttestations[uid]) {
            return false;
        }
        
        Attestation memory attestation = eas.getAttestation(uid);
        
        // Check if attestation exists and matches schema
        if (attestation.uid != uid || attestation.schema != expectedSchema) {
            return false;
        }
        
        // Check if attestation is not revoked
        if (attestation.revocationTime != 0) {
            return false;
        }
        
        // Check if attestation is not expired
        if (attestation.expirationTime != 0 && block.timestamp > attestation.expirationTime) {
            return false;
        }
        
        return true;
    }
    
    // =========================================================================
    // Revocation Functions
    // =========================================================================
    
    function revokePolicyAttestation(bytes32 uid, string calldata reason) external override onlyAuthorizedAttestor {
        _revokeAttestation(uid, reason);
    }
    
    function revokeWeatherAttestation(bytes32 uid, string calldata reason) external override onlyOracleNode {
        _revokeAttestation(uid, reason);
    }
    
    function revokeClaimAttestation(bytes32 uid, string calldata reason) external override onlyOwner {
        // Claims can only be revoked by owner as they should be permanent
        _revokeAttestation(uid, reason);
    }
    
    function _revokeAttestation(bytes32 uid, string calldata reason) internal {
        require(validAttestations[uid], "Attestation not found or already revoked");
        
        Attestation memory attestation = eas.getAttestation(uid);
        require(attestation.revocable, "Attestation is not revocable");
        
        RevocationRequest memory request = RevocationRequest({
            schema: attestation.schema,
            data: RevocationRequestData({
                uid: uid,
                value: 0
            })
        });
        
        eas.revoke(request);
        validAttestations[uid] = false;
    }
    
    // =========================================================================
    // Analytics and Reporting
    // =========================================================================
    
    function getAttestationStats() external view returns (
        uint256 totalPolicies,
        uint256 totalWeather,
        uint256 totalClaims,
        uint256 totalCompliance,
        uint256 totalPremiums
    ) {
        return (
            totalPolicyAttestations,
            totalWeatherAttestations,
            totalClaimAttestations,
            totalComplianceAttestations,
            totalPremiumAttestations
        );
    }
    
    function getLatestWeatherAttestation(string calldata location) external view returns (bytes32) {
        bytes32[] memory attestations = weatherAttestations[location];
        if (attestations.length == 0) {
            return bytes32(0);
        }
        return attestations[attestations.length - 1];
    }
    
    function getLatestPolicyAttestation(address policyContract) external view returns (bytes32) {
        bytes32[] memory attestations = policyAttestations[policyContract];
        if (attestations.length == 0) {
            return bytes32(0);
        }
        return attestations[attestations.length - 1];
    }
    
    // =========================================================================
    // Utility Functions
    // =========================================================================
    
    function getEASAddress() external view returns (address) {
        return address(eas);
    }
    
    function getSchemaRegistryAddress() external view returns (address) {
        return address(schemaRegistry);
    }
    
    function getSchemasAddress() external view returns (address) {
        return address(schemas);
    }
    
    function isValidAttestation(bytes32 uid) external view returns (bool) {
        return validAttestations[uid];
    }
}