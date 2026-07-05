module aes_core (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [127:0] key_in,
    input  wire [127:0] plaintext_in,
    output reg          done,
    output reg  [127:0] ciphertext_out
);


    localparam S_IDLE  = 2'd0;
    localparam S_ROUND = 2'd1;
    localparam S_DONE  = 2'd2;

    reg  [1:0]   state;
    reg  [127:0] state_reg;   // current AES state (data)
    reg  [127:0] key_reg;     // current round key
    reg  [7:0]   rcon_reg;    // current round constant
    reg  [3:0]   round_cnt;   // which round we are about to perform (1..10)


        // ---------------- Combinational datapath ----------------
    wire [127:0] sub_bytes_out;
    wire [127:0] shift_rows_out;
    wire [127:0] mix_columns_out;
    wire [127:0] next_key;
    wire [7:0]   next_rcon;

    sub_bytes u_sub_bytes (
        .state_in  (state_reg),
        .state_out (sub_bytes_out)
    );

    shift_rows u_shift_rows (
        .state_in  (sub_bytes_out),
        .state_out (shift_rows_out)
    );

    mix_columns u_mix_columns (
        .state_in  (shift_rows_out),
        .state_out (mix_columns_out)
    );

    key_expand u_key_expand (
        .round_key_in  (key_reg),
        .rcon          (rcon_reg),
        .round_key_out (next_key)
    );

    xtime u_rcon_xtime (
        .a (rcon_reg),
        .y (next_rcon)
    );


    // Result if this is a main round (1-9): MixColumns included
    wire [127:0] main_round_result  = mix_columns_out  ^ next_key;
    // Result if this is the final round (10): MixColumns skipped
    wire [127:0] final_round_result = shift_rows_out    ^ next_key;

    wire is_final_round = (round_cnt == 4'd10);

    // ---------------- FSM ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_IDLE;
            state_reg      <= 128'd0;
            key_reg        <= 128'd0;
            rcon_reg       <= 8'h01;
            round_cnt      <= 4'd0;
            done           <= 1'b0;
            ciphertext_out <= 128'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initial AddRoundKey (round 0) done here combinationally
                        state_reg <= plaintext_in ^ key_in;
                        key_reg   <= key_in;
                        rcon_reg  <= 8'h01;
                        round_cnt <= 4'd1;
                        state     <= S_ROUND;
                    end
                end

                S_ROUND: begin
                    key_reg  <= next_key;
                    rcon_reg <= next_rcon;
                    if (is_final_round) begin
                        state_reg <= final_round_result;
                        state     <= S_DONE;
                    end else begin
                        state_reg <= main_round_result;
                        round_cnt <= round_cnt + 4'd1;
                    end
                end

                S_DONE: begin
                    ciphertext_out <= state_reg;
                    done           <= 1'b1;
                    state          <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
