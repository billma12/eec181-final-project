module sdram_read_write(
input clk,
input reset_n,
input waitrequest,
input readdatavalid,
input [15:0] readdata,

output chipselect,
output [1:0] byteenable,
output reg read_n,
output reg write_n,

output reg [15:0] writedata,
output reg [31:0] address,

input ready,
output reg done,
output [31:0] toHexLed
);

   assign byteenable = 2'b11;
	assign chipselect = 1'b1;
	
	reg [3:0]  state     = 0;
	reg [11:0] step      = 0;
	//reg [23:0] cycle     = 0;
	reg [15:0] counter    = 0;
	reg [8:0] other     = 8'h12;
	reg [15:0] cur_value = 16'h0001;
	reg [3:0]  readcount = 4'd0;
	
	assign toHexLed = {other,readcount,cur_value,state};
	
	//localparam SECOND =  50_000_000;
	//localparam START  =  16'hFFFF;
	
	localparam IDLE       = 0;
	localparam READ       = 1;
	localparam LOAD       = 2;
	localparam WRITE      = 3;
	localparam COUNT      = 4;
	localparam DONE       = 5;
	localparam CHECK      = 6;
	
	reg [31:0] read_adr  = 32'd10;
	reg [31:0] write_adr = 32'd100;

	
	//Next state logic
	always@(posedge clk)
	begin
		if (!reset_n)
			state <= IDLE;
		else
		begin
			case(state)
				IDLE:       state <= (ready)               ? READ  : IDLE;
				READ:       state <= (waitrequest == 0)    ? WRITE : READ;
				LOAD:       state <= (readdatavalid == 1)  ? WRITE : LOAD; 
				WRITE:      state <= (waitrequest == 0)    ? CHECK : WRITE;
				//COUNT:      state <=  CHECK;
				CHECK:      state <= (readcount == 4'd10)  ? DONE  : READ;
				DONE:       state <= (~ready)              ? IDLE  : DONE;
				default:    state <= IDLE;
			endcase
		end
	end
	
	//outputs
	always@(posedge clk)
	begin
		case(state)
			IDLE: 
			begin 
				read_n  <= 1;
				write_n <= 1;
				done    <= 0;
			end
			READ:
			begin
				address     <= read_adr ;
				read_n      <= 0;
			end
			WRITE:
			begin
				address    <= write_adr;
				read_n     <= 1;
				write_n    <= 0;
				writedata  <= cur_value;
			end
			DONE:
			begin
				done      <= 1;
				write_n   <= 1;
				read_n    <= 1;
			end
		endcase
	end
	
	//update regs and addresses
	always @ (posedge clk) 
	begin
		//update addresses
		read_adr  <= (state == LOAD  && readdatavalid) ? read_adr + 2 : read_adr;
		write_adr <= (state == WRITE && waitrequest)   ? write_adr + 2 : write_adr;

		//count how many times we read
		if ((state == LOAD) && readdatavalid) begin
			readcount <= readcount + 1;
			end
		else if (state == DONE) begin
			readcount <= 0;
			end
		else begin
			readcount <= readcount;
			end
		
		//load readdata when readdatavalid = 1
		cur_value <= (readdatavalid && (state == LOAD)) ? readdata : cur_value;
	end
	

endmodule
