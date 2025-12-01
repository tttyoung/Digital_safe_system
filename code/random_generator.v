module random_generator(
    input wire clk,
    input wire rst_n,
    input wire load_seed,       // 버튼 누를 때 High
    input wire [15:0] seed_val, // Top에서 계속 도는 카운터 값
    
    output reg [3:0] d1, // 천의 자리
    output reg [3:0] d2, // 백의 자리
    output reg [3:0] d3, // 십의 자리
    output reg [3:0] d4  // 일의 자리
);

    reg [15:0] lfsr_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_reg <= 16'h1234; // 초기값
        end else if (load_seed) begin
            // 시드값이 0이면 1로 강제 변환 (Lock-up 방지)
            lfsr_reg <= (seed_val == 0) ? 16'h1 : seed_val;
        end else begin
            // 16-bit Galois LFSR
            lfsr_reg[15] <= lfsr_reg[14];
            lfsr_reg[14] <= lfsr_reg[13] ^ lfsr_reg[15];
            lfsr_reg[13] <= lfsr_reg[12] ^ lfsr_reg[15];
            lfsr_reg[12] <= lfsr_reg[11];
            lfsr_reg[11] <= lfsr_reg[10] ^ lfsr_reg[15];
            lfsr_reg[10] <= lfsr_reg[9];
            lfsr_reg[9:0] <= {lfsr_reg[8:0], lfsr_reg[15]};
        end
    end

    // 출력 분배 (Combinational Logic)
    always @(*) begin
        d1 = lfsr_reg[15:12] % 10;
        d2 = lfsr_reg[11:8]  % 10;
        d3 = lfsr_reg[7:4]   % 10;
        d4 = lfsr_reg[3:0]   % 10;
    end
endmodule