// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Escrow is Ownable, Pausable {
    
    enum EscrowState { Created, Funded, Completed, Refunded }
    EscrowState public state;
    
    address payable public payer;
    address payable public payee;
    uint256 public amount;

    event EscrowFunded(address indexed payer, uint256 amount);
    event EscrowCompleted(address indexed payee, uint256 amount);
    event EscrowRefunded(address indexed payer, uint256 amount);
    event ContractPaused(address indexed admin);
    event ContractUnpaused(address indexed admin);

    // Constructor must pass the initial owner to the Ownable contract constructor
    constructor(address payable _payee) Ownable(msg.sender) {
        payer = payable(msg.sender); // Contract deployer is the payer
        payee = _payee;
        state = EscrowState.Created;
    }

    modifier onlyPayer() {
        require(msg.sender == payer, "Escrow: Only the payer can call this function.");
        _;
    }

    modifier onlyPayee() {
        require(msg.sender == payee, "Escrow: Only the payee can call this function.");
        _;
    }

    modifier inState(EscrowState _state) {
        require(state == _state, "Escrow: Invalid state for this operation.");
        _;
    }

    // Function to fund the escrow
    function fundEscrow() external payable onlyPayer inState(EscrowState.Created) whenNotPaused {
        require(msg.value > 0, "Escrow: You must send some Ether.");
        amount = msg.value;
        state = EscrowState.Funded;
        emit EscrowFunded(payer, amount);
    }

    // Function for payee to confirm completion of transaction
    function completeEscrow() external onlyPayee inState(EscrowState.Funded) whenNotPaused {
        state = EscrowState.Completed;
        payee.transfer(amount);
        emit EscrowCompleted(payee, amount);
    }

    // Function to refund payer in case of a paused contract or issue
    function refundEscrow() external onlyOwner inState(EscrowState.Funded) whenPaused {
        state = EscrowState.Refunded;
        payer.transfer(amount);
        emit EscrowRefunded(payer, amount);
    }

    // Pause the contract in case of suspicious activity
    function pause() external onlyOwner whenNotPaused {
        _pause(); // This is the internal function from Pausable
        emit ContractPaused(msg.sender);
    }

    // Unpause the contract if everything is secure
    function unpause() external onlyOwner whenPaused {
        _unpause(); // This is the internal function from Pausable
        emit ContractUnpaused(msg.sender);
    }
    
    // Allow contract to accept Ether directly (receive function)
    receive() external payable whenNotPaused {
        require(msg.value > 0, "Escrow: No Ether sent");
        // Fund the escrow directly when Ether is received
        if (state == EscrowState.Created) {
            amount = msg.value;
            state = EscrowState.Funded;
            emit EscrowFunded(payer, amount);
        } else {
            revert("Escrow: Cannot fund escrow in current state.");
        }
    }

    // Fallback function to handle unexpected calls
    fallback() external payable {
        revert("Escrow: Invalid call");
    }
}
