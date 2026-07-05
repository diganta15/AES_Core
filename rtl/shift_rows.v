module shift_rows (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);
    // Helper: extract byte b (0..15) from a 128-bit state vector
    `define BYTE(vec, b) vec[127 - (b)*8 -: 8]

    // Row 0 (bytes 0,4,8,12) - unchanged
    assign `BYTE(state_out, 0)  = `BYTE(state_in, 0);
    assign `BYTE(state_out, 4)  = `BYTE(state_in, 4);
    assign `BYTE(state_out, 8)  = `BYTE(state_in, 8);
    assign `BYTE(state_out, 12) = `BYTE(state_in, 12);

    // Row 1 (bytes 1,5,9,13) - shift left 1: new(c) = old(c+1 mod 4)
    assign `BYTE(state_out, 1)  = `BYTE(state_in, 5);
    assign `BYTE(state_out, 5)  = `BYTE(state_in, 9);
    assign `BYTE(state_out, 9)  = `BYTE(state_in, 13);
    assign `BYTE(state_out, 13) = `BYTE(state_in, 1);

    // Row 2 (bytes 2,6,10,14) - shift left 2
    assign `BYTE(state_out, 2)  = `BYTE(state_in, 10);
    assign `BYTE(state_out, 6)  = `BYTE(state_in, 14);
    assign `BYTE(state_out, 10) = `BYTE(state_in, 2);
    assign `BYTE(state_out, 14) = `BYTE(state_in, 6);

    // Row 3 (bytes 3,7,11,15) - shift left 3
    assign `BYTE(state_out, 3)  = `BYTE(state_in, 15);
    assign `BYTE(state_out, 7)  = `BYTE(state_in, 3);
    assign `BYTE(state_out, 11) = `BYTE(state_in, 7);
    assign `BYTE(state_out, 15) = `BYTE(state_in, 11);

    `undef BYTE
endmodule