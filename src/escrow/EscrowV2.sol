// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

// OpenZeppelin imports
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// Interfaces
import {IEscrow} from "@escrow/interface/IProposal.sol";

// Errors
error OnlyProposeeCanAcceptProposal();
error ProposalAlreadyApprovedOrCancelled();
error ProposalDoesNotExist(uint proposalId);
error OnlyNFTOwnerCanPropose();
error OnlyProposerCanCancelProposal(uint proposalId);
error NFTsAreNotHeldByEscrowContract(uint proposalId);
error ProposalHasNotBeenAcceptedYet(uint proposalId);
error ProposalIsNotPending(uint proposalId);
error OnlyProposeeCanRejectProposal(uint proposalId);

/**
 * @title NFTEscrow
 * @author Jay
 * @notice this v2 escrow contract enables managing the state of NFT swap proposals
 * @dev The V2 contract is a degrade of the NFTEscrow contract since the NFTEscrow contract is not supported on the immutable network
 *      Immutable network does not support transfer of NFTs from and to smart contracts which was a major requirement for the NFTEscrow contract.
 *      The v2 contract works by only updating the state of the proposals and depending on an EOA Escrow address to handle the transfer of NFTs
 * @dev Thoughout the contract,
 *      - the term proposer refers to the user who initiates the swap
 *      - the term proposee refers to the user who accepts the swap
 *      - the term proposerNFT refers to the NFT the proposer is offering
 *      - the term proposeeNFT refers to the NFT the proposee is offering
 *      - the term proposal refers to the swap proposal
 */
contract NFTEscrowV2 is IEscrow, Initializable, AccessControlUpgradeable {
    uint proposalCount;
    mapping(uint => Proposal) public proposals;
    address private ESCROW_EOA;

    // modifier to ensure that a proposal exists
    modifier proposalExists(uint proposalId) {
        if (proposals[proposalId].proposer == address(0))
            revert ProposalDoesNotExist(proposalId);
        _;
    }

    function initialize(
        address defaultAdmin,
        address escrowEOA
    ) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        ESCROW_EOA = escrowEOA;
    }

    function proposeSwap(
        NFT memory proposerNFT,
        NFT memory proposeeNFT
    ) external {
        // Ensure the proposer is the owner of the proposerNFT
        if (
            IERC721(proposerNFT.nftAddress).ownerOf(proposerNFT.tokenId) !=
            msg.sender
        ) revert OnlyNFTOwnerCanPropose();

        // Set the proposeeNFT owner as the proposee
        address proposee = IERC721(proposeeNFT.nftAddress).ownerOf(
            proposeeNFT.tokenId
        );

        proposalCount += 1;

        // Create proposal
        Proposal memory proposal = IEscrow.Proposal({
            id: proposalCount,
            proposer: msg.sender,
            proposee: proposee,
            proposerNFT: proposerNFT,
            proposeeNFT: proposeeNFT,
            status: ProposalStatus.Proposed,
            timestamp: block.timestamp
        });

        proposals[proposalCount] = proposal;

        emit ProposalCreated(proposal);
    }

    function acceptSwapProposal(
        uint256 proposalId
    ) external proposalExists(proposalId) {
        // Ensure proposal can only be accepted by the set proposee
        if (proposals[proposalId].proposee != msg.sender)
            revert OnlyProposeeCanAcceptProposal();

        // Ensure the proposal is still pending before accepting it
        if (proposals[proposalId].status != ProposalStatus.Proposed)
            revert ProposalAlreadyApprovedOrCancelled();

        // Update proposal status
        proposals[proposalId].status = ProposalStatus.Completed;
    }

    function swap(
        uint proposalId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) proposalExists(proposalId) {
        // Ensure the proposal has been accepted by proposee before swapping
        if (proposals[proposalId].status != ProposalStatus.Completed)
            revert ProposalHasNotBeenAcceptedYet(proposalId);

        // Ensure the proposal has not

        // Ensure both parties transferred the NFT to the escrow EOA
        NFT memory proposerNFT = proposals[proposalId].proposerNFT;
        NFT memory proposeeNFT = proposals[proposalId].proposeeNFT;

        if (
            IERC721(proposerNFT.nftAddress).ownerOf(proposerNFT.tokenId) !=
            ESCROW_EOA ||
            IERC721(proposeeNFT.nftAddress).ownerOf(proposeeNFT.tokenId) !=
            ESCROW_EOA
        ) revert NFTsAreNotHeldByEscrowContract(proposalId);

        // Update proposal status
        proposals[proposalId].status = ProposalStatus.Completed;
    }

    /**
     * Cancels a proposal given its id
     * @dev this function can only be called by the proposer
     * @dev transfers the NFT back to the proposer
     * @param proposalId The id of the proposal to cancel
     */
    function cancelProposal(
        uint proposalId
    ) external proposalExists(proposalId) {
        // Ensure the proposal is still pending before cancelling it
        if (proposals[proposalId].status != ProposalStatus.Proposed)
            revert ProposalIsNotPending(proposalId);

        // Ensure only the proposer can cancel the proposal
        if (proposals[proposalId].proposer != msg.sender)
            revert OnlyProposerCanCancelProposal(proposalId);

        // Update proposal status
        proposals[proposalId].status = ProposalStatus.Rejected;
    }

    /**
     * Rejects a proposal given its id
     * @dev this function can only be called by the proposee
     * @dev transfers the NFT back to the proposer
     * @param proposalId The id of the proposal to reject
     */
    function rejectProposal(
        uint proposalId
    ) external proposalExists(proposalId) {
        // Ensure the proposal is still pending before rejecting it
        if (proposals[proposalId].status != ProposalStatus.Proposed)
            revert ProposalIsNotPending(proposalId);

        // Ensure only the proposee can reject the proposal
        if (proposals[proposalId].proposee != msg.sender)
            revert OnlyProposeeCanRejectProposal(proposalId);

        // Update proposal status
        proposals[proposalId].status = ProposalStatus.Rejected;
    }

    /**
     * Returns all proposals
     * @dev you can hit the max gas limit in call requests if there are too many proposals
     * @return proposals An array of all proposals
     */
    function getProposals() external view returns (Proposal[] memory) {
        Proposal[] memory _proposals = new Proposal[](proposalCount);

        for (uint i = 0; i < proposalCount; i++) {
            _proposals[i] = proposals[i + 1];
        }

        return _proposals;
    }
}
