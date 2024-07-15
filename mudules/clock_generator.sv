module clock_generator #(
    parameter logic [7:0] CLK_CLK_DIVISION = 8'd14,
    parameter logic [7:0] CLK_AUDIO_FRAME_LEN = 8'd64
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic enable_i,
    output logic bclk_o,
    output logic lrclk_o
);
    localparam logic [7:0] BCLK_CNTR_HALF_CC = CLK_CLK_DIVISION/2 - 1;
    localparam logic [7:0] BCLK_CNTR_FULL_CC = BCLK_CNTR_HALF_CC * 2 + 1;
    localparam logic [7:0] AUDIO_FRAME_CNTR_HALF = CLK_AUDIO_FRAME_LEN/2 - 1;

    logic [7:0] elapsed_cycles;
    logic [7:0] frame_cntr;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            elapsed_cycles <= BCLK_CNTR_FULL_CC;
            bclk_o <= 1'b0;
            frame_cntr <= AUDIO_FRAME_CNTR_HALF;
            lrclk_o <= 1'b1;
        end else if (enable_i) begin
            elapsed_cycles <= elapsed_cycles - 1;

            if (elapsed_cycles <= 0) begin
                bclk_o <= ~bclk_o;
                elapsed_cycles <= BCLK_CNTR_HALF_CC;

                if (bclk_o) begin
                    frame_cntr <= frame_cntr - 1;
                    if (frame_cntr == 0) begin
                        lrclk_o <= ~lrclk_o;
                        frame_cntr <= AUDIO_FRAME_CNTR_HALF;
                    end
                end
            end
        end
    end
endmodule