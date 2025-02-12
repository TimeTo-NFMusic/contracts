// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb

import { ERC1155Burnable } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import { ERC721Burnable } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

import "../../eip/interface/IERC1155.sol";
import "../../eip/interface/IERC721.sol";

import "../../extension/interface/IBurnToClaim.sol";

library BurnToClaimStorage {
    bytes32 public constant BURN_TO_CLAIM_STORAGE_POSITION = keccak256("burn.to.claim.storage");

    struct Data {
        IBurnToClaim.BurnToClaimInfo burnToClaimInfo;
    }

    function burnToClaimStorage() internal pure returns (Data storage burnToClaimData) {
        bytes32 position = BURN_TO_CLAIM_STORAGE_POSITION;
        assembly {
            burnToClaimData.slot := position
        }
    }
}

abstract contract BurnToClaim is IBurnToClaim {
    function getBurnToClaimInfo() public view returns (BurnToClaimInfo memory) {
        BurnToClaimStorage.Data storage data = BurnToClaimStorage.burnToClaimStorage();

        return data.burnToClaimInfo;
    }

    function setBurnToClaimInfo(BurnToClaimInfo calldata _burnToClaimInfo) external virtual {
        require(_canSetBurnToClaim(), "Not authorized.");

        BurnToClaimStorage.Data storage data = BurnToClaimStorage.burnToClaimStorage();
        data.burnToClaimInfo = _burnToClaimInfo;
    }

    function verifyBurnToClaim(
        address _tokenOwner,
        uint256 _tokenId,
        uint256 _quantity
    ) public view virtual {
        BurnToClaimInfo memory _burnToClaimInfo = getBurnToClaimInfo();
        require(_burnToClaimInfo.originContractAddress != address(0), "Origin contract not set.");

        if (_burnToClaimInfo.tokenType == IBurnToClaim.TokenType.ERC721) {
            require(_quantity == 1, "Invalid amount");
            require(IERC721(_burnToClaimInfo.originContractAddress).ownerOf(_tokenId) == _tokenOwner, "!Owner");
        } else if (_burnToClaimInfo.tokenType == IBurnToClaim.TokenType.ERC1155) {
            uint256 _eligible1155TokenId = _burnToClaimInfo.tokenId;

            require(_tokenId == _eligible1155TokenId, "Invalid token Id");
            require(
                IERC1155(_burnToClaimInfo.originContractAddress).balanceOf(_tokenOwner, _tokenId) >= _quantity,
                "!Balance"
            );
        }
    }

    function _burnTokensOnOrigin(
        address _tokenOwner,
        uint256 _tokenId,
        uint256 _quantity
    ) internal virtual {
        BurnToClaimInfo memory _burnToClaimInfo = getBurnToClaimInfo();

        if (_burnToClaimInfo.tokenType == IBurnToClaim.TokenType.ERC721) {
            ERC721Burnable(_burnToClaimInfo.originContractAddress).burn(_tokenId);
        } else if (_burnToClaimInfo.tokenType == IBurnToClaim.TokenType.ERC1155) {
            ERC1155Burnable(_burnToClaimInfo.originContractAddress).burn(_tokenOwner, _tokenId, _quantity);
        }
    }

    function _canSetBurnToClaim() internal view virtual returns (bool);
}
