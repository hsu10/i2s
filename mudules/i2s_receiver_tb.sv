`timescale 1ps / 1ps

module i2s_receiver_tb;
  // 实例化被测单元
  localparam  CLK_DIVISION = 8'd14;
  localparam  AUDIO_WORD_LEN = 8'd24;
  localparam  AUDIO_FRAME_LEN = 8'd64;

  logic clk;
  logic rst_n;

  // 时钟生成
  localparam CLK_PERIOD = 25000;  // 25000 ps = 25 ns = 40 MHz
  initial begin
    clk = 0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  // 被测单元（UUT）接口
  logic enable;
  logic audio_data_i;
  logic [23:0] audio_data_o;
  wire bclk_o, lrclk_o;
  logic new_sample_o;

  i2s_receiver #(
    .I2S_CLK_DIVISION(CLK_DIVISION),
    .I2S_AUDIO_FRAME_LEN(AUDIO_FRAME_LEN),
    .I2S_AUDIO_WORD_LEN(AUDIO_WORD_LEN)
  )
  UUT (
      .clk_i(clk),
      .rst_ni(rst_n),
      .enable_i(enable),
      .audio_data_i(audio_data_i),
      .audio_data_o(audio_data_o),
      .bclk_o(bclk_o),
      .lrclk_o(lrclk_o),
      .new_sample_o(new_sample_o)
  );

  clock_generator  #(
    .CLK_CLK_DIVISION(CLK_DIVISION),
    .CLK_AUDIO_FRAME_LEN(AUDIO_FRAME_LEN)
  ) clock_gen_inst (
      .clk_i(clk),
      .rst_ni(rst_n),
      .enable_i(enable),
      .bclk_o(bclk_o),
      .lrclk_o(lrclk_o)
  );

  // 文件描述符和测试数据
  int fd;
  logic [23:0] test_data;
  int error_count;
  bit main_lrclk;

  // 记录器任务
  task logger(input string line);
    $display(line);
    $fdisplay(fd, line);
  endtask


  task automatic send_data(input [23:0] send_data);
    fork
      begin
        test_data = send_data;
        logger($sformatf("Sending data: %b", test_data));

        // Capture the initial state of lrclk_o
        //     initial_lrclk = lrclk_o;

        // Wait for lrclk_o to change (beginning of new frame)
        //    @(lrclk_o !== initial_lrclk);
        //    initial_lrclk=lrclk_o;
        // Send data
        for (int i = 23; i >= 0; i--) begin
          if (lrclk_o == main_lrclk || i == 0) begin
            @(negedge bclk_o);
            audio_data_i = test_data[i];
          end //otherwise end early!
            else begin
            //$display("Error: LRCLK changed before sending all data");
            logger("Error: LRCLK changed before sending all data");
            break;
          end
        end

        logger("Finished sending data");
      end
    join_none
  endtask
  // Task to check received data
  task check_data(input [23:0] expected_data);
    fork
      begin
        @(posedge new_sample_o);

        if (audio_data_o !== expected_data) begin
          logger($sformatf("Error: Expected %b, Got %b", expected_data, audio_data_o));
          error_count++;
        end else begin
          logger($sformatf("Success: Correctly received %b", audio_data_o));
        end
      end
    join_none
  endtask

  initial begin
    fd = $fopen("i2s_receiver_tb.log", "w");
    logger("----- I2S RECEIVER TESTBENCH -----");

    // 初始化和复位
    enable = 0;
    rst_n = 0;
    audio_data_i = 0;
    error_count = 0;
    #1000ps;
    rst_n  = 1;
    enable = 1;
    #1000ps;
    main_lrclk = lrclk_o;

    @(main_lrclk !== lrclk_o);
    main_lrclk = lrclk_o;
    send_data(24'b0010_0000_1111_0011_1111_1111);
    @(main_lrclk !== lrclk_o);
    main_lrclk = lrclk_o;
    check_data(24'b0010_0000_1111_0011_1111_1111);
    send_data(24'b0010_0000_1111_0011_1111_1011);
    @(main_lrclk !== lrclk_o);
    main_lrclk = lrclk_o;
    check_data(24'b0010_0000_1111_0011_1111_1011);
    send_data(24'b0010_0000_1111_0011_1111_0111);
    @(main_lrclk !== lrclk_o);
    main_lrclk = lrclk_o;
    check_data(24'b0010_0000_1111_0011_1111_0111);
    #20us;
    if (error_count == 0) begin
      logger("All tests PASSED");
    end else begin
      logger($sformatf("Tests FAILED with %d errors", error_count));
    end

    $fclose(fd);
    $finish;




  end

endmodule
