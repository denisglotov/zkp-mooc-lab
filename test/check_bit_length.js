const path = require("path");
const assert = require("chai").assert;
const wasm_tester = require("circom_tester").wasm;

describe("CheckBitLength", () => {
    var circ_file = path.join(__dirname, "circuits", "check_bit_length.circom");
    var circ, num_constraints;

    before(async () => {
        circ = await wasm_tester(circ_file);
        await circ.loadConstraints();
        num_constraints = circ.constraints.length;
        var b = 23;
        console.log("CheckBitLength #Constraints:", num_constraints, "Expected:", b + 2);
        var expected_constraints = b + 2;
        if (num_constraints < expected_constraints) {
            console.log("WARNING: number of constraints is less than b + 2. It is likely that you are not constraining the witnesses appropriately.");
        }
    });

    it("bitlength of `in` <= `b`", async () => {
        const input = {
            "in": "4903265",
        };
        const witness = await circ.calculateWitness(input);
        await circ.checkConstraints(witness);
        await circ.assertOut(witness, {"out": "1"});
    });

    it("bitlength of `in` > `b`", async () => {
        const input = {
            "in": "13291873",
        };
        const witness = await circ.calculateWitness(input);
        await circ.checkConstraints(witness);
        await circ.assertOut(witness, {"out": "0"});
    });

  it("2 ** 22 --> 1", async () => {
        const input = {
            "in": "4194304",
        };
        const witness = await circ.calculateWitness(input);
        await circ.checkConstraints(witness);
        await circ.assertOut(witness, {"out": "1"});
  });

  it("2 ** 23 - 1 --> 1", async () => {
        const input = {
            "in": "8388607",
        };
        const witness = await circ.calculateWitness(input);
        await circ.checkConstraints(witness);
        await circ.assertOut(witness, {"out": "1"});
  });

  it("2 ** 23 ---> 0", async () => {
        const input = {
            "in": "8388608",
        };
        const witness = await circ.calculateWitness(input);
        await circ.checkConstraints(witness);
        await circ.assertOut(witness, {"out": "0"});
  });

  it("2 ** 24 ---> 0", async () => {
        const input = {
            "in": "16777216",
        };
        const witness = await circ.calculateWitness(input);
        await circ.checkConstraints(witness);
        await circ.assertOut(witness, {"out": "0"});
  });

  it("2 ** 25 ---> 0", async () => {
        const input = {
            "in": "33554432",
        };
        const witness = await circ.calculateWitness(input);
        await circ.checkConstraints(witness);
        await circ.assertOut(witness, {"out": "0"});
  });

  it("2 ** 26 ---> 0", async () => {
        const input = {
            "in": "67108864",
        };
        const witness = await circ.calculateWitness(input);
        await circ.checkConstraints(witness);
        await circ.assertOut(witness, {"out": "0"});
  });

  it("2 ** 27 ---> 0", async () => {
        const input = {
            "in": "134217728",
        };
        const witness = await circ.calculateWitness(input);
        await circ.checkConstraints(witness);
        await circ.assertOut(witness, {"out": "0"});
  });

  it("p - 1 ---> 0", async () => {
        const input = {
            "in": "21888242871839275222246405745257275088548364400416034343698204186575808495616",
        };
        const witness = await circ.calculateWitness(input);
        await circ.checkConstraints(witness);
        await circ.assertOut(witness, {"out": "0"});
  });
});
