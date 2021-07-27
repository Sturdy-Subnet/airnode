// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IConvenienceUtils {
    event SetAirnodeXpub(address indexed airnode, string xpub);

    event SetAirnodeAuthorizers(address indexed airnode, address[] authorizers);

    function setAirnodeXpub(string calldata xpub) external;

    function setAirnodeAuthorizers(address[] calldata authorizers) external;

    function getAirnodeAuthorizers(address airnode)
        external
        view
        returns (address[] memory authorizers);

    function checkAuthorizationStatus(
        address[] calldata authorizers,
        address airnode,
        bytes32 requestId,
        bytes32 endpointId,
        address sponsor,
        address requester
    ) external view returns (bool status);

    function checkAuthorizationStatuses(
        address[] calldata authorizers,
        address airnode,
        bytes32[] calldata requestIds,
        bytes32[] calldata endpointIds,
        address[] calldata sponsors,
        address[] calldata requesters
    ) external view returns (bool[] memory statuses);

    function airnodeToXpub(address airnode)
        external
        view
        returns (string memory xpub);
}
