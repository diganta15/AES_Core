module key_expand (
    input  wire [127:0] round_key_in,
    input  wire [7:0]   rcon,
    output wire [127:0] round_key_out
);
    wire [31:0] w0 = round_key_in[127:96];
    wire [31:0] w1 = round_key_in[95:64];
    wire [31:0] w2 = round_key_in[63:32];
    wire [31:0] w3 = round_key_in[31:0];

    // RotWord: {b0,b1,b2,b3} -> {b1,b2,b3,b0}
    wire [31:0] rot_w3 = {w3[23:0], w3[31:24]};

    // SubWord: apply S-box to each byte of rot_w3
    wire [7:0] sb0, sb1, sb2, sb3;
    sbox u_sb0(.in_byte(rot_w3[31:24]), .out_byte(sb0));
    sbox u_sb1(.in_byte(rot_w3[23:16]), .out_byte(sb1));
    sbox u_sb2(.in_byte(rot_w3[15:8]),  .out_byte(sb2));
    sbox u_sb3(.in_byte(rot_w3[7:0]),   .out_byte(sb3));

    wire [31:0] sub_rot_w3 = {sb0, sb1, sb2, sb3};

    wire [31:0] temp = sub_rot_w3 ^ {rcon, 24'h000000};

    wire [31:0] w0_n = w0 ^ temp;
    wire [31:0] w1_n = w1 ^ w0_n;
    wire [31:0] w2_n = w2 ^ w1_n;
    wire [31:0] w3_n = w3 ^ w2_n;

    assign round_key_out = {w0_n, w1_n, w2_n, w3_n};
endmodule
