// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./Blake2s.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract Blake2sTest is Test {
  function assertBlake2s(bytes memory input, bytes32 expected) internal {
    uint256 gasBefore = gasleft();
    bytes32 result = blake2s(input);
    console.log("gas", gasBefore - gasleft());
    assertEq(result, expected);
  }

  function test_empty_string() public {
    assertBlake2s(bytes(""), 0x69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9);
  }

  function test_abc() public {
    assertBlake2s(bytes("abc"), 0x508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982);
  }

  function test_quick_brown_fox() public {
    assertBlake2s(bytes("The quick brown fox jumps over the lazy dog"), 0x606beeec743ccbeff6cbcdf5d5302aa855c256c29b88c8ed331ea1a6bf3c8812);
  }

  function test_64_bytes() public {
    bytes memory input = new bytes(64);
    for (uint i = 0; i < 64; i++) input[i] = "a";
    assertBlake2s(input, 0x651d2f5f20952eacaea2fba2f2af2bcd633e511ea2d2e4c9ae2ac0d9ffb7b252);
  }

  function test_65_bytes() public {
    bytes memory input = new bytes(65);
    for (uint i = 0; i < 65; i++) input[i] = "a";
    assertBlake2s(input, 0x045f8ae18932119bd051ac7ba5c73db59892055fad5c32f82d79a6543d92a497);
  }

  function testFuzz_ffi(bytes memory input) public {
    bytes32 result = blake2s(input);

    string[] memory cmd = new string[](3);
    cmd[0] = "bash";
    cmd[1] = "-c";
    cmd[2] = string.concat("printf 0x; echo ", vm.toString(input), " | xxd -r -p | b2sum -a blake2s -l 256 | head -c64");

    bytes memory output = vm.ffi(cmd);
    bytes32 expected = abi.decode(output, (bytes32));
    assertEq(result, expected);
  }
}