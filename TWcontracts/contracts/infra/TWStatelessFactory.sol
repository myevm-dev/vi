// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;


import "../extension/interface/IContractFactory.sol";

import "../external-deps/openzeppelin/metatx/ERC2771Context.sol";
import "../extension/Multicall.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract TWStatelessFactory is Multicall, ERC2771Context, IContractFactory {
    /// @dev Emitted when a proxy is deployed.
    event ProxyDeployed(address indexed implementation, address proxy, address indexed deployer);

    constructor(address[] memory _trustedForwarders) ERC2771Context(_trustedForwarders) {}

    /// @dev Deploys a proxy that points to the given implementation.
    function deployProxyByImplementation(
        address _implementation,
        bytes memory _data,
        bytes32 _salt
    ) public override returns (address deployedProxy) {
        bytes32 salthash = keccak256(abi.encodePacked(_msgSender(), _salt));
        deployedProxy = Clones.cloneDeterministic(_implementation, salthash);

        emit ProxyDeployed(_implementation, deployedProxy, _msgSender());

        if (_data.length > 0) {
            // slither-disable-next-line unused-return
            Address.functionCall(deployedProxy, _data);
        }
    }

    function _msgSender() internal view virtual override(Multicall, ERC2771Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }
}
