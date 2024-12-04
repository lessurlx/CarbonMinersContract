// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AbstractPortal} from "@verax-attestation-registry/verax-contracts/contracts/abstracts/AbstractPortal.sol";
import {AttestationRegistry} from "@verax-attestation-registry/verax-contracts/contracts/AttestationRegistry.sol";
import {IRouter} from "@verax-attestation-registry/verax-contracts/contracts/interfaces/IRouter.sol";
import {AttestationPayload, Attestation} from "@verax-attestation-registry/verax-contracts/contracts/types/Structs.sol";

/**
 * @title  Carbon Portal
 * @author Carbon Member
 * @notice This contract aims to attest of Carbon Trade Member 
 */
contract CarbonPortal is AbstractPortal, Ownable {
    address public carbonContract;
    bytes32 public authorizedSchemas = 0x1064602e605302c554fa75e1ee5b65ac8bd5d962abd0830f73840ca138b3b1c7;
    mapping(address => bytes32) public attestationID;
    /// @dev Error thrown when the attestation subject is not the sender
    error SenderIsNotCarbonContract();
    /// @dev Error thrown when the attestation subject doesn't own an eFrog
    error SenderIsNotOwner();
    /// @dev Error thrown when the Schema is not authorized on this Portal
    error SchemaNotAuthorized();
    /// @notice Error thrown when an invalid Router address is given
    error RouterInvalid();
    /// @notice Error thrown when an invalid CarbonContract address is given
    error CarbonContractInvalid();

    /// @notice Event emitted when the router is updated
    event RouterUpdated(address routerAddress);
    /// @notice Event emitted when the CarbonContract is updated
    event CarbonContractUpdated(address carbonContractAddress);

    constructor(address[] memory _modules, address _router, address _carbonContract) AbstractPortal(_modules, _router) Ownable(msg.sender) {
        carbonContract = _carbonContract;
        router = IRouter(_router);
    }

    /**
     * @notice Run before the payload is attested
     * @param attestationPayload the attestation payload to be attested
     * @dev This function checks if
     *          the sender is Carbon Contract
     *          and if the schema is authorized
     */
    function _onAttest(
        AttestationPayload memory attestationPayload,
        address /*attester*/,
        uint256 /*value*/
    ) internal override {
        if (msg.sender != carbonContract) revert SenderIsNotCarbonContract();
        if (attestationPayload.schemaId != authorizedSchemas) revert SchemaNotAuthorized();
        // attestationID[msg.sender] = AttestationRegistry(router.getAttestationRegistry()).getNextAttestationId();
    }

    function updateAuthorizedSchema(bytes32 _schemaId) public onlyOwner {
        authorizedSchemas = _schemaId;
    }

    function updateCarbonContract(address _newCarbonContract) public onlyOwner {
        if (_newCarbonContract == address(0)) revert CarbonContractInvalid();
        carbonContract = _newCarbonContract;
        emit CarbonContractUpdated(_newCarbonContract);
    }

    /**
     * @notice Withdraw funds from the Portal
     * @param to the address to send the funds to
     * @param amount the amount to withdraw
     * @dev Only the owner can withdraw funds
     */
    function withdraw(address payable to, uint256 amount) external override onlyOwner {
        (bool s, ) = to.call{value: amount}("");
        if (!s) revert WithdrawFail();
    }
    
    // ============== get Attestation =====================
      /**
       * @notice Changes the address for the Router
       * @dev Only the registry owner can call this method
       */
      function updateRouter(address _router) public onlyOwner {
        if (_router == address(0)) revert RouterInvalid();
        router = IRouter(_router);
        emit RouterUpdated(_router);
      }

      /**
       * @notice Gets an attestation by its identifier
       * @param attester the attestation member
       * @return attestation the attestation, following EAS's format
       */
      function getAttestation(address attester) public view returns (Attestation memory attestation) {
          AttestationRegistry veraxAttestationRegistry = AttestationRegistry(router.getAttestationRegistry());
          Attestation memory veraxAttestation = veraxAttestationRegistry.getAttestation(attestationID[attester]);
          return veraxAttestation;
      }

    function uploadAttest(address attester) public {
        AttestationRegistry attestationRegistry = AttestationRegistry(router.getAttestationRegistry());
        attestationID[attester] = bytes32(abi.encode(attestationRegistry.getChainPrefix() + (attestationRegistry.getAttestationIdCounter()+1)));
        uint256 yearsecond = 356 days;
        uint256 expirationDate = block.timestamp + (100 * yearsecond);
        bool ismember = true;
        AttestationPayload memory attestationPayload = AttestationPayload(authorizedSchemas, uint64(expirationDate), abi.encodePacked(attester), abi.encode(ismember));
        bytes[] memory validationPayloads = new bytes[](0);
        attest(attestationPayload, validationPayloads);
    }

    function isMember(address attester)  public view returns(bool) {
	return attestationID[attester] != bytes32(0);
    }
}
