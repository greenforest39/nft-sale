//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Sale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    event ItemListed(
        address indexed nft,
        uint256 indexed tokenId,
        address owner,
        uint256 price,
        uint256 startTime,
        uint256 endTime
    );

    event ItemSold(
        address indexed nft,
        uint256 indexed tokenId,
        address seller,
        address buyer,
        uint256 price,
        uint256 timestamp
    );

    /// @notice Structure for listed items
    struct Listing {
        uint256 price;
        uint256 endTime;
    }

    /// @notice NFT Address -> Token ID -> Owner -> Listing
    mapping(address => mapping(uint256 => mapping(address => Listing)))
        public listings;

    /// @notice Platform fee will be sent to dev address
    address payable public dev;

    /// @notice Platform fee
    uint256 public fee;

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;

    modifier tokenOwned(
        address _nft,
        uint256 _tokenId,
        address _owner
    ) {
        require(
            IERC721(_nft).ownerOf(_tokenId) == _owner,
            "nft not owned by user"
        );
        _;
    }

    modifier notListed(
        address _nft,
        uint256 _tokenId,
        address _owner
    ) {
        Listing memory listing = listings[_nft][_tokenId][_owner];
        require(listing.endTime == 0 && listing.endTime < block.timestamp, "already listed");
        _;
    }

    /// @notice Constructor
    /// @param _dev Dev address
    /// @param _fee Platform fee
    constructor(address payable _dev, uint256 _fee) {
        require(_dev != address(0), "invalid dev address");
        require(_fee >= 0, "fee < 0");
        require(_fee <= 1000, "fee > 1000");

        dev = _dev;
        fee = _fee;
    }

    /// @notice Method for listing NFT
    /// @param _nft NFT Contract address
    /// @param _tokenId Token ID
    /// @param _price Sale price
    /// @param _endTime Sale end time
    function listItem(
        address _nft,
        uint256 _tokenId,
        uint256 _price,
        uint256 _endTime
    )
        external
        tokenOwned(_nft, _tokenId, msg.sender)
        notListed(_nft, _tokenId, msg.sender)
    {
        require(
            IERC165(_nft).supportsInterface(INTERFACE_ID_ERC721),
            "invalid nft address"
        );
        require(_endTime > block.timestamp, "invalid end time");

        require(
            IERC721(_nft).isApprovedForAll(msg.sender, address(this)),
            "item not approved"
        );

        listings[_nft][_tokenId][msg.sender] = Listing(_price, _endTime);
        emit ItemListed(
            _nft,
            _tokenId,
            msg.sender,
            _price,
            block.timestamp,
            _endTime
        );
    }

    /// @notice Method for buying listed NFT
    /// @param _nft NFT Contract address
    /// @param _tokenId Token ID
    function buyItem(
        address _nft,
        uint256 _tokenId
    )
        external
        payable
        nonReentrant
    {
        require(
            IERC165(_nft).supportsInterface(INTERFACE_ID_ERC721),
            "invalid nft address"
        );
        IERC721 nft = IERC721(_nft);
        address payable _owner = payable(nft.ownerOf(_tokenId));
        Listing memory listing = listings[_nft][_tokenId][_owner];
        require(listing.endTime >= block.timestamp, "item not listed or listing is expired");
        require(listing.price == msg.value, "insufficient funds");

        // transfers NFT from seller to buyer
        nft.safeTransferFrom(_owner, msg.sender, _tokenId);

        // transfer fee to dev address
        uint256 feeAmount = msg.value.mul(fee).div(1e3);
        (bool success, ) = dev.call{value: feeAmount}("");
        require(success, "fee transfer failed");

        // transfer payment to seller
        (success, ) = _owner.call{value: msg.value.sub(feeAmount)}("");
        require(success, "payment transfer failed");

        emit ItemSold(
            _nft,
            _tokenId,
            _owner,
            msg.sender,
            listing.price,
            block.timestamp
        );

        delete listings[_nft][_tokenId][_owner];
    }

    /// @notice Method for updating dev address. Only dev can call this method
    /// @param _dev New dev address
    function setDev(address payable _dev) external {
        require(msg.sender == dev);
        require(_dev != address(0), "invalid dev address");

        dev = _dev;
    }

    /// @notice Method for updating platform fee. Only contract owner can call this method
    /// @param _fee New platform fee
    function setFee(uint256 _fee) external onlyOwner {
        require(_fee >= 0, "fee < 0");
        require(_fee <= 1000, "fee > 1000");

        fee = _fee;
    }
}
