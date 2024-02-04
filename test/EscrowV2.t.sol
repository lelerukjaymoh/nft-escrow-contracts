// SPDX-License-Identifier: MIT
pragma solidity >0.8.19;

import "forge-std/Test.sol";
import {NFTEscrowV2} from "@escrow/EscrowV2.sol";
import {IEscrow} from "@escrow/interface/IProposal.sol";
import {NFTToken} from "./NFTToken.t.sol";

contract TestEscrowV2 is Test {
    NFTEscrowV2 escrow;
    NFTToken nft;

    address ADMIN = makeAddr("ADMIN");
    address proposer = makeAddr("proposer");
    address proposee = makeAddr("proposee");
    address escrowEOA = makeAddr("escrowEOA");

    function setUp() public {
        vm.createSelectFork("https://rpc.testnet.immutable.com");

        escrow = new NFTEscrowV2();
        escrow.initialize(ADMIN, escrowEOA);

        nft = new NFTToken();
        nft.mint(proposer, 1);
        nft.mint(proposee, 2);
    }

    function testEscrowInitialization() external {
        vm.startPrank(ADMIN);

        assertEq(
            escrow.hasRole(escrow.DEFAULT_ADMIN_ROLE(), ADMIN),
            true,
            "Admin role should be assigned to the deployer"
        );

        vm.stopPrank();
    }

    function testProposeSwap() external {
        vm.startPrank(proposer);
        escrow.proposeSwap(
            IEscrow.NFT({nftAddress: address(nft), tokenId: 1}),
            IEscrow.NFT({nftAddress: address(nft), tokenId: 2})
        );
        vm.stopPrank();

        (
            uint id,
            address _proposer,
            address _proposee,
            ,
            ,
            IEscrow.ProposalStatus status,

        ) = escrow.proposals(1);

        assertEq(id, 1, "Proposal id should be 1");
        assertEq(_proposer, proposer, "Proposer should be proposer");
        assertEq(_proposee, proposee, "Proposee should be address(0)");
        assertEq(
            uint(status),
            uint(IEscrow.ProposalStatus.Proposed),
            "Proposal status should be Proposed"
        );
    }

    function testAcceptSwapProposal() external {
        vm.startPrank(proposer);

        // propose swap
        escrow.proposeSwap(
            IEscrow.NFT({nftAddress: address(nft), tokenId: 1}),
            IEscrow.NFT({nftAddress: address(nft), tokenId: 2})
        );
        vm.stopPrank();

        vm.startPrank(proposee);
        // Accept swap proposal
        escrow.acceptSwapProposal(1);
        vm.stopPrank();

        (, , , , , IEscrow.ProposalStatus status, ) = escrow.proposals(1);

        assertEq(
            uint(status),
            uint(IEscrow.ProposalStatus.Completed),
            "Proposal status should be Completed"
        );
    }

    function testCancelProposal() external {
        vm.startPrank(proposer);
        // propose swap
        escrow.proposeSwap(
            IEscrow.NFT({nftAddress: address(nft), tokenId: 1}),
            IEscrow.NFT({nftAddress: address(nft), tokenId: 2})
        );

        // Cancel swap proposal
        escrow.cancelProposal(1);
        vm.stopPrank();

        (, , , , , IEscrow.ProposalStatus status, ) = escrow.proposals(1);

        console.log("status %s", uint(status));

        assertEq(
            uint(status),
            uint(IEscrow.ProposalStatus.Rejected),
            "Proposal status should be Rejected"
        );
    }

    function testRejectProposal() external {
        vm.startPrank(proposer);

        // propose swap
        escrow.proposeSwap(
            IEscrow.NFT({nftAddress: address(nft), tokenId: 1}),
            IEscrow.NFT({nftAddress: address(nft), tokenId: 2})
        );
        vm.stopPrank();

        vm.startPrank(proposee);
        // Reject swap proposal
        escrow.rejectProposal(1);
        vm.stopPrank();

        (, , , , , IEscrow.ProposalStatus status, ) = escrow.proposals(1);

        assertEq(
            uint(status),
            uint(IEscrow.ProposalStatus.Rejected),
            "Proposal status should be Rejected"
        );
    }
}
