// ============================================================================
// aes_tb.v - Self-checking testbench for aes_core
// Validates against the official FIPS-197 Appendix B test vector:
//   Key:        000102030405060708090a0b0c0d0e0f
//   Plaintext:  00112233445566778899aabbccddeeff
//   Ciphertext: 69c4e0d86a7b0430d8cdb78070b4c55a
// ============================================================================
`timescale 1ns/1ps

module aes_tb;

    reg         clk;
    reg         rst_n;
    reg         start;
    reg  [127:0] key_in;
    reg  [127:0] plaintext_in;
    wire         done;
    wire [127:0] ciphertext_out;

    // Known-answer test vectors: {key, plaintext, expected_ciphertext}
    // Vector 0: FIPS-197 Appendix B
    // Vector 1: NIST SP 800-38A F.1.1 (all-zero key)
    // Vector 2: NIST SP 800-38A F.1.1 (all-zero key, all-ones plaintext)
    localparam NUM_VECTORS = 3;
    reg [127:0] test_keys        [0:NUM_VECTORS-1];
    reg [127:0] test_plaintexts  [0:NUM_VECTORS-1];
    reg [127:0] test_expected    [0:NUM_VECTORS-1];

    integer cycle_count;
    integer errors;
    integer i;

    aes_core dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start),
        .key_in         (key_in),
        .plaintext_in   (plaintext_in),
        .done           (done),
        .ciphertext_out (ciphertext_out)
    );

    // 100 MHz clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // cycle counter (for latency reporting), reset on rst_n deassertion
    always @(posedge clk) begin
        if (!rst_n)
            cycle_count <= 0;
        else if (start)
            cycle_count <= 1;
        else if (!done)
            cycle_count <= cycle_count + 1;
    end

    initial begin
        $dumpfile("aes_tb.vcd");
        $dumpvars(0, aes_tb);

        // Vector 0: FIPS-197 Appendix B
        test_keys[0]       = 128'h000102030405060708090a0b0c0d0e0f;
        test_plaintexts[0] = 128'h00112233445566778899aabbccddeeff;
        test_expected[0]   = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

        // Vector 1: NIST SP 800-38A F.1.1 ECB-AES128, block 1
        test_keys[1]       = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        test_plaintexts[1] = 128'h6bc1bee22e409f96e93d7e117393172a;
        test_expected[1]   = 128'h3ad77bb40d7a3660a89ecaf32466ef97;

        // Vector 2: NIST SP 800-38A F.1.1 ECB-AES128, block 2 (same key)
        test_keys[2]       = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        test_plaintexts[2] = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
        test_expected[2]   = 128'hf5d3d58503b9699de785895a96fdbaaf;

        errors       = 0;
        rst_n        = 1'b0;
        start        = 1'b0;
        key_in       = 128'd0;
        plaintext_in = 128'd0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        for (i = 0; i < NUM_VECTORS; i = i + 1) begin
            // Apply test vector
            key_in       = test_keys[i];
            plaintext_in = test_plaintexts[i];
            start        = 1'b1;
            @(posedge clk);
            start        = 1'b0;

            // Wait for done (timeout guards against a broken FSM hanging)
            fork : wait_done
                begin
                    wait (done === 1'b1);
                    disable wait_done;
                end
                begin
                    repeat (100) @(posedge clk);
                    $display("VECTOR %0d: TIMEOUT - 'done' never asserted", i);
                    errors = errors + 1;
                    disable wait_done;
                end
            join

            if (done) begin
                $display("--------------------------------------------------------");
                $display("Vector %0d finished in %0d cycles", i, cycle_count);
                $display("Key:        %h", test_keys[i]);
                $display("Plaintext:  %h", test_plaintexts[i]);
                $display("Ciphertext: %h", ciphertext_out);
                $display("Expected:   %h", test_expected[i]);
                if (ciphertext_out === test_expected[i]) begin
                    $display("RESULT: PASS");
                end else begin
                    $display("RESULT: FAIL - mismatch");
                    errors = errors + 1;
                end
                $display("--------------------------------------------------------");
            end

            @(posedge clk);
        end

        if (errors == 0)
            $display("TESTBENCH SUMMARY: ALL %0d TESTS PASSED", NUM_VECTORS);
        else
            $display("TESTBENCH SUMMARY: %0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
