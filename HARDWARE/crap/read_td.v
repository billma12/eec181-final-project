module read_td(
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



	reg [15:0] data = 16'hABCD;
	reg [7:0] state;
	reg [7:0] nextstate = 0;
	reg [31:0] addr = 600_000;
	reg [31:0] addw = 650_000;
	reg [31:0] counter = 1;

	assign toHexLed = {counter,data,state};

	assign chipselect = 1;
	assign byteenable = 2'b11;

	localparam base_img = 32'd600_000;
	localparam base_layer1 = 32'd650_000;
	
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
			8'h0:
			begin
				counter <= 1;
				addr <= base_img;
				addw <= base_layer1;
			end

			// Read request
			8'h1:
			begin

			end

			// Read request pt2
			8'h2:
			begin
				data <= (readdatavalid) ? readdata : data;
				addr <= (readdatavalid) ? addr + 2 : addr;
			end

			// Write request
			8'h3:
			begin
				addw <= (waitrequest) ? addw : addw + 2;
			end

			8'h4:
			begin
				counter <= counter + 1;
			end

			8'h5:
			begin
			end
		endcase
	end

	always @ (*)
	begin
		read_n <= 1;
		write_n <= 1;
		address <= address;

		case(state [7:0])
			// Wait for ready == 1
			8'h0:
			begin
				nextstate <= (ready) ? 1 : 0;
			end

			// Read request
			8'h1:
			begin
				read_n <= 0;
				address <= addr;
				nextstate <= (waitrequest) ? 1 : 2;
			end

			// Read request pt2
			8'h2:
			begin
				nextstate <= (readdatavalid) ? 3 : 2;
			end

			// Write Request
			8'h3:
			begin
				write_n <= 0;
				address <= addw;
				writedata <= data;
				nextstate <= (waitrequest) ? 3 : 4;
			end

			8'h4:
			begin
				nextstate <= (counter < 784) ? 1 : 5;
			end

			8'h5:
			begin
				done <= (ready) ? 1 : 0;
				nextstate <= (ready) ? 5 : 0;
			end
		endcase
	end

endmodule

/*
module read_td(
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



	reg [15:0] data = 16'hABCD;
	reg [7:0] state;
	reg [7:0] nextstate = 0;
	reg [31:0] addr = 600_000;
	reg [31:0] addw = 650_000;
	reg [31:0] counter = 1;

	assign toHexLed = {counter,data,state};

	assign chipselect = 1;
	assign byteenable = 2'b11;

	localparam base_img = 32'd600_000;
	localparam base_layer1 = 32'd650_000;
	
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
			IDLE:
			begin
				counter <= 1;
				addr <= base_img;
				addw <= base_layer1;
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
				addw <= (waitrequest) ? addw : addw + 2;
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
		read_n <= 1;
		write_n <= 1;
		address <= address;

		case(state [7:0])
			// Wait for ready == 1
			IDLE:
			begin
				nextstate <= (ready) ? READ : IDLE;
			end

			// Read request
			READ:
			begin
				read_n <= 0;
				address <= addr;
				nextstate <= (!waitrequest) ? WAIT : READ;
			end

			// Read request pt2
			WAIT:
			begin
				nextstate <= (readdatavalid) ? WRITE : WAIT;
			end

			// Write Request
			WRITE:
			begin
				write_n <= 0;
				address <= addw;
				writedata <= data;
				nextstate <= (!waitrequest) ?  CONT : WRITE;
			end

			CONT:
			begin
				nextstate <= (counter < 784) ? READ : DONE;
			end

			DONE:
			begin
				done <= (ready) ? 1 : 0;
				nextstate <= (ready) ? DONE : IDLE;
			end
		endcase
	end

endmodule
*/