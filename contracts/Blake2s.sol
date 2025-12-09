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
        uint32[2] f;
        bytes buf;
    }

    function init(State memory S) internal pure {
        S.h[0] = IV0;
        S.h[1] = IV1;
        S.h[2] = IV2;
        S.h[3] = IV3;
        S.h[4] = IV4;
        S.h[5] = IV5;
        S.h[6] = IV6;
        S.h[7] = IV7;

        S.h[0] ^= 0x01010000 ^ OUTBYTES;

        S.t[0] = 0;
        S.t[1] = 0;
        S.f[0] = 0;
        S.f[1] = 0;
        S.buf = "";
    }

    function update(State memory S, bytes memory input) internal pure {
        uint256 inlen = input.length;
        uint256 inOffset = 0;

        if (inlen > 0) {
            uint256 left = S.buf.length;
            uint256 fill = BLOCKBYTES - left;

            if (inlen > fill) {
                S.buf = bytes.concat(S.buf, slice(input, inOffset, fill));
                incrementCounter(S, BLOCKBYTES);
                compress(S, S.buf);
                inOffset += fill;
                inlen -= fill;
                S.buf = "";

                while (inlen > BLOCKBYTES) {
                    incrementCounter(S, BLOCKBYTES);
                    compress(S, slice(input, inOffset, BLOCKBYTES));
                    inOffset += BLOCKBYTES;
                    inlen -= BLOCKBYTES;
                }
            }
            S.buf = bytes.concat(S.buf, slice(input, inOffset, inlen));
        }
    }

    function finalize(State memory S) internal pure returns (bytes32) {
        incrementCounter(S, uint32(S.buf.length));
        S.f[0] = type(uint32).max;

        while (S.buf.length < BLOCKBYTES) {
            S.buf = bytes.concat(S.buf, bytes1(0));
        }
        compress(S, S.buf);

        bytes memory out = new bytes(32);
        for (uint256 i = 0; i < 8; i++) {
            store32(out, i * 4, S.h[i]);
        }
        return bytes32(out);
    }

    function hash(bytes memory input) internal pure returns (bytes32) {
        State memory S;
        init(S);
        update(S, input);
        return finalize(S);
    }

    function incrementCounter(State memory S, uint32 inc) private pure {
        S.t[0] += inc;
        if (S.t[0] < inc) {
            S.t[1] += 1;
        }
    }

    function rotr32(uint32 x, uint32 n) private pure returns (uint32) {
        return (x >> n) | (x << (32 - n));
    }

    function load32(bytes memory b, uint256 offset) private pure returns (uint32) {
        return uint32(uint8(b[offset])) |
               (uint32(uint8(b[offset + 1])) << 8) |
               (uint32(uint8(b[offset + 2])) << 16) |
               (uint32(uint8(b[offset + 3])) << 24);
    }

    function store32(bytes memory b, uint256 offset, uint32 value) private pure {
        b[offset] = bytes1(uint8(value));
        b[offset + 1] = bytes1(uint8(value >> 8));
        b[offset + 2] = bytes1(uint8(value >> 16));
        b[offset + 3] = bytes1(uint8(value >> 24));
    }

    function slice(bytes memory data, uint256 start, uint256 len) private pure returns (bytes memory) {
        bytes memory result = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = data[start + i];
        }
        return result;
    }

    function compress(State memory S, bytes memory block_) private pure {
        uint32[16] memory m;
        uint32[16] memory v;

        for (uint256 i = 0; i < 16; i++) {
            m[i] = load32(block_, i * 4);
        }

        for (uint256 i = 0; i < 8; i++) {
            v[i] = S.h[i];
        }

        v[8] = IV0;
        v[9] = IV1;
        v[10] = IV2;
        v[11] = IV3;
        v[12] = S.t[0] ^ IV4;
        v[13] = S.t[1] ^ IV5;
        v[14] = S.f[0] ^ IV6;
        v[15] = S.f[1] ^ IV7;

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

        for (uint256 i = 0; i < 8; i++) {
            S.h[i] = S.h[i] ^ v[i] ^ v[i + 8];
        }
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

    function round(uint32[16] memory v, uint32[16] memory m, uint256 r) private pure {
        uint8[16][10] memory sigma = [
            [0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15],
            [14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3],
            [11,  8, 12,  0,  5,  2, 15, 13, 10, 14,  3,  6,  7,  1,  9,  4],
            [7,  9,  3,  1, 13, 12, 11, 14,  2,  6,  5, 10,  4,  0, 15,  8],
            [9,  0,  5,  7,  2,  4, 10, 15, 14,  1, 11, 12,  6,  8,  3, 13],
            [2, 12,  6, 10,  0, 11,  8,  3,  4, 13,  7,  5, 15, 14,  1,  9],
            [12,  5,  1, 15, 14, 13,  4, 10,  0,  7,  6,  3,  9,  2,  8, 11],
            [13, 11,  7, 14, 12,  1,  3,  9,  5,  0, 15,  4,  8,  6,  2, 10],
            [6, 15, 14,  9, 11,  3,  0,  8, 12,  2, 13,  7,  1,  4, 10,  5],
            [10,  2,  8,  4,  7,  6,  1,  5, 15, 11,  9, 14,  3, 12, 13,  0]
        ];

        G(v, m, 0, 4,  8, 12, m[sigma[r][0]],  m[sigma[r][1]]);
        G(v, m, 1, 5,  9, 13, m[sigma[r][2]],  m[sigma[r][3]]);
        G(v, m, 2, 6, 10, 14, m[sigma[r][4]],  m[sigma[r][5]]);
        G(v, m, 3, 7, 11, 15, m[sigma[r][6]],  m[sigma[r][7]]);
        G(v, m, 0, 5, 10, 15, m[sigma[r][8]],  m[sigma[r][9]]);
        G(v, m, 1, 6, 11, 12, m[sigma[r][10]], m[sigma[r][11]]);
        G(v, m, 2, 7,  8, 13, m[sigma[r][12]], m[sigma[r][13]]);
        G(v, m, 3, 4,  9, 14, m[sigma[r][14]], m[sigma[r][15]]);
    }
}

function blake2s(bytes memory input) pure returns (bytes32) {
    return Blake2s.hash(input);
}
