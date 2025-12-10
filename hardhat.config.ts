import toolbox from "@nomicfoundation/hardhat-toolbox-viem";
import { defineConfig } from "hardhat/config";

export default defineConfig({
  plugins: [toolbox],
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  test: {
    solidity: {
      ffi: true,
    },
  },
});
