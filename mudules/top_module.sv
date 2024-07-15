
module top_module;

    // Shared local parameters
    localparam logic [7:0] CLK_DIVISION = 8'd14;
    localparam logic [7:0] AUDIO_WORD_LEN = 8'd24;
    localparam logic [7:0] AUDIO_FRAME_LEN = 8'd64;

    // Signals
    logic system_clk;
    logic reset_n;
    logic enable;
    logic bclk;
    logic lrclk;
    logic [AUDIO_WORD_LEN-1:0] tx_data;
    logic tx_serial_data;
    logic [AUDIO_WORD_LEN-1:0] tx_wave;
    logic rx_serial_data;
    logic [AUDIO_WORD_LEN-1:0] rx_data;
    logic rx_data_valid;

    // Clock generator instance
    clock_generator #(
        .CLK_DIVISION(CLK_DIVISION),
        .AUDIO_FRAME_LEN(AUDIO_FRAME_LEN)
    ) clock_gen_inst (
        .clk_i(system_clk),
        .rst_ni(reset_n),
        .enable_i(enable),
        .bclk_o(bclk),
        .lrclk_o(lrclk)
    );

    // I2S transmitter instance
    i2s_transmitter #(
        .CLK_DIVISION(CLK_DIVISION),
        .AUDIO_WORD_LEN(AUDIO_WORD_LEN),
        .AUDIO_FRAME_LEN(AUDIO_FRAME_LEN)
    ) tx (
        .clk_i(system_clk),
        .rst_ni(reset_n),
        .enable_i(enable),
        .audio_data_i(tx_data),
        .audio_data_o(tx_serial_data),
        .audio_lrclk_o(),  // Not connected, using clock_generator's lrclk
        .audio_bclk_o(),   // Not connected, using clock_generator's bclk
        .wave_o(tx_wave)
    );

    // I2S receiver instance
    i2s_receiver #(
        .CLK_DIVISION(CLK_DIVISION),
        .AUDIO_WORD_LEN(AUDIO_WORD_LEN),
        .AUDIO_FRAME_LEN(AUDIO_FRAME_LEN)
    ) rx (
        .clk_i(system_clk),
        .rst_ni(reset_n),
        .enable_i(enable),
        .audio_data_i(rx_serial_data),
        .audio_data_o(rx_data),
        .bclk_o(),         // Not connected, using clock_generator's bclk
        .lrclk_o(),        // Not connected, using clock_generator's lrclk
        .new_sample_o(rx_data_valid)
    );

    // You may want to add clock generation, reset logic, and other necessary logic here

endmodule