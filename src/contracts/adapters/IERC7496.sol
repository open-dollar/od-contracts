// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @dev IERC7496 specification outlined @ https://eips.ethereum.org/EIPS/eip-7496
 */
interface IERC7496 {
  /* Events */
  event TraitUpdated(bytes32 indexed traitKey, uint256 tokenId, bytes32 traitValue);
  event TraitUpdatedRange(bytes32 indexed traitKey, uint256 fromTokenId, uint256 toTokenId);
  event TraitUpdatedRangeUniformValue(
    bytes32 indexed traitKey, uint256 fromTokenId, uint256 toTokenId, bytes32 traitValue
  );
  event TraitUpdatedList(bytes32 indexed traitKey, uint256[] tokenIds);
  event TraitUpdatedListUniformValue(bytes32 indexed traitKey, uint256[] tokenIds, bytes32 traitValue);
  event TraitMetadataURIUpdated();

  /* Getters */
  function getTraitValue(uint256 tokenId, bytes32 traitKey) external view returns (bytes32 traitValue);
  function getTraitValues(
    uint256 tokenId,
    bytes32[] calldata traitKeys
  ) external view returns (bytes32[] memory traitValues);
  function getTraitMetadataURI() external view returns (string memory uri);

  /* Setters */
  function setTrait(uint256 tokenId, bytes32 traitKey, bytes32 newValue) external;
}
