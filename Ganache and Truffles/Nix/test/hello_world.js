const HelloWorld = artifacts.require("HelloWorld");

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */
contract("HelloWorld", function (/* accounts */) {
  it("should assert true", async function () {
    const instance = await HelloWorld.deployed();
    const result = await instance.sayHelloWorld.call();
    return assert.equal(result, "Hello World", "The result is not Hello World");
  });
});