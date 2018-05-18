const ArbeeDisputableSingle = artifacts.require("../contracts/ArbeeDisputableSingle.sol");

contract('ArbeeDisputableSingle', (accounts) => {
  let ArbeeDisputableSingleInstance;
  const contractOwner = accounts[0];
  const payee = accounts[1];
  const payer = accounts[2];
  const arbitrator = accounts[3];
  const randomAddress = accounts[4];
  const units = 10;
  const arbitratorFee = 2;
  const description = "for testing";
  const title = "testing";

  beforeEach(async () => {
    ArbeeDisputableSingleInstance = await ArbeeDisputableSingle.deployed();
  })

  describe('Money Request (invoice)', () => {
    it('Should allow someone to create a money request (invoice) in ETH', async () => {
      const receipt = await ArbeeDisputableSingleInstance.createByPayee(
        0x0,
        web3.toWei(units, "ether"),
        description,
        title,
        payer,
        arbitrator,
        web3.toWei(arbitratorFee, "ether"),
        { from: payee }
      );

      assert.equal(receipt.logs.length, 1, "one event should have been triggered");
      assert.equal(receipt.logs[0].event, "LogCreated", "event should be LogCreated");
      assert.equal(receipt.logs[0].args._payee, payee, "event payee must be " + payee);
      assert.equal(receipt.logs[0].args._payer, payer, "event payer must be " + payer);
      assert.equal(receipt.logs[0].args._id, 0, "event id for transactoin must be 0");
      assert.equal(receipt.logs[0].args._tokenAddress, 0x0, "event token address must be 0x0")
      assert.equal(receipt.logs[0].args._units, web3.toWei(units, "ether"), "event units must be " + units);

      const numTransactions = await ArbeeDisputableSingleInstance.numTransactions();
      assert.equal(numTransactions, 1, "number of transactions should be 1");

      let createdTransaction = await ArbeeDisputableSingleInstance.transactions(0);
      assert.equal(createdTransaction[0], payee, "created transaction payee must be " + payee);
      assert.equal(createdTransaction[1], payer, "created transaction payee must be " + payer);
      assert.equal(createdTransaction[2], arbitrator, "created transaction arbitrator must be " + arbitrator);
      assert.equal(createdTransaction[3], 0x0, "created transaction asset addr must be 0x0");
      assert.equal(createdTransaction[4], description, "created transaction description must be " + description);
      assert.equal(createdTransaction[5], title, "created transaction title must be " + title);
      assert.equal(createdTransaction[6].toNumber(), web3.toWei(units, "ether"), "created transaction units must be " + 100);
      assert.equal(createdTransaction[7], 0, "created transaction balance must be 0");
      assert.equal(createdTransaction[8].toNumber(), web3.toWei(arbitratorFee, "ether"), "created transaction arbitrator fee must be " + arbitratorFee);
      assert.equal(createdTransaction[9].toString(10), 0, "created transaction state must be new");

    });


    it('should throw an exception if someone other than the payee pays the transaction', async () => {
      try {
        await ArbeeDisputableSingleInstance.payInvoice(0, web3.toWei(units, "ether"), {
          from: randomAddress,
          value: web3.toWei(units, "ether")
        });
        assert.fail;
      } catch (error) {
        assert(true);
      }

      createdTransaction = await ArbeeDisputableSingleInstance.transactions(0);
      assert(createdTransaction[7], 0 , "transaction balance shuold still be 0");
    })

    it('should allow payer to pay tranasction', async () => {
      await ArbeeDisputableSingleInstance.payInvoice(0, web3.toWei(units, "ether"), {
        from: payer,
        value: web3.toWei(units, "ether")
      });

      createdTransaction = await ArbeeDisputableSingleInstance.transactions(0);
      assert(createdTransaction[7], web3.toWei(units, "ether"), "transaction balance should be " + units);
      assert(createdTransaction[9].toString(10), 1, "created transaction state should be pending");

      const contractBal = await ArbeeDisputableSingleInstance.getBalance({
        from: contractOwner
      });
      assert(contractBal, web3.toWei(units), "contract balance should now be " + units);
    })
  })
})