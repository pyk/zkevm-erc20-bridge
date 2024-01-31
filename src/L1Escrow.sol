// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControlDefaultAdminRulesUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol"; // forgefmt: disable-line
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PolygonERC20BridgeBaseUpgradeable} from "./PolygonERC20BridgeBaseUpgradeable.sol";

/**
 * @title L1Escrow
 * @author sepyke.eth
 * @dev This contract is what keeps the L2Token backed up on the origin chain
 */
contract L1Escrow is AccessControlDefaultAdminRulesUpgradeable, UUPSUpgradeable, PausableUpgradeable, PolygonERC20BridgeBaseUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice Escrow manager role identifier
    bytes32 public constant ESCROW_MANAGER = keccak256("ESCROW_MANAGER");

    /// @custom:storage-location erc7201:pyk.storage.L1Escrow
    struct L1EscrowStorage {
        IERC20 originTokenAddress;
        IERC20 wrappedTokenAddress;
    }

    // keccak256(abi.encode(uint256(keccak256("pyk.storage.L1Escrow")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant L1EscrowStorageLocation = 0xb08f034e529aa57dc237646cc7098c9fd93ff0d603827be450161b6fc03f2500;

    function _getL1EscrowStorage() private pure returns (L1EscrowStorage storage $) {
        assembly {
            $.slot := L1EscrowStorageLocation
        }
    }

    function originTokenAddress() public view returns (IERC20) {
        L1EscrowStorage storage $ = _getL1EscrowStorage();
        return $.originTokenAddress;
    }

    function wrappedTokenAddress() public view returns (IERC20) {
        L1EscrowStorage storage $ = _getL1EscrowStorage();
        return $.wrappedTokenAddress;
    }

    /// @notice Disable initializer on deploy
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice L1Escrow initializer
     * @param _admin The admin address
     * @param _manager The escrow manager address
     * @param _polygonZkEVMBridge Polygon ZkEVM bridge address
     * @param _counterpartContract Couterpart contract
     * @param _counterpartNetwork Couterpart network
     * @param _originTokenAddress Token address
     * @param _wrappedTokenAddress L2Token address on Polygon ZkEVM
     */
    function initialize(
        address _admin,
        address _manager,
        address _polygonZkEVMBridge,
        address _counterpartContract,
        uint32 _counterpartNetwork,
        address _originTokenAddress,
        address _wrappedTokenAddress
    ) public virtual initializer {
        // Inits
        __AccessControlDefaultAdminRules_init(3 days, _admin);
        __UUPSUpgradeable_init();
        __Pausable_init();
        __PolygonERC20BridgeBase_init(_polygonZkEVMBridge, _counterpartContract, _counterpartNetwork);
        _grantRole(ESCROW_MANAGER, _manager);

        // Set storage
        L1EscrowStorage storage $ = _getL1EscrowStorage();
        $.originTokenAddress = IERC20(_originTokenAddress);
        $.wrappedTokenAddress = IERC20(_wrappedTokenAddress);
    }

    // ****************************
    // *          Upgrade         *
    // ****************************

    /**
     * @dev Only the owner can upgrade the L1Escrow
     * @param _newVersion The contract address of a new version
     */
    function _authorizeUpgrade(address _newVersion) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // ****************************
    // *          Pause           *
    // ****************************

    /**
     * @notice Pause the L1Escrow
     * @dev Only EMERGENCY_ROLE can pause the L1Escrow
     */
    function pause() external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Resume the L1Escrow
     * @dev Only EMERGENCY_ROLE can resume the L1Escrow
     */
    function unpause() external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ****************************
    // *           Bridge         *
    // ****************************

    /**
     * @dev Handle the reception of the tokens
     * @param amount Token amount
     */
    function _receiveTokens(uint256 amount) internal virtual override whenNotPaused {
        L1EscrowStorage storage $ = _getL1EscrowStorage();
        $.originTokenAddress.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @dev Handle the transfer of the tokens
     * @param destinationAddress Address destination that will receive the tokens on the other network
     * @param amount Token amount
     */
    function _transferTokens(address destinationAddress, uint256 amount) internal virtual override whenNotPaused {
        L1EscrowStorage storage $ = _getL1EscrowStorage();
        $.originTokenAddress.safeTransfer(destinationAddress, amount);
    }
}
