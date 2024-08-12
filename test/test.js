const { expect } = require("chai");
const { ethers, waffle } = require("hardhat");
const { parseUnits } = require("ethers/lib/utils");

describe("NFTSale", function () {
  let accounts;
  let admin;
  let alice;
  let bob;

  let adminAddress;
  let aliceAddress;
  let bobAddress;

  let mockNFT;

  beforeEach(async function () {
    accounts = await ethers.getSigners();
    admin = accounts[0];
    alice = accounts[1];
    bob = accounts[2];

    adminAddress = await admin.getAddress();
    aliceAddress = await alice.getAddress();
    bobAddress = await bob.getAddress();

    const MockNFT = await ethers.getContractFactory("MockNFT");
    mockNFT = await MockNFT.deploy();
    await mockNFT.deployed();

    await mockNFT.connect(admin).mint(aliceAddress, 1);
  });

  it("Should list NFT item & buy item", async function () {
    const Sale = await ethers.getContractFactory("Sale");
    // dev: admin, fee: 5%
    const contract = await Sale.deploy(adminAddress, 50);
    await contract.deployed();

    // approve NFT for sale contract
    await mockNFT.connect(alice).setApprovalForAll(contract.address, true);

    const now = Math.floor(new Date().getTime() / 1000);
    // list item for 10 ETH, expiration: 20 mins
    await contract
      .connect(alice)
      .listItem(mockNFT.address, 1, parseUnits("10", 18), now + 60 * 20);

    const provider = waffle.provider;
    const adminBalanceBefore = await provider.getBalance(adminAddress);
    const aliceBalanceBefore = await provider.getBalance(aliceAddress);
    const bobBalanceBefore = await provider.getBalance(bobAddress);

    // buy alice's NFT from bob
    await contract
      .connect(bob)
      .buyItem(mockNFT.address, 1, { value: parseUnits("10", 18) });

    const adminBalanceAfter = await provider.getBalance(adminAddress);
    const aliceBalanceAfter = await provider.getBalance(aliceAddress);
    const bobBalanceAfter = await provider.getBalance(bobAddress);

    expect(bobBalanceBefore.sub(bobBalanceAfter)).to.gt(parseUnits("10", 18));
    expect(aliceBalanceAfter.sub(aliceBalanceBefore)).to.eq(
      parseUnits("9.5", 18)
    );
    expect(adminBalanceAfter.sub(adminBalanceBefore)).to.eq(
      parseUnits("0.5", 18)
    );

    // check if current owner of NFT #1 is bob
    const owner = await mockNFT.ownerOf(1);
    expect(owner).to.be.eq(bobAddress);
  });
});
