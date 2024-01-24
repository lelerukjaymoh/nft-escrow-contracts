// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

// OpenZeppelin imports
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

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

contract NFTEscrow is
    IEscrow,
    Initializable,
    AccessControlUpgradeable,
    IERC721Receiver
{
    uint proposalCount;
    mapping(uint => Proposal) public proposals;

    // modifier to ensure that a proposal exists
    modifier proposalExists(uint proposalId) {
        if (proposals[proposalId].proposer == address(0))
            revert ProposalDoesNotExist(proposalId);
        _;
    }

    function initialize(address defaultAdmin) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
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

        // Transfer NFT to escrow contract
        // Proposer must have approved the escrow contract
        IERC721(proposerNFT.nftAddress).transferFrom(
            msg.sender,
            address(this),
            proposerNFT.tokenId
        );

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
        if (proposals[proposalId].status != ProposalStatus.Pending)
            revert ProposalAlreadyApprovedOrCancelled();

        // Transfer NFT to escrow contract
        // Proposee must have approved the escrow contract
        IERC721(proposals[proposalId].proposeeNFT.nftAddress).transferFrom(
            msg.sender,
            address(this),
            proposals[proposalId].proposeeNFT.tokenId
        );

        // Update proposal status
        proposals[proposalId].status = ProposalStatus.Accepted;
    }

    function swap(
        uint proposalId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) proposalExists(proposalId) {
        // Ensure the proposal has been accepted by proposee before swapping
        if (proposals[proposalId].status != ProposalStatus.Accepted)
            revert ProposalHasNotBeenAcceptedYet(proposalId);

        // Ensure the proposal has not

        // Ensure both parties sent the NFT to the escrow contract
        NFT memory proposerNFT = proposals[proposalId].proposerNFT;
        NFT memory proposeeNFT = proposals[proposalId].proposeeNFT;

        if (
            IERC721(proposerNFT.nftAddress).ownerOf(proposerNFT.tokenId) !=
            address(this) ||
            IERC721(proposeeNFT.nftAddress).ownerOf(proposeeNFT.tokenId) !=
            address(this)
        ) revert NFTsAreNotHeldByEscrowContract(proposalId);

        // Transfer NFTs to each other
        IERC721(proposerNFT.nftAddress).transferFrom(
            address(this),
            proposeeNFT.nftAddress,
            proposerNFT.tokenId
        );

        IERC721(proposeeNFT.nftAddress).transferFrom(
            address(this),
            proposerNFT.nftAddress,
            proposeeNFT.tokenId
        );

        // Update proposal status
        proposals[proposalId].status = ProposalStatus.Completed;
    }

    function cancelProposal(
        uint proposalId
    ) external proposalExists(proposalId) {
        // Ensure the proposal is still pending before cancelling it
        if (proposals[proposalId].status == ProposalStatus.Pending)
            revert ProposalIsNotPending(proposalId);

        // Ensure only the proposer can cancel the proposal
        if (proposals[proposalId].proposer != msg.sender)
            revert OnlyProposerCanCancelProposal(proposalId);

        // Transfer NFT back to proposer
        IERC721(proposals[proposalId].proposerNFT.nftAddress).transferFrom(
            address(this),
            proposals[proposalId].proposer,
            proposals[proposalId].proposerNFT.tokenId
        );

        // Update proposal status
        proposals[proposalId].status = ProposalStatus.Rejected;
    }

    // reject proposal
    function rejectProposal(
        uint proposalId
    ) external proposalExists(proposalId) {
        // Ensure the proposal is still pending before rejecting it
        if (proposals[proposalId].status == ProposalStatus.Pending)
            revert ProposalIsNotPending(proposalId);

        // Ensure only the proposee can reject the proposal
        if (proposals[proposalId].proposee != msg.sender)
            revert OnlyProposeeCanRejectProposal(proposalId);

        // Transfer NFT back to proposer
        IERC721(proposals[proposalId].proposerNFT.nftAddress).transferFrom(
            address(this),
            proposals[proposalId].proposer,
            proposals[proposalId].proposerNFT.tokenId
        );

        // Update proposal status
        proposals[proposalId].status = ProposalStatus.Rejected;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
