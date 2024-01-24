// SPDX-License-Identifier: MIT
pragma solidity >0.8.19;

interface IEscrow {
    enum ProposalStatus {
        Proposed,
        Pending,
        Accepted,
        Completed,
        Rejected
    }

    struct NFT {
        address nftAddress;
        uint256 tokenId;
    }

    struct Proposal {
        uint id;
        address proposer;
        address proposee;
        NFT proposerNFT;
        NFT proposeeNFT;
        ProposalStatus status;
        uint timestamp;
    }

    function proposeSwap(NFT memory NFTIn, NFT memory NFTOut) external;

    function acceptSwapProposal(uint256 proposalId) external;

    function swap(uint256 proposalId) external;

    function cancelProposal(uint256 proposalId) external;

    event ProposalCreated(Proposal proposal);
}
