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
error ProposalAlreadyApprovedOrCancelled();
error ProposalDoesNotExist(uint proposalId);
error OnlyProposerCanCancelProposal(uint proposalId);
error ProposerNFTIsNotHeldByEscrowContract(uint proposalId);
error ProposalIsNotPending(uint proposalId);
error OnlyProposeeCanRejectProposal(uint proposalId);
error invalidNFTTransferred(uint expectedTokenId, uint actualTokenId);

/**
 * @title NFTEscrow
 * @author Jay
 * @notice this contract enbales users to swap NFTs though a trustless escrow
 * @dev Thoughout the contract,
 * - the term proposer refers to the user who initiates the swap
 * - the term proposee refers to the user who accepts the swap
 * - the term proposerNFT refers to the NFT the proposer is offering
 * - the term proposeeNFT refers to the NFT the proposee is offering
 * - the term proposal refers to the swap proposal
 */
contract NFTEscrow is
    IEscrow,
    Initializable,
    AccessControlUpgradeable,
    IERC721Receiver
{
    uint public proposalCount;
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

    /**
     * Cancels a proposal given its id
     * @dev this function can only be called by the proposer
     * @dev transfers the NFT back to the proposer
     * @param proposalId The id of the proposal to cancel
     */
    function cancelProposal(
        uint proposalId
    ) external proposalExists(proposalId) {
        // Ensure the proposal has been proposed before rejecting it
        if (proposals[proposalId].status != ProposalStatus.Proposed)
            revert ProposalIsNotPending(proposalId);

        // Ensure only the proposer can cancel the proposal
        if (proposals[proposalId].proposer != msg.sender)
            revert OnlyProposerCanCancelProposal(proposalId);

        // Update proposal status
        proposals[proposalId].status = ProposalStatus.Rejected;

        // Transfer NFT back to proposer
        IERC721(proposals[proposalId].proposerNFT.nftAddress).transferFrom(
            address(this),
            proposals[proposalId].proposer,
            proposals[proposalId].proposerNFT.tokenId
        );
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
        // Ensure the proposal has been proposed before rejecting it
        if (proposals[proposalId].status != ProposalStatus.Proposed)
            revert ProposalIsNotPending(proposalId);

        // Ensure only the proposee can reject the proposal
        if (proposals[proposalId].proposee != msg.sender)
            revert OnlyProposeeCanRejectProposal(proposalId);

        // Update proposal status
        proposals[proposalId].status = ProposalStatus.Rejected;

        // Transfer NFT back to proposer
        IERC721(proposals[proposalId].proposerNFT.nftAddress).transferFrom(
            address(this),
            proposals[proposalId].proposer,
            proposals[proposalId].proposerNFT.tokenId
        );
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

    /**
     * is called when an NFT is transferred to the escrow contract
     * @dev this callback function is called on each transfer of the NFT to the escrow contract
     * With this we are able to execute most of the escrow logic on NFT transfer. This improves the UX and make it easier and cheaper for users to interact with the escrow
     *
     * In comparison the normal flow would be:
     * - User approves the escrow contract to spend his NFT
     * - User initiates the NFT transfer and creates the proposal
     *
     * Instead we are able to do all of this in one transaction
     * - When the user transfers the NFT to the escrow contract, we make use of this callback function to process vaildate and create the proposal
     *
     * *********************************************
     *
     * When an NFT is received in the escrow contract,
     * - check if its a proposeSwap or acceptSwapProposal.
     *   A proposeSwap is when a user is proposing a new Swap to the proposee. An acceptSwapProposal is when the proposee is accepting a previous proposal
     *   We can differentiate between the two by checking if the proposalId is provided in the transfer data
     * - if its a proposeSwap,
     *      * validate that the NFT the proposer sent is what he has provided in his swap proposal,
     *      * then create a new proposal
     * - if its an acceptSwapProposal,
     *      * ensure the data provided in the transfer is valid
     *      * validate that the NFT the proposee sent is what was expected per the swap proposal
     *      * ensure the proposer has not be completed yet. This is to prevent the proposee from accepting a proposal that has already been completed
     *      * once this checks are acertained, the NFT are transferred to the respective parties
     *      * and the proposal is marked as completed
     *
     *
     * @param "" this is who called the transfer function, in this case it will always be the from address so we dont need it
     * @param from this is who previously owned the NFT
     * @param tokenId the id of the NFT
     * @param data the data sent in the transfer
     */
    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes memory data
    ) external returns (bytes4) {
        //  Decode data sent in the transfer
        (
            address proposerNFTAddress,
            address proposeeNFTAddress,
            uint proposerTokenId,
            uint proposeeTokenId,
            uint proposalId
        ) = abi.decode(data, (address, address, uint, uint, uint));

        // If the proposalId is provided as 0 it means this is a new proposal being created
        if (proposalId == 0) {
            // Ensure the token being transferred is the one that was proposed
            if (proposerTokenId != tokenId)
                revert invalidNFTTransferred(proposeeTokenId, tokenId);

            // Set the proposeeNFT owner as the proposee
            address proposee = IERC721(proposeeNFTAddress).ownerOf(
                proposeeTokenId
            );

            proposalCount += 1;

            NFT memory proposerNFT = NFT(proposerNFTAddress, proposerTokenId);
            NFT memory proposeeNFT = NFT(proposeeNFTAddress, proposeeTokenId);

            // Create proposal
            Proposal memory proposal = IEscrow.Proposal({
                id: proposalCount,
                proposer: from,
                proposee: proposee,
                proposerNFT: proposerNFT,
                proposeeNFT: proposeeNFT,
                status: ProposalStatus.Proposed,
                timestamp: block.timestamp
            });

            proposals[proposalCount] = proposal;

            emit ProposalCreated(proposal);
        } else {
            // Get the proposal
            Proposal storage proposal = proposals[proposalId];

            // Check that the proposal exists
            if (proposal.proposer == address(0))
                revert ProposalDoesNotExist(proposalId);

            // Ensure the token being transferred is the one that was expected to be rceieved from the proposee
            if (proposal.proposeeNFT.tokenId != tokenId)
                revert invalidNFTTransferred(proposeeTokenId, tokenId);

            // Ensure the proposal is still pending before accepting it
            if (proposal.status != ProposalStatus.Proposed)
                revert ProposalAlreadyApprovedOrCancelled();

            // Ensure the proposer already transferred his nft to the escrow contract
            if (
                IERC721(proposal.proposerNFT.nftAddress).ownerOf(
                    proposal.proposerNFT.tokenId
                ) != address(this)
            ) revert ProposerNFTIsNotHeldByEscrowContract(proposalId);

            // Update proposal status
            proposal.status = ProposalStatus.Completed;

            IERC721(proposal.proposerNFT.nftAddress).transferFrom(
                address(this),
                proposal.proposee,
                proposal.proposerNFT.tokenId
            );

            IERC721(proposal.proposeeNFT.nftAddress).transferFrom(
                address(this),
                proposal.proposer,
                proposal.proposeeNFT.tokenId
            );
        }

        // If successful, return the magic value to allow the transfer to complete
        return this.onERC721Received.selector;
    }
}
