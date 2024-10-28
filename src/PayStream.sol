// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IHooks } from "./interfaces/IHooks.sol";
import { IPayStreams } from "./interfaces/IPayStreams.sol";

contract PayStreams is Ownable, IPayStreams {
    using SafeERC20 for IERC20;

    uint16 private constant BASIS_POINTS = 10_000;

    /**
     * @dev The fee applied on streams in basis points.
     */
    uint16 private s_feeInBasisPoints;
    /**
     * @dev Only supported tokens can be streamed. PYUSD should be supported for the PYUSD hackathon.
     */
    mapping(address token => bool isSupported) private s_supportedTokens;
    /**
     * @dev Any fees collected from streaming is stored in the contract and tracked by this mapping.
     */
    mapping(address token => uint256 collectedFees) private s_collectedFees;

    /**
     * @dev Stores stream details.
     */
    mapping(bytes32 streamHash => StreamData streamData) private s_streamData;
    /**
     * @dev Stores the hook configuration for the streamer and the recipient.
     */
    mapping(address user => mapping(bytes32 streamHash => HookConfig hookConfig)) private s_hookConfig;
    /**
     * @dev Utility storage for the streamer's stream hashes.
     */
    mapping(address streamer => bytes32[] streamHashes) private s_streamerToStreamHashes;
    /**
     * @dev Utility storage for the recipient's stream hashes.
     */
    mapping(address recipient => bytes32[] streamHashes) private s_recipientToStreamHashes;

    /**
     * @notice Initializes the owner and the fee value in basis points.
     * @param _feeInBasisPoints The fee value in basis points.
     */
    constructor(uint16 _feeInBasisPoints) Ownable(msg.sender) {
        if (_feeInBasisPoints > BASIS_POINTS) revert PayStreams__InvalidFeeInBasisPoints(_feeInBasisPoints);
        s_feeInBasisPoints = _feeInBasisPoints;
    }

    /**
     * @notice Allows the owner to set the fee for streaming in basis points.
     * @param _feeInBasisPoints The fee value in basis points.
     */
    function setFeeInBasisPoints(uint16 _feeInBasisPoints) external onlyOwner {
        if (_feeInBasisPoints > BASIS_POINTS) revert PayStreams__InvalidFeeInBasisPoints(_feeInBasisPoints);
        s_feeInBasisPoints = _feeInBasisPoints;

        emit FeeInBasisPointsSet(_feeInBasisPoints);
    }

    /**
     * @notice Allows the owner to withdraw any collected fees.
     * @param _token The address of the token.
     * @param _amount The amount of collected fees to withdraw.
     */
    function collectFees(address _token, uint256 _amount) external onlyOwner {
        if (!s_supportedTokens[_token]) revert PayStreams__UnsupportedToken(_token);
        if (s_collectedFees[_token] < _amount) revert PayStreams__InsufficientCollectedFees();

        s_collectedFees[_token] -= _amount;
        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit FeesCollected(_token, _amount);
    }

    /**
     * @notice Allows the owner to support or revoke support from tokens for streaming.
     * @param _token The address of the token.
     * @param _support A boolean indicating whether to support the token or revoke
     * support from the token.
     */
    function setToken(address _token, bool _support) external onlyOwner {
        if (_token == address(0)) revert PayStreams__AddressZero();

        if (_support) {
            s_supportedTokens[_token] = true;
        } else {
            s_supportedTokens[_token] = false;
        }

        emit TokenSet(_token, _support);
    }

    /**
     * @notice Allows anyone to create a stream with custom params and hook configuration.
     * @param _streamData The stream details.
     * @param _streamerHookConfig The streamer's hook configuration.
     * @param _tag Salt for stream creation. This will allow to create multiple streams for different
     * purposes targeted towards the same recipient and the same token.
     * @return The hash of the newly created stream.
     */
    function setStream(
        StreamData calldata _streamData,
        HookConfig calldata _streamerHookConfig,
        string memory _tag
    )
        external
        returns (bytes32)
    {
        if (
            _streamData.streamer != msg.sender || _streamData.recipient == address(0)
                || _streamData.recipientVault != address(0) || !s_supportedTokens[_streamData.token]
                || _streamData.amount == 0 || _streamData.startingTimestamp < block.timestamp || _streamData.duration == 0
                || _streamData.totalStreamed != 0
        ) revert PayStreams__InvalidStreamConfig();

        bytes32 streamHash = getStreamHash(msg.sender, _streamData.recipient, _streamData.token, _tag);
        if (s_streamData[streamHash].streamer != address(0)) revert PayStreams__StreamAlreadyExists(streamHash);
        s_streamData[streamHash] = _streamData;
        s_streamerToStreamHashes[msg.sender].push(streamHash);
        s_streamerToStreamHashes[_streamData.recipient].push(streamHash);
        s_hookConfig[msg.sender][streamHash] = _streamerHookConfig;

        if (_streamData.streamerVault != address(0) && _streamerHookConfig.callAfterStreamCreated) {
            IHooks(_streamData.streamerVault).afterStreamCreated(streamHash);
        }

        emit StreamCreated(streamHash);

        return streamHash;
    }

    /**
     * @notice Allows the streamer or recipient of a stream to set their vaults.
     * @dev Hooks can only be called on correctly configured and set vaults (both on streamer's
     * and recipient's end).
     * @param _streamHash The hash of the stream.
     * @param _vault The streamer's or recipient's vault address.
     */
    function setVaultForStream(bytes32 _streamHash, address _vault) external {
        StreamData memory streamData = s_streamData[_streamHash];
        if (msg.sender != streamData.streamer && msg.sender != streamData.recipient) revert PayStreams__Unauthorized();

        msg.sender == streamData.streamer
            ? s_streamData[_streamHash].streamerVault = _vault
            : s_streamData[_streamHash].recipientVault = _vault;

        emit VaultSet(msg.sender, _streamHash, _vault);
    }

    /**
     * @notice Allows streamers and recipients to set their hook configuration.
     * @param _streamHash The hash of the stream.
     * @param _hookConfig The streamer's or recipient's hook configuration.
     */
    function setHookConfigForStream(bytes32 _streamHash, HookConfig calldata _hookConfig) external {
        StreamData memory streamData = s_streamData[_streamHash];
        if (msg.sender != streamData.streamer && msg.sender != streamData.recipient) revert PayStreams__Unauthorized();

        s_hookConfig[msg.sender][_streamHash] = _hookConfig;

        emit HookConfigSet(msg.sender, _streamHash);
    }

    /**
     * @notice Allows the recipient to collect funds from a stream.
     * @param _streamHash The hash of the stream.
     */
    function collectFundsFromStream(bytes32 _streamHash) external {
        StreamData memory streamData = s_streamData[_streamHash];

        if (streamData.startingTimestamp > block.timestamp) {
            revert PayStreams__StreamHasNotStartedYet(_streamHash, streamData.startingTimestamp);
        }

        uint256 amountToCollect = (
            streamData.amount * (block.timestamp - streamData.startingTimestamp) / streamData.duration
        ) - streamData.totalStreamed;
        if (amountToCollect == 0) revert PayStreams__ZeroAmountToCollect();
        if (amountToCollect > streamData.amount && !streamData.recurring) {
            amountToCollect = streamData.amount - streamData.totalStreamed;
        }
        uint256 feeAmount = (amountToCollect * s_feeInBasisPoints) / BASIS_POINTS;

        s_streamData[_streamHash].totalStreamed += amountToCollect;

        HookConfig memory streamerHookConfig = s_hookConfig[streamData.streamer][_streamHash];
        HookConfig memory recipientHookConfig = s_hookConfig[streamData.recipient][_streamHash];

        if (streamData.streamerVault != address(0) && streamerHookConfig.callBeforeFundsCollected) {
            IHooks(streamData.streamerVault).beforeFundsCollected(_streamHash, amountToCollect, feeAmount);
        }
        if (streamData.recipientVault != address(0) && recipientHookConfig.callBeforeFundsCollected) {
            IHooks(streamData.streamerVault).beforeFundsCollected(_streamHash, amountToCollect, feeAmount);
        }

        s_collectedFees[streamData.token] += feeAmount;
        if (streamData.streamerVault != address(0)) {
            streamData.recipientVault != address(0)
                ? IERC20(streamData.token).safeTransferFrom(
                    streamData.streamerVault, streamData.recipientVault, amountToCollect - feeAmount
                )
                : IERC20(streamData.token).safeTransferFrom(
                    streamData.streamerVault, streamData.recipient, amountToCollect - feeAmount
                );

            IERC20(streamData.token).safeTransferFrom(streamData.streamerVault, address(this), feeAmount);
        } else {
            streamData.recipientVault != address(0)
                ? IERC20(streamData.token).safeTransferFrom(
                    streamData.streamer, streamData.recipientVault, amountToCollect - feeAmount
                )
                : IERC20(streamData.token).safeTransferFrom(
                    streamData.streamer, streamData.recipient, amountToCollect - feeAmount
                );

            IERC20(streamData.token).safeTransferFrom(streamData.streamer, address(this), feeAmount);
        }

        if (streamData.streamerVault != address(0) && streamerHookConfig.callAfterFundsCollected) {
            IHooks(streamData.streamerVault).afterFundsCollected(_streamHash, amountToCollect, feeAmount);
        }
        if (streamData.recipientVault != address(0) && recipientHookConfig.callAfterFundsCollected) {
            IHooks(streamData.streamerVault).afterFundsCollected(_streamHash, amountToCollect, feeAmount);
        }

        emit FundsCollectedFromStream(_streamHash, amountToCollect);
    }

    /**
     * @notice Allows the creator of a stream to update the stream parameters.
     * @param _streamHash The hash of the stream.
     * @param _amount The new amount to stream.
     * @param _startingTimestamp The new starting timestamp.
     * @param _duration The new stream duration.
     * @param _recurring Update stream to be recurring or not.
     */
    function updateStream(
        bytes32 _streamHash,
        uint256 _amount,
        uint256 _startingTimestamp,
        uint256 _duration,
        bool _recurring
    )
        external
    {
        StreamData memory streamData = s_streamData[_streamHash];
        if (msg.sender != streamData.streamer) revert PayStreams__Unauthorized();

        HookConfig memory streamerHookConfig = s_hookConfig[streamData.streamer][_streamHash];
        HookConfig memory recipientHookConfig = s_hookConfig[streamData.recipient][_streamHash];

        if (streamData.streamerVault != address(0) && streamerHookConfig.callBeforeFundsCollected) {
            IHooks(streamData.streamerVault).beforeStreamUpdated(_streamHash);
        }

        s_streamData[_streamHash].amount = _amount;
        s_streamData[_streamHash].startingTimestamp = _startingTimestamp;
        s_streamData[_streamHash].duration = _duration;
        s_streamData[_streamHash].recurring = _recurring;

        if (streamData.streamerVault != address(0) && streamerHookConfig.callAfterStreamClosed) {
            IHooks(streamData.streamerVault).afterStreamUpdated(_streamHash);
        }
        if (streamData.recipientVault != address(0) && recipientHookConfig.callAfterStreamClosed) {
            IHooks(streamData.recipientVault).afterStreamUpdated(_streamHash);
        }

        emit StreamUpdated(_streamHash, _amount, _startingTimestamp, _duration, _recurring);
    }

    /**
     * @notice Allows the creator of a stream to cancel the stream.
     * @param _streamHash The hash of the stream.
     */
    function cancelStream(bytes32 _streamHash) external {
        StreamData memory streamData = s_streamData[_streamHash];
        if (msg.sender != streamData.streamer) revert PayStreams__Unauthorized();

        HookConfig memory streamerHookConfig = s_hookConfig[streamData.streamer][_streamHash];
        HookConfig memory recipientHookConfig = s_hookConfig[streamData.recipient][_streamHash];

        if (streamData.streamerVault != address(0) && streamerHookConfig.callBeforeStreamClosed) {
            IHooks(streamData.streamerVault).beforeStreamClosed(_streamHash);
        }

        delete s_streamData[_streamHash];

        if (streamData.streamerVault != address(0) && streamerHookConfig.callAfterStreamClosed) {
            IHooks(streamData.streamerVault).afterStreamClosed(_streamHash);
        }
        if (streamData.recipientVault != address(0) && recipientHookConfig.callAfterStreamClosed) {
            IHooks(streamData.recipientVault).afterStreamClosed(_streamHash);
        }

        emit StreamCancelled(_streamHash);
    }

    /**
     * @notice Gets the fee value for streaming in basis points.
     * @return The fee value for streaming in basis points.
     */
    function getFeeInBasisPoints() external view returns (uint16) {
        return s_feeInBasisPoints;
    }

    /**
     * @notice Checks if the given token is supported for streaming or not.
     * @param _token The address of the token.
     * @return A boolean indicating whether the token is supported or not.
     */
    function isSupportedToken(address _token) external view returns (bool) {
        return s_supportedTokens[_token];
    }

    /**
     * @notice Gets the total amount collected in fees for a given token.
     * @param _token The address of the token.
     * @return The amount of token collected in fees.
     */
    function getCollectedFees(address _token) external view returns (uint256) {
        return s_collectedFees[_token];
    }

    /**
     * @notice Gets the details for a given stream.
     * @param _streamHash The hash of the stream.
     * @return The stream details.
     */
    function getStreamData(bytes32 _streamHash) external view returns (StreamData memory) {
        return s_streamData[_streamHash];
    }

    /**
     * @notice Gets the hook configuration for a given user and a given stream hash.
     * @param _user The user's address.
     * @param _streamHash The hash of the stream.
     * @return The hook configuration details.
     */
    function getHookConfig(address _user, bytes32 _streamHash) external view returns (HookConfig memory) {
        return s_hookConfig[_user][_streamHash];
    }

    /**
     * @notice Gets the hashes of the streams created by a user.
     * @param _streamer The stream creator's address.
     * @return An array of stream hashes.
     */
    function getStreamerStreamHashes(address _streamer) external view returns (bytes32[] memory) {
        return s_streamerToStreamHashes[_streamer];
    }

    /**
     * @notice Gets the hashes of the streams the user is a recipient of.
     * @param _recipient The stream recipient's address.
     * @return An array of stream hashes.
     */
    function getRecipientStreamHashes(address _recipient) external view returns (bytes32[] memory) {
        return s_recipientToStreamHashes[_recipient];
    }

    /**
     * @notice Computes the hash of a stream from the streamer, recipient, token addresses and a string tag.
     * @param _streamer The address of the stream creator.
     * @param _recipient The address of the stream recipient.
     * @param _token The address of the token.
     * @param _tag Salt for stream creation.
     * @return The hash of the stream.
     */
    function getStreamHash(
        address _streamer,
        address _recipient,
        address _token,
        string memory _tag
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_streamer, _recipient, _token, _tag));
    }
}