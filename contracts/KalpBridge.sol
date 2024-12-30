// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract KalpBridge is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    /*
     * Adding the methods from the OpenZeppelin's library which wraps around ERC20 operations that
     * throw on failure to implement their safety.
     */
    using SafeERC20 for ERC20;

    /**
     * @notice Emitted when tokens are locked in the bridge contract to initiate a cross-chain transfer.
     * @param from The address of the sender locking the tokens.
     * @param to The address of the receiver on the destination chain, passed in string format.
     * @param amount The amount of tokens being locked.
     * @param currentChainId The chain ID of the network where tokens are being locked.
     * @param nonce This is to have the number of transaction done to perform locking.
     *
     * This event signifies that the specified `amount` of tokens from the `from` address have been
     * locked in the bridge contract and are ready for cross-chain bridging to the `to` address.
     */
    event BridgeToken(address from, string to, uint256 amount, uint256 currentChainId, uint256 nonce);

    /**
     * @notice Emitted when tokens are bridged to the destination chain and are available for the beneficiary.
     * @param to The address of the receiver on the destination chain.
     * @param amount The amount of tokens being bridged to the `to` address.
     * @param currentChainId The chain ID of the network where tokens are bridged to.
     *
     * This event indicates that tokens are successfully bridged and available for withdrawal by the
     * beneficiary on the destination chain.
     */
    event HandleBridgeToken(address to, uint256 amount, uint256 currentChainId);

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

    uint256 public nonce; 
    uint256 public currentChainId;
    uint256 public totalLockedToken;    // Total tokens which are locked inside Kalp Bridge during BridgeToken.
    uint256 public allocatedLockedToken;    // Total tokens which are still locked in Kalp Bridge but allocated to withdraw.  
    address giniTokenAddress; 
    
    struct unlockedToken {
        uint256 amount;
        string status;
    }

    struct receivedTokensFrom {
        string tokenReceivedFrom;
        uint256 amount;
        string txId;
    }

    mapping(address => bool) public admins;
    mapping(address => unlockedToken) public unlockedTokens;    // Tokens which are still locked in kalp bridge but to withdraw for specific user
    mapping(address => receivedTokensFrom[]) public receivedTokensRecord;
    mapping(string => bool) public txIdPresent; 
    

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
     * @param _currentChainId The ID of the blockchain network where this contract is deployed.
     *
     * Requirements:
     * - This function can only be called once as it uses the `initializer` modifier.
     * - Initializes the ownership of the contract using `__Ownable_init()`.
     * - Prepares the contract for upgradeability using `__UUPSUpgradeable_init()`.
     */
    function initialize(uint256 _currentChainId) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        nonce = 0;
        totalLockedToken = 2000000000000000000000000000;
        currentChainId = _currentChainId;
    }

    function addAdmin(address _admin) onlyOwner public {
        admins[_admin] = true;
    }

    function removeAdmin(address _admin) onlyOwner public {
        admins[_admin] = false;
    }

    function setGiniToken(address _giniTokenAddress) public onlyAdmin {
        require(giniTokenAddress == address(0), "Address is being set!");
        giniTokenAddress = _giniTokenAddress;
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
        ERC20 giniToken = ERC20(giniTokenAddress);
        uint256 allowance = giniToken.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Approval Not Done!");
        totalLockedToken = totalLockedToken + _amount ;
        nonce = nonce + 1;
        emit BridgeToken(msg.sender, _receiverAddress, _amount, currentChainId, nonce) ;

        giniToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
    * @notice Handles the process of marking tokens as ready for withdrawal for a specific receiver.
    * @dev This function checks the status of the tokens for the receiver. If the status is "withdrawalReady", 
    *      it increases the amount of tokens marked for withdrawal. Otherwise, it sets the amount and status.
    *      Only an admin can execute this function.
    * @param _senderAddress The address of the user who has initiated the tokens bridiging on the source chain.
    * @param _receiverAddress The address of the user who will receive the tokens on the destination chain.
    * @param _amount The amount of tokens to be bridged and made ready for withdrawal.
    * @param _txId TxId generated on source.
    * 
    * Requirements:
    * - The caller must have the "Admin" role.
    * - If the receiver's tokens are already marked as "withdrawalReady", increase the amount.
    * - Otherwise, set the amount and mark the tokens' status as "withdrawalReady".
    * - Updates the total allocated locked tokens.
    * - Emits a `handleBridgeToken` event upon successful processing.
    */
    function handleBridgeToken(string memory _senderAddress, address _receiverAddress, uint256 _amount, string memory _txId) onlyAdmin public {
        require(!txIdPresent[_txId], "tx already received!");
        txIdPresent[_txId] = true;
        receivedTokensRecord[_receiverAddress].push(receivedTokensFrom({tokenReceivedFrom: _senderAddress, amount: _amount, txId: _txId}));
        if (keccak256(abi.encodePacked(unlockedTokens[_receiverAddress].status)) == keccak256(abi.encodePacked("withdrawalReady"))) {
            unlockedTokens[_receiverAddress].amount += _amount ;
        } else {
            unlockedTokens[_receiverAddress] = unlockedToken({amount : _amount, status : "withdrawalReady"});
        }
        allocatedLockedToken = allocatedLockedToken + _amount;

        emit HandleBridgeToken(_receiverAddress, _amount, currentChainId);
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
        ERC20 giniToken = ERC20(giniTokenAddress);
        uint256 amount = unlockedTokens[msg.sender].amount;
        allocatedLockedToken = allocatedLockedToken - amount ;
        totalLockedToken = totalLockedToken - amount ;
        unlockedTokens[msg.sender].status = "withdrawalCompleted";
        unlockedTokens[msg.sender].amount = 0 ;
        emit WithdrawToken(msg.sender, amount, currentChainId) ;

        giniToken.safeTransfer(msg.sender, amount);
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