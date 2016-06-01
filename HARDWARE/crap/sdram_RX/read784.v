// this reads 784 from addresses and copies to another 784 adddress

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


	localparam LAYER1_BASE = 32'd650_000;
	localparam TD_BASE = 32'd600_000;
	
	reg [15:0] data = 16'hDBAC;
	reg [3:0] state;
	reg [3:0] nextstate = 0;
	reg [31:0] addr = TD_BASE;
	reg [31:0] addw = LAYER1_BASE;
	reg [31:0] counter = 1;

	assign toHexLed = {counter,data,state};

	assign chipselect = 1;
	assign byteenable = 2'b11;

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
		counter <= counter;
		addr <= addr;
		addw <= addw;
		
		case(state)
			4'h0:
			begin
				counter <= 1;
				addr <= TD_BASE;
				addw <= LAYER1_BASE;
			end

			// Read request
			4'h1:
			begin

			end

			// Read request pt2
			4'h2:
			begin
				data <= (readdatavalid) ? readdata : data;
				addr <= (readdatavalid) ? addr + 2 : addr;
			end

			// Write request
			4'h3:
			begin
				addw <= (waitrequest) ? addw : addw + 2;
			end

			4'h4:
			begin
				counter <= counter + 1;
			end

			4'h5:
			begin
			end
		endcase
	end

	always @ (*)
	begin
		// state [7:0] <= nextstate [7:0];
		read_n <= 1;
		write_n <= 1;
		address <= address;

		case(state)
			// Wait for ready == 1
			4'h0:
			begin
				nextstate <= (ready) ? 1 : 0;
			end

			// Read request
			4'h1:
			begin
				read_n <= 0;
				address <= addr;
				nextstate <= (waitrequest) ? 1 : 2;
			end

			// Read request pt2
			4'h2:
			begin
				nextstate <= (readdatavalid) ? 3 : 2;
			end

			// Write Request
			4'h3:
			begin
				write_n <= 0;
				address <= addw;
				writedata <= data;
				nextstate <= (waitrequest) ? 3 : 4;
			end

			4'h4:
			begin
				nextstate <= (counter < 784) ? 1 : 5;
			end

			4'h5:
			begin
				done <= (ready) ? 1 : 0;
				nextstate <= (ready) ? 5 : 0;
			end
		endcase
	end

endmodule
