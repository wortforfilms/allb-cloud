// ============================================================================
// Module:      fpga_top
// Description: prakriya_core behind an SPI mode 0 slave, for a microcontroller
//              master (maataa-os on a NUCLEO-F411RE: SPI2 PB13 SCK, PB14 MISO,
//              PB15 MOSI, PB12 CS as a GPIO, PC7 BUSY input).
//
// Protocol (protocol version 1). Every frame is one CS-low period. While the
// master clocks a frame out, the slave always sends the result block below
// from byte 0, so any frame also reads the result.
//
//   START frame (master -> FPGA), 3 + 2*ntok bytes:
//     0x01, ntok (1..12), flags, then per token: letter, attr
//       flags: bit 0 ghatadi, bits 2:1 pada_choice (prakriya_core)
//       letter: the 6-bit sound code of panini_defs.vh
//       attr:   bit 0 nasal, bits 2:1 accent (0 none, 1 anudatta, 2 svarita)
//     Checked when CS rises. A well-formed START while the core is idle
//     starts a derivation and clears the result; anything else that begins
//     with 0x01 sets the error bit and starts nothing.
//   READ frame: any other first byte (0x02 by convention); 49 bytes read the
//     whole result. Its bytes are ignored.
//
//   Result block (FPGA -> master), byte index:
//     0       status: bit 0 busy, bit 1 done, bit 2 more than 32 steps (the
//             rest were not kept), bit 3 the last START was refused,
//             bits 7:4 protocol version (1)
//     1       number of steps (saturates at 255)
//     2..33   steps in order: bits 4:0 the sutra id (step_rule), bits 6:5
//             the deciding principle (step_why); 0 after the last
//     34      length of the root text after the last step (snap_dlen)
//     35..46  its letters (snap_d), one 6-bit code a byte
//     47, 48  vikarana (snap_t1) and ending (snap_t2) after the last step
//     49..    0
//
// BUSY (to PC7) is high from an accepted START until the core is done; the
// master waits for it to fall (or polls status bit 0), then reads.
// The frame's tokens feed prakriya_core directly, so they must not change
// while it works: a frame that begins while the core is busy writes nothing
// (it still reads the result), and a START in it is refused.
// ============================================================================
`timescale 1ns / 1ps

module fpga_top #(
    parameter integer DMAX = 12,
    parameter integer TMAX = 12,
    parameter integer STEPS = 32
)(
    input  wire       clk,          // at least 8x SCLK
    input  wire       rst_n,
    input  wire       spi_sclk,
    input  wire       spi_cs_n,
    input  wire       spi_mosi,
    output wire       spi_miso,
    output wire       busy_out,
    output wire [2:0] leds          // busy, done, error (active high)
);
    localparam [7:0] CMD_START = 8'h01;
    localparam [3:0] VERSION   = 4'd1;

    // ------------------------------------------------------------------ SPI
    wire       frame_start, frame_end, rx_valid;
    wire [7:0] rx_byte, rx_count, tx_idx;
    reg  [7:0] tx_byte;
    spi_slave spi (
        .clk(clk), .rst_n(rst_n),
        .spi_sclk(spi_sclk), .spi_cs_n(spi_cs_n), .spi_mosi(spi_mosi), .spi_miso(spi_miso),
        .frame_start(frame_start), .frame_end(frame_end),
        .rx_valid(rx_valid), .rx_byte(rx_byte), .rx_count(rx_count),
        .tx_idx(tx_idx), .tx_byte(tx_byte)
    );

    // ------------------------------------------------------------------ frame
    reg              running;
    reg              locked;        // this frame began while the core was busy
    reg [7:0]        cmd;
    reg [3:0]        f_ntok;
    reg [2:0]        f_flags;
    reg [TMAX*6-1:0] f_letter;
    reg [TMAX-1:0]   f_nasal;
    reg [TMAX*2-1:0] f_accent;
    integer          tk;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            locked <= 1'b0; cmd <= 8'd0; f_ntok <= 4'd0; f_flags <= 3'd0;
            f_letter <= 0; f_nasal <= 0; f_accent <= 0;
        end else if (frame_start) begin
            locked <= running;
        end else if (rx_valid && rx_count == 8'd1) begin
            cmd <= rx_byte;
        end else if (rx_valid && !locked) begin
            // rx_count already counts this byte: 1 is the command.
            if (rx_count == 8'd2) f_ntok <= rx_byte[3:0];
            else if (rx_count == 8'd3) f_flags <= rx_byte[2:0];
            else if (rx_count >= 8'd4 && rx_count < 8'd4 + 2*TMAX) begin
                tk = (rx_count - 8'd4) >> 1;
                if (rx_count[0] == 1'b0) f_letter[tk*6 +: 6] <= rx_byte[5:0];
                else begin
                    f_nasal[tk]        <= rx_byte[0];
                    f_accent[tk*2 +: 2] <= rx_byte[2:1];
                end
            end
        end
    end
    wire well_formed = f_ntok >= 4'd1 && f_ntok <= TMAX && rx_count == 8'd3 + {f_ntok, 1'b0};

    // ------------------------------------------------------------------ core
    reg              start;
    wire             step_valid, core_busy, core_done;
    wire [4:0]       step_rule;
    wire [1:0]       step_why, snap_t1;
    wire [2:0]       snap_t2;
    wire [3:0]       snap_dlen;
    wire [DMAX*6-1:0] snap_d;
    prakriya_core #(.DMAX(DMAX), .TMAX(TMAX)) core (
        .clk(clk), .rst_n(rst_n), .start(start),
        .ntok(f_ntok), .tok_letter(f_letter), .tok_nasal(f_nasal), .tok_accent(f_accent),
        .ghatadi(f_flags[0]), .pada_choice(f_flags[2:1]),
        .step_valid(step_valid), .step_rule(step_rule), .step_why(step_why),
        .snap_dlen(snap_dlen), .snap_d(snap_d), .snap_t1(snap_t1), .snap_t2(snap_t2),
        .busy(core_busy), .done(core_done)
    );

    // ------------------------------------------------------------------ control and result
    reg              done_f, overflow, error;
    reg [7:0]        nsteps;
    reg [6:0]        steps [0:STEPS-1];
    reg [3:0]        r_dlen;
    reg [DMAX*6-1:0] r_d;
    reg [1:0]        r_t1;
    reg [2:0]        r_t2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start <= 1'b0; running <= 1'b0; done_f <= 1'b0; overflow <= 1'b0; error <= 1'b0;
            nsteps <= 8'd0; r_dlen <= 4'd0; r_d <= 0; r_t1 <= 2'd0; r_t2 <= 3'd0;
        end else begin
            start <= 1'b0;
            if (frame_end && cmd == CMD_START) begin
                if (well_formed && !locked && !running) begin
                    start <= 1'b1; running <= 1'b1;
                    done_f <= 1'b0; overflow <= 1'b0; error <= 1'b0; nsteps <= 8'd0;
                    r_dlen <= 4'd0; r_d <= 0; r_t1 <= 2'd0; r_t2 <= 3'd0;
                end else begin
                    error <= 1'b1;
                end
            end
            if (step_valid && running) begin
                if (nsteps >= STEPS) overflow <= 1'b1;
                if (nsteps != 8'hFF) nsteps <= nsteps + 8'd1;
                r_dlen <= snap_dlen; r_d <= snap_d; r_t1 <= snap_t1; r_t2 <= snap_t2;
            end
            if (core_done && running) begin
                running <= 1'b0; done_f <= 1'b1;
            end
        end
    end

    always @(posedge clk)
        if (step_valid && running && nsteps < STEPS) steps[nsteps[4:0]] <= {step_why, step_rule};

    // Steps are read from block RAM one clk after tx_idx is set. tx_idx stays
    // the same for a whole byte (spi_slave samples tx_byte at its 8th rising
    // edge), so the registered read is ready long before it is used. Only
    // index 0 (status) is read in the same clk, when CS falls.
    reg [6:0] step_q;
    always @(posedge clk) step_q <= steps[tx_idx[4:0] - 5'd2];

    // The result block, read by byte index.
    always @* begin
        if (tx_idx == 8'd0)
            tx_byte = {VERSION, error, overflow, done_f, running};
        else if (tx_idx == 8'd1)
            tx_byte = nsteps;
        else if (tx_idx >= 8'd2 && tx_idx < 8'd2 + STEPS)
            tx_byte = (tx_idx - 8'd2 < nsteps) ? {1'b0, step_q} : 8'd0;
        else if (tx_idx == 8'd2 + STEPS)
            tx_byte = {4'd0, r_dlen};
        else if (tx_idx >= 8'd3 + STEPS && tx_idx < 8'd3 + STEPS + DMAX)
            tx_byte = {2'b00, r_d[(tx_idx - 8'd3 - STEPS)*6 +: 6]};
        else if (tx_idx == 8'd3 + STEPS + DMAX)
            tx_byte = {6'd0, r_t1};
        else if (tx_idx == 8'd4 + STEPS + DMAX)
            tx_byte = {5'd0, r_t2};
        else
            tx_byte = 8'd0;
    end

    assign busy_out = running;
    assign leds     = {error, done_f, running};
endmodule
