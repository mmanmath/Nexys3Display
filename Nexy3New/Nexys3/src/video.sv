//----------------------------------------------------------------------------------
//-- Company: Arizona State Univerity
//-- Engineer: Manu Prasad
//-- 
//-- Create Date:   04/06/2014 
//-- Design Name: 
//-- Module Name:   Video Controller 
//-- Description: 	This module establishes the video control FSM
//
//--
//-- Revision: 
//-- Revision 0.01 - File Created
//-- Additional Comments: 
//--
//----------------------------------------------------------------------------------			

`timescale 1ns / 1ns

module video (	output bit	TFT_CLK,			// Clock signal for LCD
				output bit	TFT_DISP,			// TFT Display signal
				output bit	TFT_EN,				// TFT Enable signal
				output bit	TFT_DE,				// TFT DE
				output bit	LED_EN,				// Backlight LED enable
				output bit	[7:0] TFT_R,		// Red pixel data output 
				output bit	[7:0] TFT_B,		// Blue pixel data output
				output bit	[7:0] TFT_G,		// Green pixel data	output	
				input bit	[7:0] TFT_R_IN,		// Red pixel data input 
				input bit	[7:0] TFT_B_IN,		// Blue pixel data input
				input bit	[7:0] TFT_G_IN,		// Green pixel data	input
				input bit	reset				// Global reset signal
				);	

				
parameter 	t_tft_clk = 111, // TFT Clk is 9 MHz i.e 111.11ns
			t1 = 1000000, // TFT-EN high to first pixel bus signal = 1 ms; min = 0.05 ms, max = 100 ms 
			t2 = 1000000, // Valid pixel data to DISP high = 1 ms; min = 0 ms, max = 200 ms
			t3 = 160000000, // DISP high to backlight on, backlight off to DISP low = 160 ms; min = 160 ms
			t4 = 100000000,	// TFT-EN low pulse = 100ms; min = 100 ms
			t_pwm = 100000,	// PWM Frequency = 10 kHz i.e 100 us; min = 100Hz, max = 50kHz 
			duty_cycle = 0.50; //PWM Duty cycle

int tva = 1, tvb = 1, tha = 1 , thb = 1; // Counters for vertical and horizontal active and blanking periods 
	
//bit clk_on = 0;
	
typedef enum {sreset, power_on, active, blanking, power_down} states;
// The active and blanking periods correspond to vertical active and vertical blanking
// Multiple horizontal active and blanking periods occur within the vertical active state
states next_state = power_on;
states current_state = sreset;
	   
bit [7:0] ram_R [255 : 0], ram_G [255 : 0], ram_B [255 : 0];
int i = 0, j = 0;

//Initialize RAM values
initial	
	begin
	for(i = 0; i<255; i++)
		begin
			ram_R[i] <= 0;
			ram_G[i] <=	0;
			ram_B[i] <=	0;
		end
	i = 0;
	end
		
				
//Setup the pixel clock		
initial	 
	begin 
		TFT_CLK = 0;	 
		//@(clk_on)
		forever #t_tft_clk TFT_CLK = ~TFT_CLK;	   
	end	  
	
// Reset and next state assignment
always @(posedge TFT_CLK iff(next_state!=current_state))
	begin
	if(reset)
		current_state = sreset;
	else
		if(next_state==current_state); // Redundant, remove this
		else current_state = next_state;
	end
		
//Register to hold pixel data
always @(TFT_R or TFT_G or TFT_B)
	begin
		ram_R[i] = TFT_R_IN;
		ram_G[i] = TFT_G_IN;
		ram_B[i] = TFT_B_IN;
		i++;
		if(i==255)
			i=0;
	end
	
//PWM
initial
	begin
	@(LED_EN)
	forever
	begin
		LED_EN = 1; #(t_pwm*duty_cycle)
		LED_EN = 0; #(t_pwm*(1-duty_cycle));
	end
	end
	

//State Machine Definitions
always @(current_state)
	begin
		case(current_state)
			sreset:
			if(reset)
			begin
				TFT_DISP <= 0;
				TFT_EN <= 0;
				TFT_DE <= 0;
				LED_EN <= 0;
				TFT_R <= 0;
				TFT_B <= 0;
				TFT_G <= 0;	
				next_state = sreset;
			end	
			else
				next_state = power_on;
			power_on:
			begin
				TFT_EN = 1;
				#t1 //clk_on <= 1;	
				TFT_R <= ram_R[j];
				TFT_G <= ram_G[j];
				TFT_B <= ram_B[j];
				TFT_DE = 1;
				if(j==255)
					j=0;
				else
					j++;
				fork
					next_state = blanking;
					begin
						#t2 TFT_DISP = 1;
						#t3 LED_EN = 1;	 
					end
				join_none 
			end
			active:
			begin 
				for(tva = 1; tva <= 45; tva ++)
					begin
						// Horizontal Blanking
						for(thb = 1; thb <= 45; thb++)
							begin
								@(posedge TFT_CLK);
								TFT_R <= TFT_R;
								TFT_G <= TFT_G;
								TFT_B <= TFT_B;
								TFT_DE = 0;
							end
						// Horizontal active
						for(tha = 1; tha <= 480; tha++)
							begin
								@(posedge TFT_CLK);
								TFT_R <= ram_R[j];
								TFT_G <= ram_G[j];
								TFT_B <= ram_B[j];
								TFT_DE = 1;
								if(j==255)
									j=0;
								else
									j++;
							end
					end
				next_state = blanking;
			end
			blanking:
			begin  
				for(tvb = 1; tvb <= 16; tvb++)  // 480 clocks is one line
					begin
						for(int temp = 1; temp <= 480; temp++) 
							begin
								@(posedge TFT_CLK);
								TFT_DE <= 0;
							end
					end
				next_state = active;
			end
			power_down:	 	   
			
			begin
			//Unimplemented
			end
		endcase
	end	
	
endmodule