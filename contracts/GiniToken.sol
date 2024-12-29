// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title GiniToken
 * @dev A contract representing the GiniToken ERC20 token with access control.
 *
 * The contract is created with the following parameters:
 * - The name of the token is "Gini".
 * - The symbol of the token is "GINI".
 * - The total supply of the token is 2,000,000,000 GINI.
 * - The total supply for the public sale is 300,000,000 GINI.
 */
contract GiniToken is ERC20, AccessControl {
    // _______________ Storage _______________

    /**
     * @notice Stores `true` for addresses for which all token transfers are denied.
     *
     * An address => is denied for all token transfers?
     */
    mapping(address => bool) public denylist;

    // _______________ Constants _______________

    /// @notice The total supply for the Free Token.

    /// @notice The total supply of the token.
    uint256 public constant TOTAL_SUPPLY = 2_000_000_000 * 1e18;

    // _______________ Errors _______________
    /**
     * @notice Reverted when public sale or vesting contract addresses are zero during contract creation.
     */
    error ZeroAddress();

    /**
     * @notice Reverted when token transfer from or to a denied address.
     *
     * It provides the value:
     * @param _addr The denied address, from or to which a token transfer is attempted.
     */
    error DeniedAddress(address _addr);

    /**
     * @notice Reverted when re-denying a denied address.
     *
     * It provides the value:
     * @param _addr The denied address attempted to be denied again.
     */
    error AlreadyDenied(address _addr);

    /**
     * @notice Reverted when allowing an address that is not denied.
     *
     * It provides the value:
     * @param _addr The address that is not denied, but has been attempted to be allowed.
     */
    error NotDenied(address _addr);

    // _______________ Events _______________

    /**
     * @notice Emitted when all token transfers are denied for an address `_addr`.
     *
     * @param _addr The address for which all token transfers are denied.
     */
    event Denied(address indexed _addr);

    /**
     * @notice Emitted when token transfers are allowed for a denied address `_addr`.
     *
     * @param _addr The address for which token transfers are allowed.
     */
    event Allowed(address indexed _addr);

    /**
     *
     * @param _bridgeContractAddress The address of the public sale contract
     */
    constructor(address _bridgeContractAddress) ERC20("Gini", "GINI") {
        if (_bridgeContractAddress == address(0)) {
            revert ZeroAddress();
        }
        
        _mint(_bridgeContractAddress, TOTAL_SUPPLY);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // _______________ External functions _______________

    /**
     * @notice Denies all token transfers for an address `_addr`.
     *
     * Emits a `Denied` event.
     *
     * Requirements:
     * - The caller should have the role `DENIER_ROLE`.
     * - The address `_addr` should not be denied.
     *
     * @param _addr An address to be denied.
     */
    // prettier-ignore
    function deny(address _addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (denylist[_addr])
            revert AlreadyDenied(_addr);

        denylist[_addr] = true;

        emit Denied(_addr);
    }

    /**
     * @notice Allows token transfers for a denied address `_addr`.
     *
     * Emits an `Allowed` event.
     *
     * Requirements:
     * - The caller should have the role `DENIER_ROLE`.
     * - The address `_addr` should be denied.
     *
     * @param _addr A denied address to be allowed.
     */
    // prettier-ignore
    function allow(address _addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!denylist[_addr])
            revert NotDenied(_addr);

        denylist[_addr] = false;

        emit Allowed(_addr);
    }

    // _______________ Internal functions _______________

    /**
     * @notice Hook that is called before any transfer of tokens.
     *
     * It is overridden to be extended with the following requirements:
     * - `_from` should not be denied (`denylist`).
     * - `_to` should not be denied (`denylist`).
     *
     * It also includes the condition of `Pauseable`:
     * - The contract should not be paused.
     *
     * @param from An address from which tokens are transferred. Only in the first transaction, it is zero address,
     * when the total supply is minted to the owner address during contract creation.
     * @param to An address to which tokens are transferred.
     * @param value Amount of tokens to be transferred.
     *
     * @notice See `Pauseable` and `ERC20` for details.
     */
    function _update(address from, address to, uint256 value) internal override(ERC20) {
        if (denylist[from]) revert DeniedAddress(from);
        if (denylist[to]) revert DeniedAddress(to);

        super._update(from, to, value);
    }
}
