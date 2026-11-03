// ============================================================================
// Testbench: tb_fpga_top
// Drives fpga_top the way the microcontroller will: SPI mode 0 at clk/8 (the
// slowest clk the slave allows), one START frame per form of the reference
// slice (vectors/prakriya_ref.mem), wait for BUSY to fall, then a 49-byte READ
// frame. Every form must come back with the reference's step list (sutra
// and deciding principle) and its final state (root text, vikarana, ending).
// Also: malformed and cut-short STARTs are refused (error bit), and the
// next good START clears it. (A START
// while the core works cannot be timed from here: a derivation takes fewer
// clks than the shortest START frame; fpga_top refuses it the same way.)
// ============================================================================
`timescale 1ns / 1ps
`include "panini_defs.vh"
`include "vectors/prakriya_counts.vh"

module tb_fpga_top;
    localparam integer DMAX = 12, TMAX = 12, SMAX = 26, SW = 17, IN = 1 + TMAX*3 + 2, WORDS = IN + 1 + SMAX*SW;
    localparam integer HALF = 40;          // SCLK half period: 4 clk of 10 ns, so SCLK = clk/8
    localparam integer RESULT = 49;

    reg clk = 0, rst_n = 0, sclk = 0, cs_n = 1, mosi = 0;
    wire miso, busy; wire [2:0] leds;
    fpga_top dut (.clk(clk), .rst_n(rst_n), .spi_sclk(sclk), .spi_cs_n(cs_n), .spi_mosi(mosi),
                  .spi_miso(miso), .busy_out(busy), .leds(leds));
    always #5 clk = ~clk;

    reg [31:0] mem [0:`PRAKRIYA_FORMS*WORDS-1];
    reg [7:0] tx [0:63];
    reg [7:0] rx [0:63];
    integer f, k, n, b, sb, last, nsteps, errors = 0, bad_forms = 0, total = 0;
    reg bad;

    // One frame of n bytes: tx[] out on MOSI, MISO into rx[]. Mode 0: data
    // changes on the falling edge, both sides sample on the rising edge.
    task frame(input integer len);
        integer i, j;
        begin
            cs_n = 0; #(HALF * 2);
            for (i = 0; i < len; i = i + 1) begin
                for (j = 7; j >= 0; j = j - 1) begin
                    mosi = tx[i][j];
                    #HALF sclk = 1; rx[i][j] = miso;
                    #HALF sclk = 0;
                end
            end
            #(HALF * 2) cs_n = 1; #(HALF * 4);
        end
    endtask

    task start_form(input integer form);
        integer q;
        begin
            q = form * WORDS;
            tx[0] = 8'h01; tx[1] = mem[q][3:0];
            tx[2] = {5'd0, mem[q+2+TMAX*3][1:0], mem[q+1+TMAX*3][0]};
            for (k = 0; k < mem[q][3:0]; k = k + 1) begin
                tx[3 + 2*k] = {2'b00, mem[q+1+k*3][5:0]};
                tx[4 + 2*k] = {5'd0, mem[q+3+k*3][1:0], mem[q+2+k*3][0]};
            end
            frame(3 + 2 * mem[q][3:0]);
        end
    endtask

    task read_result;
        begin
            for (k = 0; k < RESULT; k = k + 1) tx[k] = (k == 0) ? 8'h02 : 8'h00;
            frame(RESULT);
        end
    endtask

    initial begin
        $readmemh("vectors/prakriya_ref.mem", mem);
        #100 rst_n = 1; #100;

        for (f = 0; f < `PRAKRIYA_FORMS; f = f + 1) begin
            b = f * WORDS;
            nsteps = mem[b+IN];
            start_form(f);
            if (!busy) begin $display("FAIL form %0d: BUSY did not rise after START", f); bad_forms = bad_forms + 1; end
            n = 0;
            while (busy && n < 2000) begin @(posedge clk); n = n + 1; end
            read_result;
            bad = 0;
            if (rx[0][7:4] != 4'd1 || rx[0][0] || !rx[0][1] || rx[0][2]) bad = 1;
            if (rx[0][3]) bad = 1;
            if (rx[1] != nsteps) bad = 1;
            for (k = 0; k < nsteps; k = k + 1) begin
                sb = b + IN + 1 + k * SW;
                if (rx[2+k][4:0] !== mem[sb][4:0] || rx[2+k][6:5] !== mem[sb+1][1:0]) bad = 1;
            end
            last = b + IN + 1 + (nsteps - 1) * SW;
            if (rx[34][3:0] !== mem[last+2][3:0] || rx[47][1:0] !== mem[last+15][1:0] || rx[48][2:0] !== mem[last+16][2:0]) bad = 1;
            for (k = 0; k < DMAX; k = k + 1) if (k < mem[last+2][3:0] && rx[35+k][5:0] !== mem[last+3+k][5:0]) bad = 1;
            if (bad) begin
                bad_forms = bad_forms + 1;
                if (bad_forms <= 5)
                    $display("FAIL form %0d: status %h, %0d steps (want %0d), first step %h", f, rx[0], rx[1], nsteps, rx[2]);
            end
            total = total + nsteps;
        end

        // A malformed START (ntok 0) is refused.
        tx[0] = 8'h01; tx[1] = 8'd0; tx[2] = 8'd0; frame(3);
        read_result;
        if (!rx[0][3] || busy) begin $display("FAIL: malformed START not refused (status %h)", rx[0]); errors = errors + 1; end
        // A START cut short (fewer token bytes than ntok) is refused.
        tx[0] = 8'h01; tx[1] = 8'd3; tx[2] = 8'd0; tx[3] = 8'd1; frame(4);
        if (busy) begin $display("FAIL: short START accepted"); errors = errors + 1; end
        // The next good START is accepted and clears the error bit.
        start_form(0);
        n = 0; while (busy && n < 2000) begin @(posedge clk); n = n + 1; end
        read_result;
        if (rx[0][3] || !rx[0][1] || rx[1] != mem[IN]) begin $display("FAIL: good START after an error (status %h)", rx[0]); errors = errors + 1; end

        $display("FPGA top over SPI: %0d of %0d forms agree (%0d steps), %0d protocol errors",
                 `PRAKRIYA_FORMS - bad_forms, `PRAKRIYA_FORMS, total, errors);
        if (bad_forms || errors) $fatal(1, "FPGA TOP: FAIL");
        $display("FPGA TOP: PASS");
        $finish;
    end
endmodule
