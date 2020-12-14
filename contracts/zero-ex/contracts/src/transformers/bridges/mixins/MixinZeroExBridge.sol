/*

  Copyright 2020 ZeroEx Intl.

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

pragma solidity ^0.6.5;
pragma experimental ABIEncoderV2;

import "@0x/contracts-erc20/contracts/src/v06/LibERC20TokenV06.sol";
import "@0x/contracts-erc20/contracts/src/v06/IERC20TokenV06.sol";
import "@0x/contracts-utils/contracts/src/v06/LibSafeMathV06.sol";
import "../IBridgeAdapter.sol";
import "../../../vendor/ILiquidityProvider.sol";
import "../../../vendor/v3/IERC20Bridge.sol";


contract MixinZeroExBridge {

    using LibERC20TokenV06 for IERC20TokenV06;
    using LibSafeMathV06 for uint256;

    /// @dev Emitted when a trade occurs.
    /// @param inputToken The token the bridge is converting from.
    /// @param outputToken The token the bridge is converting to.
    /// @param inputTokenAmount Amount of input token.
    /// @param outputTokenAmount Amount of output token.
    /// @param source The bridge source ID, indicating the underlying source of the fill.
    /// @param to The `to` address, currrently `address(this)`
    event ERC20BridgeTransfer(
        IERC20TokenV06 inputToken,
        IERC20TokenV06 outputToken,
        uint256 inputTokenAmount,
        uint256 outputTokenAmount,
        IBridgeAdapter.BridgeSource source,
        address to
    );

    function _tradeZeroExBridge(
        IBridgeAdapter.BridgeOrder memory order,
        IERC20TokenV06 sellToken,
        IERC20TokenV06 buyToken,
        uint256 sellAmount
    )
        internal
        returns (uint256 boughtAmount)
    {
        // Trade the good old fashioned way
        sellToken.compatTransfer(
            order.sourceAddress,
            sellAmount
        );
        try ILiquidityProvider(order.sourceAddress).sellTokenForToken(
                address(sellToken),
                address(buyToken),
                address(this), // recipient
                1, // minBuyAmount
                order.bridgeData
        ) returns (uint256 _boughtAmount) {
            boughtAmount = _boughtAmount;
            emit ERC20BridgeTransfer(
                sellToken,
                buyToken,
                sellAmount,
                boughtAmount,
                order.source,
                address(this)
            );
        } catch {
            uint256 balanceBefore = buyToken.balanceOf(address(this));
            IERC20Bridge(order.sourceAddress).bridgeTransferFrom(
                address(buyToken),
                order.sourceAddress,
                address(this), // recipient
                1, // minBuyAmount
                order.bridgeData
            );
            boughtAmount = buyToken.balanceOf(address(this)).safeSub(balanceBefore);
        }
    }
}
