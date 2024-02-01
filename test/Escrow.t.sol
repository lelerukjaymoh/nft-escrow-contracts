// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {NFTEscrow} from "@escrow/NFTEscrow.sol";
import {IEscrow} from "@escrow/interface/IProposal.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTToken is ERC721 {
    constructor() ERC721("MyToken", "MTK") {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

contract TestEscrow is Test {
    NFTEscrow escrow;
    NFTToken nft;

    address ADMIN = makeAddr("ADMIN");
    address proposer = makeAddr("proposer");
    address proposee = makeAddr("proposee");

    function setUp() public {
        vm.createSelectFork("https://rpc.testnet.immutable.com");
        escrow = new NFTEscrow();

        // initialize
        escrow.initialize(ADMIN);

        //mint
        nft = new NFTToken();

        // mint
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

    // Tests that when an NFT is transferred to the escrow contract, a swap proposal is created
    function testProposal() external {
        // transfer NFT from proposer to escrow contract
        bytes memory proposerData = abi.encode(
            address(nft),
            address(nft),
            1,
            2,
            0
        );

        vm.prank(proposer);
        IERC721(address(nft)).safeTransferFrom(
            proposer,
            address(escrow),
            1,
            proposerData
        );
        vm.stopPrank();

        (uint id, address _proposer, , , , , ) = escrow.proposals(1);

        assertEq(id, 1, "Proposal id should be 1");

        assertEq(_proposer, proposer, "Proposer should be the proposer");

        assertEq(
            IERC721(address(nft)).ownerOf(1),
            address(escrow),
            "Escrow contract should now be the owner of the proposer NFT"
        );

        bytes memory proposeeData = abi.encode(
            address(nft),
            address(nft),
            1,
            2,
            1
        );

        vm.prank(proposee);
        IERC721(address(nft)).safeTransferFrom(
            proposee,
            address(escrow),
            2,
            proposeeData
        );
        vm.stopPrank();

        (
            ,
            address __proposer,
            address _proposee,
            ,
            ,
            IEscrow.ProposalStatus status,

        ) = escrow.proposals(1);

        console.log("status: %s", uint(status), escrow.proposalCount());

        // Ensure the nfts where transferred to the proposer and proposee
        assertEq(
            IERC721(address(nft)).ownerOf(1),
            _proposee,
            "Proposee should now be the owner of the proposer NFT"
        );

        assertEq(
            IERC721(address(nft)).ownerOf(2),
            __proposer,
            "Proposer should now be the owner of the proposee NFT"
        );

        assertEq(uint(status), 1, "Proposal status should be accepted");
    }

    function testCanCancelProposal() external {
        // transfer NFT from proposer to escrow contract
        bytes memory proposerData = abi.encode(
            address(nft),
            address(nft),
            1,
            2,
            0
        );

        vm.prank(proposer);
        IERC721(address(nft)).safeTransferFrom(
            proposer,
            address(escrow),
            1,
            proposerData
        );
        vm.stopPrank();

        (uint id, address _proposer, , , , , ) = escrow.proposals(1);

        assertEq(id, 1, "Proposal id should be 1");

        assertEq(_proposer, proposer, "Proposer should be the proposer");

        assertEq(
            IERC721(address(nft)).ownerOf(1),
            address(escrow),
            "Escrow contract should now be the owner of the proposer NFT"
        );

        vm.prank(proposer);
        escrow.cancelProposal(1);
        vm.stopPrank();

        (, , , , , IEscrow.ProposalStatus status, ) = escrow.proposals(1);

        assertEq(uint(status), 2, "Proposal status should be Rejected");
    }

    function testCanRejectProposal() external {
        // transfer NFT from proposer to escrow contract
        bytes memory proposerData = abi.encode(
            address(nft),
            address(nft),
            1,
            2,
            0
        );

        vm.prank(proposer);
        IERC721(address(nft)).safeTransferFrom(
            proposer,
            address(escrow),
            1,
            proposerData
        );
        vm.stopPrank();

        (uint id, , address _proposee, , , , ) = escrow.proposals(1);

        assertEq(id, 1, "Proposal id should be 1");

        assertEq(_proposee, proposee, "Proposer should be the proposer");

        assertEq(
            IERC721(address(nft)).ownerOf(1),
            address(escrow),
            "Escrow contract should now be the owner of the proposer NFT"
        );

        vm.prank(proposee);
        escrow.rejectProposal(1);
        vm.stopPrank();

        (, , , , , IEscrow.ProposalStatus status, ) = escrow.proposals(1);

        assertEq(uint(status), 2, "Proposal status should be Rejected");
    }
}
