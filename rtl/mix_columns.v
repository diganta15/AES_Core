
module xtime (
    input  wire [7:0] a,
    output wire [7:0] y
);
    // Multiply by {02} in GF(2^8) with reduction poly x^8+x^4+x^3+x+1 (0x1b)
    assign y = a[7] ? (({a[6:0], 1'b0}) ^ 8'h1b) : {a[6:0], 1'b0};
endmodule

module mix_column (
    input  wire [31:0] col_in,   // {a0, a1, a2, a3} a0=row0 ... a3=row3
    output wire [31:0] col_out
);
    wire [7:0] a0 = col_in[31:24];
    wire [7:0] a1 = col_in[23:16];
    wire [7:0] a2 = col_in[15:8];
    wire [7:0] a3 = col_in[7:0];

    wire [7:0] x2a0, x2a1, x2a2, x2a3;
    xtime u_x0(.a(a0), .y(x2a0));
    xtime u_x1(.a(a1), .y(x2a1));
    xtime u_x2(.a(a2), .y(x2a2));
    xtime u_x3(.a(a3), .y(x2a3));

    // 3*a = 2*a XOR a
    wire [7:0] x3a0 = x2a0 ^ a0;
    wire [7:0] x3a1 = x2a1 ^ a1;
    wire [7:0] x3a2 = x2a2 ^ a2;
    wire [7:0] x3a3 = x2a3 ^ a3;

    wire [7:0] b0 = x2a0 ^ x3a1 ^ a2      ^ a3;
    wire [7:0] b1 = a0    ^ x2a1 ^ x3a2   ^ a3;
    wire [7:0] b2 = a0    ^ a1   ^ x2a2   ^ x3a3;
    wire [7:0] b3 = x3a0 ^ a1   ^ a2      ^ x2a3;

    assign col_out = {b0, b1, b2, b3};
endmodule

module mix_columns (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);
    // column c occupies bits [127-32c : 96-32c]
    mix_column u_c0(.col_in(state_in[127:96]), .col_out(state_out[127:96]));
    mix_column u_c1(.col_in(state_in[95:64]),  .col_out(state_out[95:64]));
    mix_column u_c2(.col_in(state_in[63:32]),  .col_out(state_out[63:32]));
    mix_column u_c3(.col_in(state_in[31:0]),   .col_out(state_out[31:0]));
endmodule
