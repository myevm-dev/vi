// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;



import "../interface/IDelayedReveal.sol";

library DelayedRevealStorage {
    /// @custom:storage-location erc7201:delayed.reveal.storage
    ///@dev keccak256(abi.encode(uint256(keccak256("delayed.reveal.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant DELAYED_REVEAL_STORAGE_POSITION =
        0x29cbb6a3768b42f407b01945994a37861bf5a2179c5dea5be7e378415e755100;

    struct Data {
        /// @dev Mapping from tokenId of a batch of tokens => to delayed reveal data.
        mapping(uint256 => bytes) encryptedData;
    }

    function data() internal pure returns (Data storage data_) {
        bytes32 position = DELAYED_REVEAL_STORAGE_POSITION;
        assembly {
            data_.slot := position
        }
    }
}

/**
 *  @title   Delayed Reveal
 *  @notice  Thirdweb's `DelayedReveal` is a contract extension for base NFT contracts. It lets you create batches of
 *           'delayed-reveal' NFTs. You can learn more about the usage of delayed reveal NFTs here - https://blog.thirdweb.com/delayed-reveal-nfts
 */

abstract contract DelayedReveal is IDelayedReveal {
    /// @dev Mapping from tokenId of a batch of tokens => to delayed reveal data.
    function encryptedData(uint256 _tokenId) public view returns (bytes memory) {
        return _delayedRevealStorage().encryptedData[_tokenId];
    }

    /// @dev Sets the delayed reveal data for a batchId.
    function _setEncryptedData(uint256 _batchId, bytes memory _encryptedData) internal {
        _delayedRevealStorage().encryptedData[_batchId] = _encryptedData;
    }

    /**
     *  @notice             Returns revealed URI for a batch of NFTs.
     *  @dev                Reveal encrypted base URI for `_batchId` with caller/admin's `_key` used for encryption.
     *                      Reverts if there's no encrypted URI for `_batchId`.
     *                      See {encryptDecrypt}.
     *
     *  @param _batchId     ID of the batch for which URI is being revealed.
     *  @param _key         Secure key used by caller/admin for encryption of baseURI.
     *
     *  @return revealedURI Decrypted base URI.
     */
    function getRevealURI(uint256 _batchId, bytes calldata _key) public view returns (string memory revealedURI) {
        bytes memory dataForBatch = _delayedRevealStorage().encryptedData[_batchId];
        if (dataForBatch.length == 0) {
            revert("Nothing to reveal");
        }

        (bytes memory encryptedURI, bytes32 provenanceHash) = abi.decode(dataForBatch, (bytes, bytes32));

        revealedURI = string(encryptDecrypt(encryptedURI, _key));

        require(keccak256(abi.encodePacked(revealedURI, _key, block.chainid)) == provenanceHash, "Incorrect key");
    }

    /**
     *  @notice         Encrypt/decrypt data on chain.
     *  @dev            Encrypt/decrypt given `data` with `key`. Uses inline assembly.
     *                  See: https://ethereum.stackexchange.com/questions/69825/decrypt-message-on-chain
     *
     *  @param data     Bytes of data to encrypt/decrypt.
     *  @param key      Secure key used by caller for encryption/decryption.
     *
     *  @return result  Output after encryption/decryption of given data.
     */
    function encryptDecrypt(bytes memory data, bytes calldata key) public pure override returns (bytes memory result) {
        // Store data length on stack for later use
        uint256 length = data.length;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Set result to free memory pointer
            result := mload(0x40)
            // Increase free memory pointer by lenght + 32
            mstore(0x40, add(add(result, length), 32))
            // Set result length
            mstore(result, length)
        }

        // Iterate over the data stepping by 32 bytes
        for (uint256 i = 0; i < length; i += 32) {
            // Generate hash of the key and offset
            bytes32 hash = keccak256(abi.encodePacked(key, i));

            bytes32 chunk;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                // Read 32-bytes data chunk
                chunk := mload(add(data, add(i, 32)))
            }
            // XOR the chunk with hash
            chunk ^= hash;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                // Write 32-byte encrypted chunk
                mstore(add(result, add(i, 32)), chunk)
            }
        }
    }

    /**
     *  @notice         Returns whether the relvant batch of NFTs is subject to a delayed reveal.
     *  @dev            Returns `true` if `_batchId`'s base URI is encrypted.
     *  @param _batchId ID of a batch of NFTs.
     */
    function isEncryptedBatch(uint256 _batchId) public view returns (bool) {
        return _delayedRevealStorage().encryptedData[_batchId].length > 0;
    }

    /// @dev Returns the DelayedReveal storage.
    function _delayedRevealStorage() internal pure returns (DelayedRevealStorage.Data storage data) {
        data = DelayedRevealStorage.data();
    }
}
