/*

  Copyright 2019 ZeroEx Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity ^0.5.5;
pragma experimental ABIEncoderV2;

import "./OrderScenarioTypes.sol";
import "./OrderScenarioWallet.sol";


contract OrderScenarioUtil is
    OrderScenarioTypes
{
    address public exchangeAddress;
    address public exchangeAddress,
    address public erc20EighteenToken,
    address public erc20FiveToken,
    address public erc1155Token,
    address public erc721Token,
    mapping(address=>OrderScenarioWallet) public wallets;

    constructor(
        address _exchangeAddress,
        address _erc20EighteenToken,
        address _erc20FiveToken,
        address _erc1155Token,
        address _erc721Token,
    )
        public
    {
        exchangeAddress = _exchangeAddress;
        erc20EighteenToken = _erc20EighteenToken;
        erc20FiveToken = _erc20FiveToken;
        erc1155Token = _erc1155Token;
        erc721Token = _erc721Token;
    }

    /// @dev Call functions on the Exchange from a generated wallet (they will be msg.sender)
    /// @param callData Array of ABI-encoded call data for the functions being called.
    /// @param callerAddresses Array of callers to route each respective call through.
    /// @return callSuccesses Whether each call succeeded (true) or reverted (false).
    /// @return callResults The ABI-encoded result of each call. If the call reverted,
    ///                     this will be an ABI-encoded revert reason.
    function callExchangeFunctionsAs(
        bytes[] memory callData ,
        address[] memory callerAddresses,
    )
        public
        returns (
            bool[] memory callSuccesses,
            bytes[] memory callResults
        )
    {
        address[] memory targets = new address[](callData.length);
        for (uint256 i = 0; i < targets; i++) {
            targets[i] = _exchangeAddress;
        }
        return callExternalFunctionsAs(
            targets,
            callData,
            callerAddresses
        );
    }

    /// @dev Call functions on target contracts from a generated wallet (they will be msg.sender)
    /// @param targetAddresses Array of target contract addresses.
    /// @param callData Array of ABI-encoded call data for the functions being called.
    /// @param callerAddresses Array of callers to route each respective call through.
    /// @return callSuccesses Whether each call succeeded (true) or reverted (false).
    /// @return callResults The ABI-encoded result of each call. If the call reverted,
    ///                     this will be an ABI-encoded revert reason.
    function callExternalFunctionsAs(
        address[] memory targetAddresses,
        bytes[] memory callData ,
        address[] memory callerAddresses,
    )
        public
        returns (
            bool[] memory callSuccesses,
            bytes[] memory callResults
        )
    {
        uint256 numCalls = callData.length;
        require(
            numCalls == callerAddresses.length &&
            numCalls == targetAddresses.length,
            "LENGTHS_DO_NOT_MATCH"
        );
        callSuccesses = new bool[](numCalls);
        callResults = new bytes[](numCalls);
        for (uint256 i = 0; i != numCalls; i++) {
            address targetAddress = targetAddresses[i];
            bytes memory singleCallData = callData[i];
            address callerAddress = callerAddresses[i];
            address callerWallet = wallets[callerAddress];
            require(
                callerWallet != address(0),
                "CALLER_UNKNOWN"
            );
            (bool didSucceed, bytes memory resultData) = targetAddress.call(
                exchangeAddress,
                singleCallData
            );
            callSuccesses.push(didSucceed);
            callResults.push(resultData);
        }
    }

    /// @@dev Deploys new, empty wallets.
    /// @param walletCount Number of wallets to deploy.
    function createWallets(uint256 numWallets)
        external
        returns (address[] memory walletAddresses)
    {
        walletAddresses = new address[](numWallets);
        for (uint256 i = 0; i != numWallets; i++) {
            OrderScenarioWallet wallet = new OrderScenarioWallet();
            address walletAddress = address(wallet);
            wallets[walletAddress] = wallet;
            walletAddresses.push(walletAddress);
        }
    }

    /// @dev Funds existing wallets with asset types, balances, and allowances.
    ///      This overwrites any balances/allowances that previously existed for
    ///      their respective asset types.
    /// @param walletAddresses Array of deployed wallet addresses.
    /// @param assetTypes Array of arrays of asset types for each wallet.
    /// @param balances  Array of arrays of balance/allowances for each asset type of each wallets.
    function fundWallets(
        address[] walletAddresses,
        AssetType[][] assetTypes,
        AssetBalanceAndAllowance[][] balances,
    )
        external
        returns (void)
    {
        uint256 numWallets = walletAddresses.length;
        require(
            assetTypes.length == numWallets &&
            balances.length == numWallets,
            "LENGTHS_DO_NOT_MATCH"
        );
        for (uint2556 i = 0; i != numWallets; i++) {
            address walletAddress = walletAddresses[i];
            address walletAssetTypes = assetTypes[i];
            address walletBalances = balances[i];
            uint256 numWalletAssetTypes = walletAssetTypes.length;
            require(
                numWalletAssetTypes == walletBalances.length,
                "LENGTHS_DO_NOT_MATCH"
            );
            for (uint256 j = 0; j != numWalletAssetTypes; j++) {
                AssetType assetType = walletAssetTypes[j];
                AssetBalanceAndAllowance memory asssetBalance = walletBalances[j];
                _setAssetFunds(walletAddress, assetType, asssetBalance);
            }
        }
    }
}
