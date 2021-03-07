pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

// SPDX-License-Identifier: SimPL-2.0

import "./interface/IERC721TokenReceiverEx.sol";
import "./interface/IERC20.sol";

import "./lib/Util.sol";

import "./Pixel.sol";
import "./Member.sol";

contract Vote is Member, IERC721TokenReceiverEx {
    struct VoterInfo {
        uint256 votes;
        uint256 amount;
        uint256 status;
    }

    struct NftInfo {
        address owner;
        uint256 nftId;
        uint256 votes;
        uint256 amount;
        uint256 status;
    }

    struct NftVoter {
        mapping(address => VoterInfo) voters;
    }

    struct Proposal {
        address creator;
        string name;
        string description;
        uint256 signupTime;
        uint256 voteTime;
        uint256 endTime;
        address token;
        address nft;
        uint256 unitAmount;
        uint256 nftNumber;
        NftInfo[] nftInfos;
        mapping(uint256 => NftVoter) nftVoters;
        mapping(address => VoterInfo) voters;
    }
    uint256 public proposalCount;

    event VoteEvent(
        address indexed owner,
        uint256 indexed nftId,
        uint256 totalAmount,
        uint256 totalVotes,
        uint256 amount,
        uint256 votes
    );

    mapping(uint256 => Proposal) public proposals;

    constructor() {
        proposalCount = 0;
    }

    function createProposal(
        string memory _name,
        string memory _description,
        uint256 _signupTime,
        uint256 _voteTime,
        uint256 _endTime,
        address _token,
        address _nft,
        uint256 _unitAmount
    ) external returns (uint256) {
        proposalCount++;

        Proposal storage curProposal = proposals[proposalCount];
        curProposal.creator = msg.sender;
        curProposal.name = _name;
        curProposal.description = _description;
        curProposal.signupTime = _signupTime;
        curProposal.voteTime = _voteTime;
        curProposal.endTime = _endTime;
        curProposal.token = _token;
        curProposal.unitAmount = _unitAmount;
        curProposal.nftNumber = 0;
        curProposal.nft = _nft;

        return proposalCount;
    }

    function getProposalNfts(uint256 proposalId)
        public
        view
        validProposal(proposalId)
        returns (NftInfo[] memory)
    {
        Proposal storage proposal = proposals[proposalId];
        return proposal.nftInfos;
    }

    function getMyProposalNftVote(uint256 proposalId, uint256 id)
        public
        view
        validProposal(proposalId)
        returns (VoterInfo memory)
    {
        Proposal storage proposal = proposals[proposalId];

        NftVoter storage nftVoters = proposal.nftVoters[id];
        VoterInfo storage nftVoterInfo = nftVoters.voters[msg.sender];
        return nftVoterInfo;
    }

    function onERC721Received(
        address,
        address from,
        uint256 nftId,
        bytes memory data
    ) external override returns (bytes4) {
        uint256 operate = uint8(data[0]);

        if (operate == 1) {
            uint256 proposalId = 0;
            for (uint256 i = 1; i != 33; ++i) {
                proposalId = (proposalId << 8) | uint8(data[i]);
            }
            Proposal storage proposal = proposals[proposalId];
            if (proposal.nft == msg.sender) {
                uint256[] memory nftIds = new uint256[](1);
                nftIds[0] = nftId;
                _addNfts(proposalId, from, nftIds);
            } else {
                return 0;
            }
        }

        return Util.ERC721_RECEIVER_RETURN;
    }

    function onERC721ExReceived(
        address,
        address from,
        uint256[] memory nftIds,
        bytes memory data
    ) external override returns (bytes4) {
        uint256 operate = uint8(data[0]);

        if (operate == 1) {
            uint256 proposalId = 0;
            for (uint256 i = 1; i != 33; ++i) {
                proposalId = (proposalId << 8) | uint8(data[i]);
            }
            Proposal storage proposal = proposals[proposalId];
            if (proposal.nft == msg.sender) {
                _addNfts(proposalId, from, nftIds);
            } else {
                return 0;
            }
        }

        return Util.ERC721_RECEIVER_EX_RETURN;
    }

    function _addNfts(
        uint256 proposalId,
        address account,
        uint256[] memory nftIds
    ) internal validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        uint256 _now = block.timestamp;

        //todo
        // require(proposal.signupTime > _now, "proposal hasn't start.");
        // require(proposal.voteTime < _now, "proposal has expired.");

        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            proposal.nftNumber++;

            proposal.nftInfos.push(
                NftInfo({
                    owner: account,
                    nftId: nftId,
                    votes: 0,
                    amount: 0,
                    status: 0
                })
            );

            // NftInfo storage info = proposal.nftInfos[proposal.nftNumber];

            // info.owner = account;
            // info.nftId = nftId;
            // info.votes = 0;
            // info.amount = 0;
        }
    }

    function castVote(
        uint256 proposalId,
        uint256 id,
        uint256 votes
    ) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        // uint256 _now = block.timestamp;

        // require(proposal.voteTime > _now, "proposal hasn't start.");
        // require(proposal.endTime < _now, "proposal has expired.");

        NftInfo storage info = proposal.nftInfos[id];

        NftVoter storage nftVoters = proposal.nftVoters[id];
        VoterInfo storage nftVoterInfo = nftVoters.voters[msg.sender];
        uint256 amount = sqrt(proposal.unitAmount, nftVoterInfo.votes, votes); // QV Vote
        _onTokenAdd(proposal.token, amount);

        nftVoterInfo.votes += votes;
        nftVoterInfo.amount += amount;
        info.amount += amount;
        info.votes += votes;

        VoterInfo storage voterInfo = proposal.voters[msg.sender];
        voterInfo.amount += amount;
        voterInfo.votes += votes;

        emit VoteEvent(
            msg.sender,
            proposalId,
            voterInfo.amount,
            voterInfo.votes,
            amount,
            votes
        );
    }

    function withdrawnft(uint256 proposalId, uint256 id)
        external
        validProposal(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];

        uint256 _now = block.timestamp;

        require(proposal.endTime > _now, "proposal hasn't ended.");

        NftInfo storage info = proposal.nftInfos[id];

        require(info.owner == msg.sender, "nft isn't owner");

        require(info.status != 1, "nft has withdrawed");
        info.status = 1;

        IERC721(proposal.nft).transferFrom(
            address(this),
            info.owner,
            info.nftId
        );
    }

    function withdrawtoken(uint256 proposalId)
        external
        validProposal(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        uint256 _now = block.timestamp;
        require(proposal.endTime > _now, "proposal hasn't ended.");

        VoterInfo storage voterInfo = proposal.voters[msg.sender];
        require(voterInfo.status != 1, "token has withdrawed");

        voterInfo.status = 1;

        _onTokenSub(proposal.token, voterInfo.amount);
    }

    function sqrt(
        uint256 unit,
        uint256 cur,
        uint256 votes
    ) internal pure returns (uint256 y) {
        uint256 amount = 0;
        for (uint256 i = 1; i <= votes; i++) {
            amount += unit * (cur + i);
        }
        require(amount > 0, "amount invalid");
        return amount;
    }

    /**
     * @dev checks if a proposal id is valid
     * @param proposalId the proposal id
     */
    modifier validProposal(uint256 proposalId) {
        require(
            proposalId > 0 && proposalId <= proposalCount,
            "Not a valid Proposal Id"
        );
        _;
    }

    function _onTokenAdd(address token, uint256 amount)
        internal
        returns (uint256)
    {
        if (token == address(0)) {
            return _onEthAdd(amount);
        } else {
            return _onErc20Add(token, amount);
        }
    }

    function _onErc20Add(address token, uint256 amount)
        internal
        returns (uint256)
    {
        IERC20 moneyIn = IERC20(token);
        require(
            moneyIn.transferFrom(msg.sender, address(this), amount),
            "money transfer failed"
        );
        return amount;
    }

    function _onEthAdd(uint256 amount) internal returns (uint256) {
        require(msg.value == amount, "invalid amount");
        return amount;
    }

    function _onTokenSub(address token, uint256 amount) internal {
        if (token == address(0)) {
            _onEthSub(amount);
        } else {
            _onErc20Sub(token, amount);
        }
    }

    function _onErc20Sub(address token, uint256 amount) internal {
        address payable owner = msg.sender;
        require(IERC20(token).transfer(owner, amount), "transfer money failed");
    }

    function _onEthSub(uint256 amount) internal {
        address payable owner = msg.sender;
        owner.transfer(amount);
    }
}
