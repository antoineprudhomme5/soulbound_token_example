// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface IERC5192 {
    /// @notice Emitted when the locking status is changed to locked.
    /// @dev If a token is minted and the status is locked, this event should be emitted.
    /// @param tokenId The identifier for a token.
    event Locked(uint256 tokenId);

    /// @notice Emitted when the locking status is changed to unlocked.
    /// @dev If a token is minted and the status is unlocked, this event should be emitted.
    /// @param tokenId The identifier for a token.
    event Unlocked(uint256 tokenId);

    /// @notice Returns the locking status of an Soulbound Token
    /// @dev SBTs assigned to zero address are considered invalid, and queries
    /// about them do throw.
    /// @param tokenId The identifier for an SBT.
    function locked(uint256 tokenId) external view returns (bool);
}

interface IERC5484 {
    /// A guideline to standardlize burn-authorization's number coding
    enum BurnAuth {
        IssuerOnly,
        OwnerOnly,
        Both,
        Neither
    }

    /// @notice Emitted when a soulbound token is issued.
    /// @dev This emit is an add-on to nft's transfer emit in order to distinguish sbt
    /// from vanilla nft while providing backward compatibility.
    /// @param from The issuer
    /// @param to The receiver
    /// @param tokenId The id of the issued token
    event Issued(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        BurnAuth burnAuth
    );

    /// @notice provides burn authorization of the token id.
    /// @dev unassigned tokenIds are invalid, and queries do throw
    /// @param tokenId The identifier for a token.
    function burnAuth(uint256 tokenId) external view returns (BurnAuth);
}

abstract contract SouldBoundToken is ERC721, IERC5192, IERC5484 {
    bool private isLocked;
    mapping(uint256 => bool) private _isLocked;
    mapping(uint256 => BurnAuth) private _burnAuth;
    mapping(uint256 => address) private _tokenOwners;
    mapping(uint256 => address) private _tokenIssuers;

    error ErrLocked();
    error ErrNotFound();

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {}

    function issue(
        address to,
        uint256 tokenId,
        bool isLocked,
        BurnAuth burnAuth
    ) internal {
        // check that the token id is not already used
        require(_tokenOwners[tokenId] == address(0));

        _safeMint(to, tokenId);

        // remember is the token is locked
        _isLocked[tokenId] = isLocked;
        // remember the `burnAuth` for this token
        _burnAuth[tokenId] = burnAuth;
        // remember the issuer and owner of the token
        _tokenIssuers[tokenId] = msg.sender;
        _tokenOwners[tokenId] = to;

        emit Issued(msg.sender, to, tokenId, burnAuth);
    }

    modifier checkLock() {
        if (isLocked) revert ErrLocked();
        _;
    }

    function locked(uint256 tokenId) external view returns (bool) {
        if (!_exists(tokenId)) revert ErrNotFound();
        return _isLocked[tokenId];
    }

    function burnAuth(uint256 tokenId) external view returns (BurnAuth) {
        return _burnAuth[tokenId];
    }

    function getTokenOwner(uint256 tokenId) internal view returns (address) {
        return _tokenOwners[tokenId];
    }

    function burn(uint256 tokenId) external {
        address issuer = _tokenIssuers[tokenId];
        address owner = _tokenOwners[tokenId];
        BurnAuth burnAuth = _burnAuth[tokenId];

        require(
            (burnAuth == BurnAuth.Both &&
                (msg.sender == issuer || msg.sender == owner)) ||
                (burnAuth == BurnAuth.IssuerOnly && msg.sender == issuer) ||
                (burnAuth == BurnAuth.OwnerOnly && msg.sender == owner),
            "The set burnAuth doesn't allow you to burn this token"
        );

        // Burn the token
        delete _tokenIssuers[tokenId];
        delete _tokenOwners[tokenId];
        delete _isLocked[tokenId];
        delete _burnAuth[tokenId];
        ERC721._burn(tokenId);
    }
}

contract DrivingLicenseToken is SouldBoundToken {
    constructor() SouldBoundToken("Driving License", "DRL") {}

    function issueDrivingLicense(address to, uint256 tokenId) public {
        issue(to, tokenId, true, IERC5484.BurnAuth.IssuerOnly);
    }

    function getDrivingLicenseOwner(
        uint256 tokenId
    ) public view returns (address) {
        return getTokenOwner(tokenId);
    }
}
