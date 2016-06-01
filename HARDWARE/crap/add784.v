module add_784(
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

	reg [3:0] state;
	reg [3:0] nextstate = 0;
	
	reg [31:0] addr = 600_000;
	reg [31:0] addw = 650_000;
	reg [31:0] addr_w1 = 800;

	reg [15:0] total = 1;
	reg [15:0] data = 16'hABCD;
	reg [15:0] data_w1 = 16'hABCD;
	
	reg [31:0] counter = 1;

	localparam IDLE = 0;
	localparam READ_IMG = 1;
	localparam WAIT_IMG = 2;
	localparam ADD = 3;
	localparam WRITE_TO_L1 = 4;
	localparam CONT_IMG = 5;
	localparam DONE = 6;
	localparam READ_W1 = 7;
	localparam WAIT_W1 = 8;
	localparam CONT_W1 = 9;
	localparam CONT_L1 = 10;
	localparam STORE_IMG = 11;
	localparam WRITE = 12;
	localparam READ = 13;
	localparam WAIT = 14;
	localparam CONT = 15;
	
	
	
	assign toHexLed = {data_w1,data[3:0],state};

	assign chipselect = 1;
	assign byteenable = 2'b11;

	localparam base_img = 32'd600_000;
	localparam base_layer1 = 32'd650_000;
	localparam base_weight1 = 32'd800;
	
	always @ (posedge clk)
	begin
		state <= nextstate;
		if(reset_n == 0)
		begin
			state <= 0;
		end
	end

	always @ (posedge clk)
	begin
		//counter <= counter;
		//addr <= addr;
		//addw <= addw;
		
		case(state)
			IDLE:
			begin
				counter <= 1;
				addr <= base_img;
				addw <= base_layer1;
				addr_w1 <= base_weight1;
				total <= 0;
			end

			// Read request
			READ:
			begin

			end

			// Read request pt2
			WAIT:
			begin
				data <= (readdatavalid) ? readdata : data;
				addr <= (readdatavalid) ? addr + 2 : addr;
			end

			// Write request
			WRITE:
			begin
				writedata <= total;
				addw <= (waitrequest) ? addw : addw + 2;
			end

			ADD:
			begin
				total <= (1) ? data + total : total;
			end
			
			CONT:
			begin
				counter <= counter + 1;
			end

			DONE:
			begin
			end
		endcase
	end

	always @ (*)
	begin
		//read_n <= 1;
		//write_n <= 1;
		//address <= address;

		case(state)
			// Wait for ready == 1
			IDLE:
			begin
				read_n <= 1;
				write_n <= 1;
				nextstate <= (ready) ? READ : IDLE;
			end

			// Read request
			READ:
			begin
				read_n <= 0;
				write_n <= 1;
				address <= addr;
				nextstate <= (!waitrequest) ? WAIT : READ;
			end

			// Read request pt2
			WAIT:
			begin
				nextstate <= (readdatavalid) ? ADD : WAIT;
			end

			ADD:
			
			begin
				nextstate <= CONT;
			end
			
			// Write Request
			WRITE:
			begin
				write_n <= 0;
				read_n <= 1;
				address <= addw;
				nextstate <= (!waitrequest) ?  DONE : WRITE;
			end

			CONT:
			begin
				nextstate <= (counter < 784) ? READ : WRITE;
			end

			DONE:
			begin
				done <= (ready) ? 1 : 0;
				nextstate <= (ready) ? DONE : IDLE;
			end
		endcase
	end

endmodule

