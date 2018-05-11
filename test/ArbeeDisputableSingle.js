// const assert = require('assert');
// const ganache = require('ganache-cli');
// const Web3 = require('web3');
// const web3 = newWeb3(ganache.provider());

// const CompiledArbeeDisputableSingle = require('../build/contracts/ArbeeDisputableSingle.json');

// let accounts;
// let ArbeeDisputableSingle;

// beforeEach(async () => {
//     accounts = await web3.eth.getAccounts();
//     ArbeeDisputableSingle = await new web3.eth.Contract(JSON.parse(compiledFactory.interface));
// })

const ArbeeDisputableSingle = artifacts.require("../contracts/ArbeeDisputableSingle.sol");

contract('ArbeeDisputableSingle', (accounts) => {
  let ArbeeDisputableSingleInstance;
  const contractOwner = accounts[0];
  const payee = accounts[1];
  const payer = accounts[2];
  const arbitrator = accounts[3];
  const units = 10;
  const arbitratorFee = 2;

  beforeEach(async () => {
    ArbeeDisputableSingleInstance = await ArbeeDisputableSingle.deployed();
  })

  describe('Money Request (invoice)', () => {
    it('Should allow someone to create a money request (invoice) in ETH', async () => {
      const receipt = await ArbeeDisputableSingleInstance.createByPayee(
        0x0,
        web3.toWei(units, "ether"),
        "for testing",
        "testing",
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
      assert.equal(receipt.logs[0].args._arbitrator, arbitrator, "event arbitrator address must be " + arbitrator);
      assert.equal(receipt.logs[0].args._units, web3.toWei(units, "ether"), "event units must be " + units);
    });
  })
})