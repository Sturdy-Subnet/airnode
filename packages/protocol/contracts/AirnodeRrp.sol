// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./RequestUtils.sol";
import "./WithdrawalUtils.sol";
import "./interfaces/IAirnodeRrp.sol";
import "./authorizers/interfaces/IRrpAuthorizerNew.sol";

/// @title Contract that implements the Airnode request–response protocol
/// @dev The main functionality is implemented in RequestUtils, this contract
/// implements some additional convenience functions
contract AirnodeRrp is RequestUtils, WithdrawalUtils, IAirnodeRrp {
    struct Announcement {
        string xpub;
        address[] authorizers;
    }

    mapping(address => Announcement) private airnodeToAnnouncement;

    /// @notice Called by the Airnode operator to set announcement
    /// @dev It is expected for the Airnode operator to call this function with
    /// the respective Airnode's default BIP 44 wallet (m/44'/60'/0'/0/0).
    /// This announcement does not need to be made for the protocol to be used,
    /// it is mainly for convenience.
    /// @param xpub Extended public key of the Airnode
    /// @param authorizers Authorizer contract addresses that Airnode uses
    function setAirnodeAnnouncement(
        string calldata xpub,
        address[] calldata authorizers
    ) external override {
        airnodeToAnnouncement[msg.sender] = Announcement({
            xpub: xpub,
            authorizers: authorizers
        });
        emit SetAirnodeAnnouncement(msg.sender, xpub, authorizers);
    }

    /// @notice Called to get the Airnode announcement
    /// @dev The information announced with this function is not trustless.
    /// It is up to the user to verify that the announced `xpub` is correct by
    /// checking if its default BIP 44 wallet matches the Airnode address.
    /// It is not possible to verify the correctness of `authorizers` (i.e.,
    /// that the Airnode will use these contracts to check for authorization).
    /// @param airnode Airnode address
    /// @return xpub Extended public key of the Airnode
    /// @return authorizers Authorizer contract addresses
    function getAirnodeAnnouncement(address airnode)
        external
        view
        override
        returns (string memory xpub, address[] memory authorizers)
    {
        Announcement storage announcement = airnodeToAnnouncement[airnode];
        return (announcement.xpub, announcement.authorizers);
    }

    /// @notice A convenience method to retrieve multiple templates with a
    /// single call
    /// @param templateIds Request template IDs
    /// @return airnodes Array of Airnode addresses
    /// @return endpointIds Array of endpoint IDs
    /// @return parameters Array of request parameters
    function getTemplates(bytes32[] calldata templateIds)
        external
        view
        override
        returns (
            address[] memory airnodes,
            bytes32[] memory endpointIds,
            bytes[] memory parameters
        )
    {
        airnodes = new address[](templateIds.length);
        endpointIds = new bytes32[](templateIds.length);
        parameters = new bytes[](templateIds.length);
        for (uint256 ind = 0; ind < templateIds.length; ind++) {
            Template storage template = templates[templateIds[ind]];
            airnodes[ind] = template.airnode;
            endpointIds[ind] = template.endpointId;
            parameters[ind] = template.parameters;
        }
    }

    /// @notice Uses the authorizer contracts of an Airnode to decide if a
    /// request is authorized. Once an Airnode receives a request, it calls
    /// this method to determine if it should respond. Similarly, third parties
    /// can use this method to determine if a particular request would be
    /// authorized.
    /// @dev This method is meant to be called off-chain by the Airnode to
    /// decide if it should respond to a request. The requester can also call
    /// it, yet this function returning true should not be taken as a guarantee
    /// of the subsequent request being fulfilled.
    /// It is enough for only one of the authorizer contracts to return true
    /// for the request to be authorized.
    /// @param authorizers Authorizer contract addresses
    /// @param airnode Airnode address
    /// @param requestId Request ID
    /// @param endpointId Endpoint ID
    /// @param sponsor Sponsor address
    /// @param requester Requester address
    /// @return status Authorization status of the request
    function checkAuthorizationStatus(
        address[] calldata authorizers,
        address airnode,
        bytes32 requestId,
        bytes32 endpointId,
        address sponsor,
        address requester
    ) public view override returns (bool status) {
        for (uint256 ind = 0; ind < authorizers.length; ind++) {
            IRrpAuthorizerNew authorizer = IRrpAuthorizerNew(authorizers[ind]);
            if (
                authorizer.isAuthorized(
                    requestId,
                    airnode,
                    endpointId,
                    sponsor,
                    requester
                )
            ) {
                return true;
            }
        }
        return false;
    }

    /// @notice A convenience function to make multiple authorization status
    /// checks with a single call
    /// @param airnode Airnode address
    /// @param requestIds Request IDs
    /// @param endpointIds Endpoint IDs
    /// @param sponsors Sponsor addresses
    /// @param requesters Requester addresses
    /// @return statuses Authorization statuses of the request
    function checkAuthorizationStatuses(
        address[] calldata authorizers,
        address airnode,
        bytes32[] calldata requestIds,
        bytes32[] calldata endpointIds,
        address[] calldata sponsors,
        address[] calldata requesters
    ) external view override returns (bool[] memory statuses) {
        require(
            requestIds.length == endpointIds.length &&
                requestIds.length == sponsors.length &&
                requestIds.length == requesters.length,
            "Unequal parameter lengths"
        );
        statuses = new bool[](requestIds.length);
        for (uint256 ind = 0; ind < requestIds.length; ind++) {
            statuses[ind] = checkAuthorizationStatus(
                authorizers,
                airnode,
                requestIds[ind],
                endpointIds[ind],
                sponsors[ind],
                requesters[ind]
            );
        }
    }
}
