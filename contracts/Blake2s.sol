// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

library Blake2s {
    uint32 constant BLOCKBYTES = 64;
    uint32 constant OUTBYTES = 32;

    uint32 constant IV0 = 0x6A09E667;
    uint32 constant IV1 = 0xBB67AE85;
    uint32 constant IV2 = 0x3C6EF372;
    uint32 constant IV3 = 0xA54FF53A;
    uint32 constant IV4 = 0x510E527F;
    uint32 constant IV5 = 0x9B05688C;
    uint32 constant IV6 = 0x1F83D9AB;
    uint32 constant IV7 = 0x5BE0CD19;

    struct State {
        uint32[8] h;
        uint32[2] t;
    }

    function hash(bytes memory input) internal pure returns (bytes32) {
        State memory S;
        S.h[0] = IV0 ^ 0x01010000 ^ OUTBYTES;
        S.h[1] = IV1;
        S.h[2] = IV2;
        S.h[3] = IV3;
        S.h[4] = IV4;
        S.h[5] = IV5;
        S.h[6] = IV6;
        S.h[7] = IV7;

        uint256 len = input.length;
        uint256 offset = 0;

        unchecked {
            while (len > BLOCKBYTES) {
                incrementCounter(S, BLOCKBYTES);
                compress(S, input, offset, false);
                offset += BLOCKBYTES;
                len -= BLOCKBYTES;
            }

            bytes memory padded = new bytes(64);
            for (uint256 i = 0; i < len; i++) {
                padded[i] = input[offset + i];
            }
            incrementCounter(S, uint32(len));
            compress(S, padded, 0, true);
        }

        return hashFromState(S);
    }

    function hashFromState(State memory S) private pure returns (bytes32) {
        bytes memory out = new bytes(32);
        unchecked {
            store32(out, 0, S.h[0]);
            store32(out, 4, S.h[1]);
            store32(out, 8, S.h[2]);
            store32(out, 12, S.h[3]);
            store32(out, 16, S.h[4]);
            store32(out, 20, S.h[5]);
            store32(out, 24, S.h[6]);
            store32(out, 28, S.h[7]);
        }
        return bytes32(out);
    }

    function incrementCounter(State memory S, uint32 inc) private pure {
        unchecked {
            S.t[0] += inc;
            if (S.t[0] < inc) {
                S.t[1] += 1;
            }
        }
    }

    function rotr32(uint32 x, uint32 n) private pure returns (uint32) {
        unchecked {
            return (x >> n) | (x << (32 - n));
        }
    }

    function load32(bytes memory b, uint256 offset) private pure returns (uint32) {
        unchecked {
            return uint32(uint8(b[offset])) |
                   (uint32(uint8(b[offset + 1])) << 8) |
                   (uint32(uint8(b[offset + 2])) << 16) |
                   (uint32(uint8(b[offset + 3])) << 24);
        }
    }

    function store32(bytes memory b, uint256 offset, uint32 value) private pure {
        unchecked {
            b[offset] = bytes1(uint8(value));
            b[offset + 1] = bytes1(uint8(value >> 8));
            b[offset + 2] = bytes1(uint8(value >> 16));
            b[offset + 3] = bytes1(uint8(value >> 24));
        }
    }

    function compress(State memory S, bytes memory block_, uint256 offset, bool isFinal) private pure {
        uint32[16] memory m;
        uint32[16] memory v;

        unchecked {
            m[0] = load32(block_, offset + 0);
            m[1] = load32(block_, offset + 4);
            m[2] = load32(block_, offset + 8);
            m[3] = load32(block_, offset + 12);
            m[4] = load32(block_, offset + 16);
            m[5] = load32(block_, offset + 20);
            m[6] = load32(block_, offset + 24);
            m[7] = load32(block_, offset + 28);
            m[8] = load32(block_, offset + 32);
            m[9] = load32(block_, offset + 36);
            m[10] = load32(block_, offset + 40);
            m[11] = load32(block_, offset + 44);
            m[12] = load32(block_, offset + 48);
            m[13] = load32(block_, offset + 52);
            m[14] = load32(block_, offset + 56);
            m[15] = load32(block_, offset + 60);

            v[0] = S.h[0];
            v[1] = S.h[1];
            v[2] = S.h[2];
            v[3] = S.h[3];
            v[4] = S.h[4];
            v[5] = S.h[5];
            v[6] = S.h[6];
            v[7] = S.h[7];
        }

        v[8] = IV0;
        v[9] = IV1;
        v[10] = IV2;
        v[11] = IV3;
        v[12] = S.t[0] ^ IV4;
        v[13] = S.t[1] ^ IV5;
        v[14] = isFinal ? type(uint32).max ^ IV6 : IV6;
        v[15] = IV7;

        round(v, m, 0);
        round(v, m, 1);
        round(v, m, 2);
        round(v, m, 3);
        round(v, m, 4);
        round(v, m, 5);
        round(v, m, 6);
        round(v, m, 7);
        round(v, m, 8);
        round(v, m, 9);

        S.h[0] ^= v[0] ^ v[8];
        S.h[1] ^= v[1] ^ v[9];
        S.h[2] ^= v[2] ^ v[10];
        S.h[3] ^= v[3] ^ v[11];
        S.h[4] ^= v[4] ^ v[12];
        S.h[5] ^= v[5] ^ v[13];
        S.h[6] ^= v[6] ^ v[14];
        S.h[7] ^= v[7] ^ v[15];
    }

    function G(uint32[16] memory v, uint32[16] memory, uint256 a, uint256 b, uint256 c, uint256 d, uint32 x, uint32 y) private pure {
        unchecked {
            v[a] = v[a] + v[b] + x;
            v[d] = rotr32(v[d] ^ v[a], 16);
            v[c] = v[c] + v[d];
            v[b] = rotr32(v[b] ^ v[c], 12);
            v[a] = v[a] + v[b] + y;
            v[d] = rotr32(v[d] ^ v[a], 8);
            v[c] = v[c] + v[d];
            v[b] = rotr32(v[b] ^ v[c], 7);
        }
    }

    uint256 constant SIGMA0123 = 0x8F04A562EBCD1397491763EADF250C8B357B20C16DF984AEFEDCBA9876543210;
    uint256 constant SIGMA4567 = 0xA2684F05931CE7BDB8293670A4DEF15C91EF57D438B0A6C2D386CB1EFA427509;
    uint256 constant SIGMA89 = 0x0DC3E9BF5167482A5A417D2C803B9EF6;

    function sigma(uint256 r, uint256 i) private pure returns (uint256) {
        unchecked {
            uint256 packed;
            if (r < 4) packed = SIGMA0123;
            else if (r < 8) packed = SIGMA4567;
            else packed = SIGMA89;

            return (packed >> (((r & 0x3) << 6) + (i << 2))) & 0xF;
        }
    }

    function round(uint32[16] memory v, uint32[16] memory m, uint256 r) private pure {
        G(v, m, 0, 4,  8, 12, m[sigma(r, 0)],  m[sigma(r, 1)]);
        G(v, m, 1, 5,  9, 13, m[sigma(r, 2)],  m[sigma(r, 3)]);
        G(v, m, 2, 6, 10, 14, m[sigma(r, 4)],  m[sigma(r, 5)]);
        G(v, m, 3, 7, 11, 15, m[sigma(r, 6)],  m[sigma(r, 7)]);
        G(v, m, 0, 5, 10, 15, m[sigma(r, 8)],  m[sigma(r, 9)]);
        G(v, m, 1, 6, 11, 12, m[sigma(r, 10)], m[sigma(r, 11)]);
        G(v, m, 2, 7,  8, 13, m[sigma(r, 12)], m[sigma(r, 13)]);
        G(v, m, 3, 4,  9, 14, m[sigma(r, 14)], m[sigma(r, 15)]);
    }
}

function blake2s(bytes memory input) pure returns (bytes32) {
    return Blake2s.hash(input);
}