const { expect } = require("chai");

describe("DrivingLicenseToken", function () {
  async function setup() {
    const [issuer, owner, receiver] = await hre.ethers.getSigners();

    const drivingLicenseTokenContractFactory =
      await hre.ethers.getContractFactory("DrivingLicenseToken");
    const drivingLicenseTokenContract =
      await drivingLicenseTokenContractFactory.deploy();
    await drivingLicenseTokenContract.deployed();

    const tokenId = 1;

    await drivingLicenseTokenContract
      .connect(issuer)
      .issueDrivingLicense(owner.address, tokenId);

    return { drivingLicenseTokenContract, issuer, owner, receiver, tokenId };
  }

  describe("given a driving license souldbound token, locked, and only burnable by the issuer", () => {
    describe("when the owner tries to transfer his token", async () => {
      it("fails to transfer the token because it's locked", async () => {
        const { drivingLicenseTokenContract, owner, receiver, tokenId } =
          await setup();

        expect(
          drivingLicenseTokenContract
            .connect(owner)
            .transferFrom(owner.address, receiver.address, tokenId)
        ).to.be.revertedWith(/reverted with custom error \'ErrLocked\(\)\'/);

        expect(
          await drivingLicenseTokenContract
            .connect(owner)
            .getDrivingLicenseOwner(tokenId)
        ).to.be.equal(owner.address);
      });
    });

    describe("when the issuer tries to transfer the token", () => {
      it("fails to transfer the token because it's locked", async () => {
        const {
          drivingLicenseTokenContract,
          issuer,
          owner,
          receiver,
          tokenId,
        } = await setup();

        expect(
          drivingLicenseTokenContract
            .connect(issuer)
            .transferFrom(owner.address, receiver.address, tokenId)
        ).to.be.revertedWith(/reverted with custom error \'ErrLocked\(\)\'/);

        expect(
          await drivingLicenseTokenContract
            .connect(issuer)
            .getDrivingLicenseOwner(tokenId)
        ).to.be.equal(owner.address);
      });
    });

    describe("when the owner tries to burn his token", () => {
      it("fails because he's not allowed to", async () => {
        const { drivingLicenseTokenContract, owner, tokenId } = await setup();

        expect(
          drivingLicenseTokenContract.connect(owner).burn(tokenId)
        ).to.be.revertedWith(
          /The set burnAuth doesn't allow you to burn this token/
        );

        expect(
          await drivingLicenseTokenContract
            .connect(owner)
            .getDrivingLicenseOwner(tokenId)
        ).to.be.equal(owner.address);
      });
    });

    describe("when the issuer tries to burn the token", () => {
      it("fails because he's not allowed to", async () => {
        const { drivingLicenseTokenContract, issuer, owner, tokenId } =
          await setup();

        expect(drivingLicenseTokenContract.connect(issuer).burn(tokenId)).not.to
          .be.reverted;

        expect(
          await drivingLicenseTokenContract
            .connect(issuer)
            .getDrivingLicenseOwner(tokenId)
        ).to.be.equal("0x0000000000000000000000000000000000000000");
      });
    });
  });
});
