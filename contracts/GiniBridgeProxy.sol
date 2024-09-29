// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract GiniBridgeProxy is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /**
     * @notice Emitted when tokens are locked in the bridge contract to initiate a cross-chain transfer.
     * @param from The address of the sender locking the tokens.
     * @param to The address of the receiver on the destination chain, passed in string format.
     * @param amount The amount of tokens being locked.
     * @param currentChainId The chain ID of the network where tokens are being locked.
     *
     * This event signifies that the specified `amount` of tokens from the `from` address have been
     * locked in the bridge contract and are ready for cross-chain bridging to the `to` address.
     */
    event BridgeLock(address from, string to, uint256 amount, uint256 currentChainId);

    /**
     * @notice Emitted when tokens are bridged to the destination chain and are available for the beneficiary.
     * @param to The address of the receiver on the destination chain.
     * @param amount The amount of tokens being bridged to the `to` address.
     * @param currentChainId The chain ID of the network where tokens are bridged to.
     *
     * This event indicates that tokens are successfully bridged and available for withdrawal by the
     * beneficiary on the destination chain.
     */
    event HandleTokenBridging(address to, uint256 amount, uint256 currentChainId);

    /**
     * @notice Emitted when the tokens are successfully withdrawn by the beneficiary on the destination chain.
     * @param to The address of the beneficiary who withdrew the tokens.
     * @param amount The amount of tokens withdrawn by the beneficiary.
     * @param currentChainId The chain ID of the network where the withdrawal took place.
     *
     * This event indicates that the `to` address has successfully withdrawn the specified `amount` of tokens
     * after the bridging process is complete.
     */
    event WithdrawToken(address to, uint256 amount, uint256 currentChainId);

    uint256 public currentChainId;
    uint256 public totalLockedToken; 
    uint256 public allocatedLockedToken;
    address giniTokenAddress; 
    
    struct unlockedToken {
        uint256 amount;
        string status;
    }

    mapping(address => unlockedToken) public unlockedTokens;
    mapping(address => bool) public admins;

    modifier onlyAdmin(){
        require(admins[msg.sender] == true, "Only Admin!");
        _;
    }

    // constructor() {
    //     _disableInitializers();
    // }   

    /**
     * @notice Initializes the contract with the Gini token address and the chain ID.
     * @dev This function is called only once during the contract's initialization.
     *      It sets the Gini token address and the current chain ID.
     *      It also initializes the `Ownable` and `UUPSUpgradeable` contracts.
     * @param _giniTokenAddress The address of the Gini token (ERC20) contract.
     * @param _currentChainId The ID of the blockchain network where this contract is deployed.
     *
     * Requirements:
     * - This function can only be called once as it uses the `initializer` modifier.
     * - Initializes the ownership of the contract using `__Ownable_init()`.
     * - Prepares the contract for upgradeability using `__UUPSUpgradeable_init()`.
     */
    function initialize(address _giniTokenAddress, uint256 _currentChainId) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        currentChainId = _currentChainId;
        giniTokenAddress = _giniTokenAddress;
    }

    function addAdmin(address _admin) onlyOwner public {
        admins[_admin] = true;
    }

    function removeAdmin(address _admin) onlyOwner public {
        admins[_admin] = false;
    }

    /**
     * @notice Bridges the specified amount of tokens from the sender's address to the receiver's address.
     * @dev This function locks the specified amount of tokens from the sender in the bridge contract. 
     *      The sender must approve the contract to spend the tokens before calling this function.
     * @param _receiverAddress The address on the destination chain where the tokens will be sent.
     * @param _amount The amount of tokens to be bridged (locked in the current chain).
     * 
     * Requirements:
     * - The sender must have approved the contract to spend at least `_amount` tokens.
     * - Emits a `BridgeLock` event after successfully locking the tokens.
     * - Transfers the tokens from the sender's address to the bridge contract.
     * - Updates the total amount of locked tokens.
     */
    function bridgeToken(string memory _receiverAddress, uint256 _amount) public {
        IERC20 giniToken = IERC20(giniTokenAddress);
        uint256 allowance = giniToken.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Approval Not Done!");
        totalLockedToken = totalLockedToken + _amount ;
        emit BridgeLock(msg.sender, _receiverAddress, _amount, currentChainId) ;

        giniToken.transferFrom(msg.sender, address(this), _amount);
    }

    /**
    * @notice Handles the process of marking tokens as ready for withdrawal for a specific receiver.
    * @dev This function checks the status of the tokens for the receiver. If the status is "withdrawalReady", 
    *      it increases the amount of tokens marked for withdrawal. Otherwise, it sets the amount and status.
    *      Only an admin can execute this function.
    * @param _receiverAddress The address of the user who will receive the tokens on the destination chain.
    * @param _amount The amount of tokens to be bridged and made ready for withdrawal.
    * 
    * Requirements:
    * - The caller must have the "Admin" role.
    * - If the receiver's tokens are already marked as "withdrawalReady", increase the amount.
    * - Otherwise, set the amount and mark the tokens' status as "withdrawalReady".
    * - Updates the total allocated locked tokens.
    * - Emits a `HandleTokenBridging` event upon successful processing.
    */
    function handleTokenBridging(address _receiverAddress, uint256 _amount) onlyAdmin public {
        if (keccak256(abi.encodePacked(unlockedTokens[_receiverAddress].status)) == keccak256(abi.encodePacked("withdrawalReady"))) {
            unlockedTokens[_receiverAddress].amount += _amount ;
        } else {
            unlockedTokens[_receiverAddress] = unlockedToken({amount : _amount, status : "withdrawalReady"});
        }
        allocatedLockedToken = allocatedLockedToken + _amount;

        emit HandleTokenBridging(_receiverAddress, _amount, currentChainId);
    }

    /**
     * @notice Allows the user to withdraw tokens that are marked as "withdrawalReady".
     * @dev This function checks if the caller has tokens ready for withdrawal.
     *      If the status is "withdrawalReady" and the user has a non-zero amount, the tokens are transferred.
     *      The function updates the status to "withdrawalCompleted" and resets the user's amount to zero.
     *      the caller (msg.sender) is the beneficiary of the withdrawal.
     *
     * Requirements:
     * - The caller must have tokens marked as "withdrawalReady".
     * - The caller must have a positive token balance to withdraw.
     * - The total locked and allocated token balances are reduced by the withdrawal amount.
     * - The user's withdrawal status is updated to "withdrawalCompleted".
     * - Emits a `WithdrawTokenEmit` event upon successful withdrawal.
     */
    function withdrawToken() public {
        require(keccak256(abi.encodePacked(unlockedTokens[msg.sender].status)) == keccak256(abi.encodePacked("withdrawalReady")) , "Can not withdraw!");
        require(unlockedTokens[msg.sender].amount >= 0, "No amount to withdraw!");
        IERC20 giniToken = IERC20(giniTokenAddress);
        uint256 amount = unlockedTokens[msg.sender].amount;
        allocatedLockedToken = allocatedLockedToken - amount ;
        totalLockedToken = totalLockedToken - amount ;
        unlockedTokens[msg.sender].status = "withdrawalCompleted";
        unlockedTokens[msg.sender].amount = 0 ;
        emit WithdrawToken(msg.sender, amount, currentChainId) ;

        giniToken.transfer(msg.sender, amount);
    }

    /**
     * @notice Authorizes the contract upgrade to a new implementation address.
     * @param newImplementation The address of the new implementation contract.
     *
     * This function is called internally to ensure that only the contract owner
     * can authorize an upgrade to a new implementation. It overrides the internal 
     * `_authorizeUpgrade` function provided by the OpenZeppelin upgradeable contracts.
     *
     * Requirements:
     * - The caller must be the owner of the contract (checked via `onlyOwner` modifier).
     *
     * This function is critical in ensuring secure upgradeability of the contract
     * by restricting who can authorize an upgrade, thereby preventing unauthorized upgrades.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}   