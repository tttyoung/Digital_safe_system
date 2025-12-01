module cal_result(
    // 1. 난수 입력 (4자리)
    input wire [3:0] d1, // 천의 자리 (제일 왼쪽)
    input wire [3:0] d2,
    input wire [3:0] d3,
    input wire [3:0] d4, // 일의 자리 (제일 오른쪽)

    // 2. 연산자 입력 (관리자 모드에서 올 신호 -> 지금은 임의로 넣을 예정)
    input wire op1, // 첫 번째 연산자 (d1 ? d2) : 0이면 +, 1이면 *
    input wire op2, // 두 번째 연산자 (Res ? d3)
    input wire op3, // 세 번째 연산자 (Res ? d4)

    // 3. 최종 정답 출력
    output reg [15:0] correct_ans // 최대 9*9*9*9=6561 이므로 16비트면 충분
);

    // 중간 계산 과정을 저장할 변수들
    reg [15:0] step1_res; // (d1 op1 d2) 결과
    reg [15:0] step2_res; // (step1 op2 d3) 결과

    always @(*) begin
        // d1과 d2 연산 - op1
        if (op1 == 1'b0) step1_res = d1 + d2;      // 덧셈
        else             step1_res = d1 * d2;      // 곱셈

        //  step1_res와 d3 연산 - op2
        if (op2 == 1'b0) step2_res = step1_res + d3;
        else             step2_res = step1_res * d3;

        // step2_res와 d4 연산 - op3
        if (op3 == 1'b0) correct_ans = step2_res + d4;
        else             correct_ans = step2_res * d4;
    end


endmodule
