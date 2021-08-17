// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract WarehouseReceipt is ERC721URIStorage {
    using SafeMath for uint256;

    enum LoanState {
        START,
        END
    }

    LoanState public state;

    struct Receipt {
        uint256 warehouseId;
    }

    struct Loan {
        uint256 id;
        uint256 duration;
        uint256 amount;
        string details;
    }

    Loan[] public loans;

    uint256 public newLoanId;
    bytes4 internal constant MAGIC_ERC721_RECEIVED =
        bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));

    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    mapping(uint256 => Loan) public loanIndex;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public loanIncites;
    mapping(uint256 => address) public loanToId;
    mapping(uint256 => address) public approvedLoan;
    mapping(address => mapping(address => bool))
        private _collateralManagerApproval;

    event LoanCreated(
        uint256 loanId,
        uint256 duration,
        uint256 amount,
        string details
    );

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    function createLoan(
        uint256 id,
        uint256 duration,
        uint256 amount,
        string memory details
    ) external {
        _createLoan(id, duration, amount, details);
        state = LoanState.START;
    }

    function getLoan(uint256 id)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            string memory
        )
    {
        Loan memory loan = loans[id];
        return (loan.id, loan.duration, loan.amount, loan.details);
    }

    function totalSupply() external view returns (uint256) {
        return loans.length;
    }

    function balanceOf(address owner)
        public
        view
        override
        returns (uint256 balance)
    {
        return loanIncites[owner];
    }

    function ownerOf(uint256 tokenId)
        public
        view
        override
        returns (address owner)
    {
        return loanToId[tokenId];
    }

    /* 
        When you write require statements, ALWAYS include an error message at the end.
        The compiler can run into issues later when migrating the smart contracts.
     */

    function transfer(address to, uint256 tokenId)
        external
        isOwner(msg.sender, tokenId)
        noZeroAddress(to)
    {
        require(to != address(this), "Cannot transfer to its own contract");
        _transfer(msg.sender, to, tokenId);
    }

    function approve(address _approved, uint256 _tokenId)
        public
        override
        isOwner(_approved, _tokenId)
        noZeroAddress(_approved)
    {
        _approve(_approved, _tokenId);
        emit Approval(loanToId[_tokenId], _approved, _tokenId);
    }

    function setApprovalForAll(address operator, bool _approved)
        public
        override
        noZeroAddress(operator)
    {
        require(operator != msg.sender);
        _setApprovalForAll(operator, _approved);
        emit ApprovalForAll(msg.sender, operator, _approved);
    }

    function getApproved(uint256 _tokenId)
        public
        view
        override
        returns (address)
    {
        require(_tokenId < loans.length);
        return approvedLoan[_tokenId];
    }

    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override
        returns (bool)
    {
        return _collateralManagerApproval[_owner][_operator];
    }

    function mintNFT(
        uint256 receiptId,
        uint256 amount,
        uint256 collateral,
        address _owner,
        address _operator
    ) external view returns (bool) {
        require(receiptId > 0);
        require(collateral > amount);
        return _collateralManagerApproval[_owner][_operator];
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public override {
        safeTransferFrom(_from, _to, _tokenId, "");
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory data
    ) public override {
        require(_isApprovedOrOwner(msg.sender, _from, _to, _tokenId));
        _safeTransfer(_from, _to, _tokenId, data);
    }

    function calculateFee(uint256 amount) external pure returns (uint256) {
        //100 basis points = 1 pct
        return (amount.div(10000)).mul(100);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public override isOwner(_from, _tokenId) noZeroAddress(_to) {
        address owner = loanToId[_tokenId];
        require(_to != owner);
        require(
            msg.sender == _from ||
                approvedFor(msg.sender, _tokenId) ||
                this.isApprovedForAll(owner, msg.sender)
        );
        require(_tokenId < loans.length, "Token ID not VALID");
        _transfer(_from, _to, _tokenId);
    }

    function approvedFor(address claimant, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        return approvedLoan[tokenId] == claimant;
    }

    //Front End function in which Collateral Manager: approves, appraises, and documents asset
    function _setApprovalForAll(address _operator, bool _approved) internal {
        _collateralManagerApproval[msg.sender][_operator] = _approved;
    }

    //Assets must be in warehouse
    function _checkERC721Support(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) internal returns (bool) {
        if (!_isContract(_to)) {
            return true;
        }
        bytes4 returnData = IERC721Receiver(_to).onERC721Received(
            msg.sender,
            _from,
            _tokenId,
            _data
        );
        return returnData == MAGIC_ERC721_RECEIVED;
    }

    function _isContract(address _to) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_to)
        }
        return size > 0;
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal override {
        balances[_to].add(1);
        _to = loanToId[_tokenId];
        if (_from != address(0)) {
            balances[_from].sub(1);
            delete approvedLoan[_tokenId];
        }
        emit Transfer(_from, _to, _tokenId);
    }

    function _approve(address _approved, uint256 _tokenId) internal override {
        approvedLoan[_tokenId] = _approved;
    }

    function _isApprovedOrOwner(
        address spender,
        address _from,
        address _to,
        uint256 _tokenId
    ) private view returns (bool) {
        require(_tokenId < loans.length);
        require(_to != address(0));
        address owner = loanToId[_tokenId];
        require(_to != owner);
        //Error at approve(spender, _tokenId)
        return (spender == _from ||
            approvedFor(spender, _tokenId) ||
            this.isApprovedForAll(owner, spender));
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal override {
        _transfer(from, to, tokenId);
        require(_checkERC721Support(from, to, tokenId, _data));
    }

    function _createLoan(
        uint256 id,
        uint256 duration,
        uint256 amount,
        string memory details
    ) internal {
        Loan memory _loan = Loan(id, duration, amount, details);
        loans.push(_loan);
        newLoanId.add(1);
        emit LoanCreated(id, duration, amount, details);
    }

    modifier noZeroAddress(address _addr) {
        require(_addr != address(0), "Cannot use zero address");
        _;
    }

    modifier isOwner(address _claimant, uint256 _tokenId) {
        require(
            loanToId[_tokenId] == _claimant,
            "Can only be called by claimant of loan"
        );
        _;
    }

    modifier activeLoan() {
        require(state == LoanState.START, "Loan must be active");
        _;
    }
}
