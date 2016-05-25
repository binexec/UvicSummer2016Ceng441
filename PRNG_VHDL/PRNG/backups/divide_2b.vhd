--This module is used to test the individual subcomponents of the main divider, minus the main division control process

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity divider_test is
    Port ( Y : in  STD_LOGIC_VECTOR (31 downto 0);
           X : in  STD_LOGIC_VECTOR (31 downto 0);
           R : out  STD_LOGIC_VECTOR (31 downto 0);
           Q : out  STD_LOGIC_VECTOR (31 downto 0);
           clk : in  STD_LOGIC;
			  rst : in  STD_LOGIC;
           start : in  STD_LOGIC;
           output_ready : out  STD_LOGIC;
			  
			operands_valid_dbg : out  STD_LOGIC;
			divider_busy_dbg : out STD_LOGIC;
			Y_buf_dbg : OUT STD_LOGIC_VECTOR (31 downto 0);
			X_buf_dbg : OUT STD_LOGIC_VECTOR (31 downto 0);
			Z_dbg : OUT STD_LOGIC_VECTOR (31 downto 0);
			px_dbg : OUT STD_LOGIC_VECTOR (31 downto 0);
			py_dbg : OUT STD_LOGIC_VECTOR (31 downto 0);
			mu1_dbg : OUT STD_LOGIC_VECTOR (31 downto 0);
			mu2_dbg : OUT STD_LOGIC_VECTOR (31 downto 0);
			delta_dbg : OUT STD_LOGIC_VECTOR (31 downto 0)
           );
end divider_test;

architecture Behavioral of divider_test is
	
	signal Y_buffer : STD_LOGIC_VECTOR (31 downto 0);
	signal X_buffer : STD_LOGIC_VECTOR (31 downto 0);
	
	signal operands_valid : STD_LOGIC := '0';
	signal divider_busy : STD_LOGIC := '0';
	
	signal Z : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
	signal px, py : Integer;
	signal mu_phase1 : Integer;
	signal mu_phase2 : Integer;
	signal delta : STD_LOGIC_VECTOR (31 downto 0);
	

begin
	--Output intermediate debug values
	operands_valid_dbg <= operands_valid;
	divider_busy_dbg <= divider_busy;
	Y_buf_dbg <= Y_buffer;
	X_buf_dbg <= X_buffer;
	Z_dbg <= Z;
	px_dbg <= std_logic_vector(to_signed(px, X'length));
	py_dbg <= std_logic_vector(to_signed(py, Y'length));
	mu1_dbg <= std_logic_vector(to_signed(mu_phase1, Y'length));
	mu2_dbg <= std_logic_vector(to_signed(mu_phase2, Y'length));
	delta_dbg <= delta;
	
	--Generates PX value on the falling edge (The most significant bit in X that's 1)
	process(clk,X_buffer)
	begin
		if(clk = '0' and clk'event) then
			--px <= 0;	
			for i in 31 downto 0 loop
				if (X_buffer(i) = '1') then
					px <= i;
					exit;
				end if;
			end loop;
		end if;
	end process;
	
	--Generates PY value on the falling edge (The most significant bit in Y that's 0)
	process(clk,Y_buffer)
		variable Y_temp : STD_LOGIC_VECTOR (31 downto 0);
	begin
		if(clk = '0' and clk'event) then
		
			if(signed(Y_buffer) < 0) then				--Find the Most Significant 0 if Y<0. 
				Y_temp := not Y_buffer;
				for i in 31 downto 0 loop
					if (Y_temp(i) = '1') then
						py <= i;
						exit;
					end if;
				end loop;
			
			elsif(signed(Y_buffer) > 0) then			--If Y>0, the MS 1 is found instead. 
				for i in 31 downto 0 loop
					if (Y_buffer(i) = '1') then
						py <= i;
						exit;
					end if;
				end loop;
			
			else												--If Y=0, the process will return a 0 since a MS 1 cannot be found.
				py <= 0;
			end if;
			
		end if;
	end process;
	
	--Generates the "mu" signal for the first phase of the division algorithm on the falling edge
	process(clk,operands_valid,Y_buffer)
	begin
		if(clk = '0' and clk'event) then
			if(signed(Y_buffer) >= 0) then
				mu_phase1 <= 1;
			else
				mu_phase1 <= -1;
			end if;
		end if;
	end process;
	
	--Generates the "mu" signal for the second phase of the division algorithm on the falling edge
	process(clk,operands_valid,Y_buffer,X_buffer)
	begin
		if(clk = '0' and clk'event) then
			if(signed(Y_buffer) >= signed(X_buffer)) then
				mu_phase2 <= 1;
			else
				mu_phase2 <= -1;	--When Y<0
			end if;
		end if;
	end process;
	
	--Generates the "delta" signal for the first phase of the division algorithm on the falling edge
	process(clk,operands_valid,py,px)
		variable bit_pos : integer;
		variable delta_temp : std_logic_vector(31 downto 0);
	begin
		if(clk = '0' and clk'event) then
			bit_pos := py - px;
			delta_temp := (others => '0');
			
			if(bit_pos > 0) then
				delta_temp(bit_pos) := '1';
			end if;
			
			delta <= delta_temp;
		end if;
	end process;
	
	--Main Division algorithm and controls
	process(clk,start,mu_phase1,mu_phase2,delta,py,px)
		variable temp1, temp2, temp3, temp4 : Integer;
	begin
		if(clk = '1' and clk'event) then
			--Load the initial operand values when the divider's idle
			if(start = '1') then
				Y_buffer <= Y;
				X_buffer <= X;
		
		else
			--Run one iteration of Algorithm Phase 1
				if (py > px) then
					temp1 := mu_phase1 * to_integer(signed(delta));
					--Calculate Y value for this iteration
					temp2 := temp1 * to_integer(signed(delta));
					temp3 := to_integer(signed(Y_buffer)) - temp2;
					R <= std_logic_vector(to_signed(temp3,32));
					--Calculate Z value for this iteration
					temp4 := to_integer(signed(Z)) + temp1;
					Z <= std_logic_vector(to_signed(temp4,32));
					Q <= Z;
					
				--Run one iteration of Algorithm Phase 2
				else				
					--Does quotient and remainder needs adjustments?
					if(not(signed(Y_buffer) >= 0 and signed(Y_buffer) < signed(X_buffer))) then
						--Calculate Y value for this iteration
						temp1 := mu_phase2 * to_integer(signed(X_buffer));
						temp2 := to_integer(signed(Y_buffer)) - temp1;
						R <= std_logic_vector(to_signed(temp2,32));
						--Calculate Z value for this iteration
						temp3 := to_integer(signed(Z)) + mu_phase2;
						Z <= std_logic_vector(to_signed(temp3,32));
						Q <= Z;
					end if;
						
						R <= Y_buffer;
						Q <= Z;
					
				end if;

			end if;
		end if;
	end process;

end Behavioral;

