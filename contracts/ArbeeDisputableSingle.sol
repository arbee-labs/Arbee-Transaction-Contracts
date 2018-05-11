pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract ArbeeDisputableSingle is Ownable {
    using SafeMath for uint256;
    
    enum TxStates{ New, Pending, Disputed, Completed, Resolved }

    struct TxStruct {
        address payee;
        address payer;
        address arbitrator;
        address assetAddr;

        string description;
        string txName;
        uint256 units;
        uint256 balance;
        uint256 arbitratorFee;
        TxStates currState;
    }
    
    //////////
    // disputes likely to be moved out to a separate contract in the future to handle other kind of payouts
    //////////
    
    struct DisputeStruct {
        uint256 transactionId;
        bool isOpen;
        mapping (address => uint256) payoutAmts;
    }
    
    // stateVariables
    uint transactionCounter;
    // mapping (address => uint256[]) public userTransactions;
    mapping (uint256 => DisputeStruct) public disputes;
    // mapping (address => uint256[]) public arbitratorTransactions;
    TxStruct[] public transactions;
    
    
    modifier fulfillableTx(address _assetAddress, uint256 _units) {
        ERC20 token = ERC20(_assetAddress);
        require(token.balanceOf(msg.sender) >= _units);
        _;
    }
    
    modifier onlyPayee(uint _id) {
        require(msg.sender == transactions[_id].payee, "only the payee of this tx can call this method");
        
        _;
    }
  
    modifier onlyPayer(uint _id) {
        require(msg.sender == transactions[_id].payer, "only the payer of this tx can call this method");
        
        _;
    }
    
    modifier validTx(uint _id) {
        require(_id <= transactionCounter && _id >= 0, "Not a valid Tx");

        _;
    }
    
    modifier onlyArbitrator(uint _id) {
        require(msg.sender == transactions[_id].arbitrator, "only the Arbitrator of this tx can call this method");
        
        _;
    }
    
    modifier onlyTxParticipants(uint _id) {
        require(msg.sender == transactions[_id].payee || msg.sender == transactions[_id].payer, "only the sender or recipient can call this method");

        _;
    }
    
    modifier onlyDisputed(uint _id) {
        TxStruct memory transaction = transactions[_id];
        DisputeStruct memory transactionDispute = disputes[_id];
        
        require(transaction.currState == TxStates.Disputed && transactionDispute.isOpen);
        
        _;
    }
    
    //events
    event LogCreated(
        uint _id,
        address indexed _payee,
        address indexed _payer,
        address indexed _arbitrator,
        address _tokenAddress,
        uint256 _units
    );
    
    event LogCompleted(
        uint _id,
        address indexed _payee,
        address indexed _payer
    );
    
    event LogDisputed(
        uint _id,
        address indexed _payee,
        address indexed _payer,
        address indexed _arbitrator
    );

    
    /**
    * Functions
    */

    /**
    * @dev invoice creation called by payee
    * @param _tokenAddress address the address of the underlying transaction unit. For ETH use 0X0...
    * @param _units uint units of the underlying asset to be transacted
    * @param _description string descritpion of the transaction
    * @param _txName string name of transaction
    * @param _from address the payer of the tranasction (address msg.sender is requesting units from)
    * @param _arbitrator address designated arbitrator of the transaction. This could be a DAO, another contract, or another person
    * @param _arbitratorFee uint amount arbitrator will get if a transaction needs resolving. This amount must be less than _units
    */
    
    function createByPayee(address _tokenAddress, uint _units, string _description, string _txName, address _from, address _arbitrator, uint _arbitratorFee) public returns (bool success) {
        
        require(_arbitratorFee < _units);
        
        TxStruct memory newInvoice = TxStruct({
            payee: msg.sender,
            payer: _from,
            arbitrator: _arbitrator,
            assetAddr: _tokenAddress,
            description: _description,
            txName: _txName,
            units: _units,
            balance: 0,
            arbitratorFee: _arbitratorFee,
            currState: TxStates.New
        });

        proccessTransaction(newInvoice);

        return true;
    }

    /**
    * @dev sending escrowed ETH to payee called by the payer of the transaction. value will be denoted in msg.value
    * @param _description string descritpion of the transaction
    * @param _txName string name of transaction
    * @param _to address of the transactions payee (address messege.sender is sending units to)
    * @param _arbitrator address designated arbitrator of the transaction. This could be a DAO, another contract, or another person
    * @param _arbitratorFee uint amount arbitrator will get if a transaction needs resolving. This amount must be less than _units
    */
    
    function createByPayer(string _description, string _txName, address _to, address _arbitrator, uint _arbitratorFee) payable public returns (bool success) {
        require(_arbitratorFee < msg.value);
        TxStruct memory newPayment = TxStruct({
            payee: _to,
            payer: msg.sender,
            arbitrator: _arbitrator,
            arbitratorFee: _arbitratorFee,
            assetAddr: 0x0,
            description: _description,
            txName: _txName,
            units: msg.value,
            balance: msg.value,
            currState: TxStates.Pending
        });
        
        proccessTransaction(newPayment);
    
        return true;    
        
    }

    /**
    * @dev sending escrowed tokens to payee called by the payer of the transaction. Similar to createByPayer
    * sender needs to call approve and pass in this contract address along with an amount that is at least _units
    * Transaction will fail otherwise
    *
    * @param _tokenAddress address contract address of token
    * @param _units uint units of assets from _tokenAddress payer is sending to payee
    * @param _description string descritpion of the transaction
    * @param _txName string name of transaction
    * @param _to address of the transactions payee (address messege.sender is sending units to)
    * @param _arbitrator address designated arbitrator of the transaction. This could be a DAO, another contract, or another person
    * @param _arbitratorFee uint amount arbitrator will get if a transaction needs resolving. This amount must be less than _units
    */
    
    function createByPayerERC20(address _tokenAddress, uint _units, string _description, string _txName, address _to, address _arbitrator, uint _arbitratorFee) fulfillableTx(_tokenAddress, _units) payable public returns (bool success) {
        require(_arbitratorFee < _units);

        TxStruct memory newPayment = TxStruct({
            payee: _to,
            payer: msg.sender,
            arbitrator: _arbitrator,
            arbitratorFee: _arbitratorFee,
            assetAddr: _tokenAddress,
            description: _description,
            txName: _txName,
            units: _units,
            balance: _units,
            currState: TxStates.Pending
        });
        
        assert(ERC20(_tokenAddress).transferFrom(msg.sender, this, _units));
        proccessTransaction(newPayment);
    
        // emit LogCreated(transactionCounter, newPayment.payee, newPayment.payer, newPayment.arbitrator, newPayment.assetAddr, newPayment.units);
        // transactionCounter ++;
        return true;    
    }
    
    /**
    * @dev releasing transaction funds to payee. can only be called by payer of TX.
    * Will mark transaction as completed when transfer is complete
    *
    * @param _id uint identifier of transction
    */
    function releaseFunds(uint _id) onlyPayer(_id) validTx(_id) public returns (bool) {
        // transaction must not be completed or cancelled
        TxStruct storage transaction = transactions[_id];
        uint txBal = transaction.balance;

        require(transaction.currState == TxStates.Pending || transaction.currState == TxStates.New || transaction.currState == TxStates.Disputed, 'invalid tx state');
        transaction.balance = 0;
        transaction.currState = TxStates.Completed;
        if(transaction.assetAddr == 0x0) {
            transaction.payee.transfer(txBal);
        } else {
            assert(ERC20(transaction.assetAddr).transfer(transaction.payee, txBal));
        }
        
        emit LogCompleted(_id, transaction.payee, transaction.payer);
        
        return true;
    }

    /**
    * @dev Sending funds to a "New" transaction sent to payer by payee.
    * State will go to "Pending" when transaction balance is equal to number 
    * of units designatedin the transaction
    *
    * @param _id uint identifier of transction
    * @param _units uint number of units payer is sending to transaction
    */
    
    function payInvoice(uint _id, uint _units) public payable onlyPayer(_id) validTx(_id) returns (bool) {
        TxStruct storage transaction = transactions[_id];
        uint256 txBal = transaction.balance;
        require(transaction.currState == TxStates.New);
        
        if(transaction.assetAddr == 0x0) {
            require (_units == msg.value);
            require(txBal.add(msg.value) <= transaction.units);
            transaction.balance = txBal.add(msg.value);
        } else {
            require(_units.add(txBal) <= transaction.units);
            transaction.balance = txBal.add(_units);
            assert(ERC20(transaction.assetAddr).transferFrom(msg.sender, this, _units));
        }
        if (txBal.add(_units) == transaction.units) {
            transaction.currState = TxStates.Pending;
        }
        
        return true;
    }
  
    /**
    * @dev returning transaction funds to payer. can only be called by payee of TX.
    * Will mark transaction as completed when transfer is complete
    *
    * @param _id uint identifier of transction
    */
    function returnFunds(uint _id) onlyPayee(_id) validTx(_id) public returns (bool)  {
        TxStruct storage transaction = transactions[_id];
        DisputeStruct storage dispute = disputes[_id];
        uint txBal = transaction.balance;
        require(transaction.currState == TxStates.Pending || transaction.currState == TxStates.New || transaction.currState == TxStates.Disputed, 'invalid tx state');
        transaction.balance = 0;
        transaction.currState = TxStates.Completed;
        if(transaction.assetAddr == 0x0 && txBal > 0) {
            transaction.payer.transfer(txBal);
        } else {
            assert(ERC20(transaction.assetAddr).transfer(transaction.payer, txBal));
        }
        
        // if dispute is open make sure to close it

        if(dispute.isOpen == true) {
            dispute.isOpen = false;
        }
        
        emit LogCompleted(_id, transaction.payee, transaction.payer);
        return true;
        // Log Event Here
    }
    
    /**
    * @dev escalating transaction and disputing funds. Will give designated arbitrator control of payouts
    * Can be called by both payee or payer
    *
    * @param _id uint identifier of transction
    */
    function disputeTx(uint _id) onlyTxParticipants(_id) public {
        TxStruct storage transaction = transactions[_id];
        require(transaction.currState == TxStates.Pending);
        transaction.currState = TxStates.Disputed;
        
        disputes[_id] = DisputeStruct({
            transactionId: _id,
            isOpen: true
        });
        
        emit LogDisputed(_id, transaction.payee, transaction.payer, transaction.arbitrator);
    }
    
    /**
    * @dev updating disputed payout
    * Can be called by arbitrator if tx is in dispute state
    *
    * @param _id uint identifier of transction
    * @param _userAddress address of either payee or payer
    * @param _userPayout amout designated to address in _userAddress
    *   _userPayout for each single update must be less than balance after arbitratorfees
    */
    function updatePayout(uint _id, address _userAddress, uint _userPayout) public onlyArbitrator(_id) onlyDisputed(_id) returns (bool) {
        TxStruct memory transaction = transactions[_id];
        DisputeStruct storage transactionDispute = disputes[_id];
        uint256 totalPayout = transaction.balance.sub(transaction.arbitratorFee);
        require(_userPayout <= totalPayout, "A payout cannot be greater than the AVAILABLE balance of the contract");
        require(transaction.currState == TxStates.Disputed);
        require(_userAddress == transaction.payee || _userAddress == transaction.payer);
        transactionDispute.payoutAmts[_userAddress] = _userPayout;
        return true;
    }
    
    /**
    * @dev Resolving Tx after disputePayout has been updated
    * Can be called by arbitrator if tx is in dispute state
    * Payouts in dispute must equal the leftover balance of transaction after arbitrator fees.
    *
    * @param _id uint identifier of transction
    */
    function resolveTx(uint _id) public onlyArbitrator(_id) onlyDisputed(_id) returns (bool) {
        TxStruct storage transaction = transactions[_id];
        DisputeStruct storage transactionDispute = disputes[_id];
        uint256 txBal = transaction.balance;
        uint256 totalPayout = txBal.sub(transaction.arbitratorFee);
        uint256 payeePayout = transactionDispute.payoutAmts[transaction.payee];
        uint256 payerPayout = transactionDispute.payoutAmts[transaction.payer];
        uint256 arbitratorPayout = transaction.arbitratorFee;
        
        require(payeePayout.add(payerPayout) == totalPayout, "Invalid Payouts");
        
        transaction.balance = 0;
        transaction.currState = TxStates.Resolved;
        transactionDispute.isOpen = false;
        
        if(transaction.assetAddr == 0x0) {
            // handle eth transfers here;
            if (payerPayout > 0) {
                transaction.payer.transfer(payerPayout);
            }
            
            if (payeePayout > 0) {
                transaction.payee.transfer(payeePayout);
            }
            
            if (arbitratorPayout > 0) {
                transaction.arbitrator.transfer(arbitratorPayout);
            }
        }  else {
            // handle erc20 transfers here
            if (payerPayout > 0) {
                assert(ERC20(transaction.assetAddr).transfer(transaction.payer, payerPayout));
            }
            if (payeePayout > 0) {
                assert(ERC20(transaction.assetAddr).transfer(transaction.payee, payeePayout));
            }
            if (arbitratorPayout > 0) {
                assert(ERC20(transaction.assetAddr).transfer(transaction.arbitrator, arbitratorPayout));
            }
        }
        
        emit LogCompleted(_id, transaction.payee, transaction.payer);
        
        return true;
    }
    
    function proccessTransaction(TxStruct _newTransaction) internal {
        transactions.push(_newTransaction);
        // userTransactions[_newTransaction.payee].push(transactionCounter);
        // userTransactions[_newTransaction.payer].push(transactionCounter);
        
        // if (_newTransaction.arbitrator != 0x0) {
        //     userTransactions[_newTransaction.arbitrator].push(transactionCounter);
        // }
        emit LogCreated(transactionCounter, _newTransaction.payee, _newTransaction.payer, _newTransaction.arbitrator, _newTransaction.assetAddr, _newTransaction.units);
        transactionCounter ++;
    }
    
    function getBalance() onlyOwner public view returns (uint) {
        return address(this).balance;
    }
    
    function numTransactions() onlyOwner public view returns(uint) {
        return transactions.length;
    }
    
    function disputePayout(uint _id, address _addr) public view returns (uint256){
        return disputes[_id].payoutAmts[_addr];
    }


    // function numUserTranasctions(address _uid) public view returns(uint) {
    //     return userTransactions[_uid].length;
    // }
    
}

