# Verilog Driver Code for LM75A Temperature Sensor
## Basic Description
This code is a Verilog driver for the LM75A temperature sensor, used to read the temperature values reported by the 
sensor using an FPGA. The LM75A is a temperature sensor that operates with the I2C protocol and offers a temperature 
measurement accuracy of up to 0.125 degrees Celsius. The directly read data is in the form of an 11-bit two's 
complement. In this driver, to avoid instability caused by excessively high precision, the read temperature precision 
is set to 0.5 degrees Celsius. This driver includes the conversion of directly read two's complement data into 8421 BCD 
code and outputs the temperature's sign, hundreds, tens, and units digit data. By default, the driver reads the 
temperature once per second. This driver module only includes the function to directly read temperature data from the 
LM75A temperature sensor and does not include the configuration of related registers in the LM75A chip.
## Driver Module Description
### Port Information
This module contains 2 input ports, 7 output ports, and 1 inout port. The port definitions are as follows:
#### Input Ports:
* `clk`: 1-bit wide clock signal, default at 50MHz.
* `rst_n`: 1-bit wide reset signal, active low.
#### Output Ports:
* `valid`: 1-bit wide output valid signal, which generates a rising edge after completing temperature reading and 
  related data processing. This is used to indicate that the subsequent module can receive the temperature data. 
  The temperature data output will not change between two rising edges of the `valid` signal.
* `sign`: 1-bit wide signal representing the sign of the temperature. If 0, the temperature is positive; if 1, 
  the temperature is negative.
* `fractional`: 4-bit wide signal representing the decimal part of the temperature data (in 8421 BCD code), which is 
  the first digit after the decimal point. Since the read precision of the driver module is 0.5 degrees Celsius, the 
  data output by this port can only be 0 or 5.
* `ones`: 4-bit wide signal representing the units digit of the temperature data (in 8421 BCD code).
* `tens`: 4-bit wide signal representing the tens digit of the temperature data (in 8421 BCD code).
* `hundreds`: 4-bit wide signal representing the hundreds digit of the temperature data (in 8421 BCD code). Generally, 
  the device works below 100 degrees Celsius, so this port can be left floating.
* `scl`: 1-bit wide I2C protocol `SCL` signal, providing the clock signal.
#### Inout Port:
* `sda`: 1-bit wide I2C protocol `SDA` signal, used for data input and output.
### Configurable Parameters
* `DEVICE_ADDR`: The address of the LM75A device. The first 4 bits (1001) cannot be modified. The middle 3 bits are the 
  LM75A's `A2`, `A1`, `A0` address bits, which should be modified according to the actual situation. The default in 
  the driver is `000`. The last bit represents the read/write signal, with `1` indicating data read and `0` indicating 
  data write. Since this driver only includes the function of reading temperature data, the last bit should remain `1`.
* `READ_TIME`: The number of `clk` clock signal cycles included in one temperature reading, used to control the reading 
  frequency. When the `clk` signal is 50MHz, the default reading cycle is 1s.
* `STEP_TIME`: The number of `clk` signal cycles included in one period of the `scl` signal during the reading process, 
  used to control the frequency of the `scl` signal. This frequency should be set according to the actual device 
  situation and should not be too fast. Additionally, it is recommended to set the last 2 bits of this constant 
  (in binary representation) to `0`. When the `clk` signal frequency is 50MHz, the default period of the `scl` signal 
  is 1us.
------------------------------------------------------------------------------------------------------------------------
## 基本描述
本代码是LM75A温度传感器的Verilog驱动程序，用于利用FPGA读取该传感器报告的温度值。LM75A是一款I2C协议的温度传感器，温度测量精度可达到
0.125摄氏度，直接读取获得的数据是11位补码的形式。在本驱动程序，为了避免精度过高带来的不稳定，读取的温度精度仅为0.5摄氏度。本驱动包含
将直接读取到的补码转换为8421BCD码的部分，将原始数据转换为温度的符号、百位、十位、个位数据输出。默认情况下，驱动每秒读取一次温度。本驱
动模块仅包含直接读取LM75A温度传感器的温度数据的功能，不含配置LM75A芯片中的相关寄存器的功能。
## 驱动模块描述
### 端口信息
本模块包含2个输入端口，7个输出端口，1个双向端口，端口定义如下：
#### 输入端口：
* `clk`: 位宽为1位，时钟信号，默认为50MHz。
* `rst_n`: 位宽为1位，复位信号，低有效。
#### 输出端口：
* `valid`: 位宽为1位，输出有效信号，当完成温度的读取和相关数据处理后会产生一个上升沿，用于指示后续模块接收温度数据，在`valid`信号的
  两次上升沿之间输出的温度数据不会改变。
* `sign`: 位宽为1位，表示温度的符号，若为0，则温度值为正，若为1，则温度值为负。
* `fractional`: 位宽为4位，表示温度数据的小数部分（8421BCD码），即小数点后第一位的数据。由于驱动模块的读取精度为0.5℃，因此该端口
  输出的数据仅可能为0或5。
* `ones`: 位宽为4位，表示温度数据的个位数字（8421BCD码）。
* `tens`: 位宽为4位，表示温度数据的十位数字（8421BCD码）。
* `hundreds`: 位宽为4位，表示温度数据的百位数字（8421BCD码）。一般情况下，器件工作的温度低于100℃，因此可以将该端口悬空。
* `scl`: 位宽为1位，I2C协议的`SCL`信号，提供时钟信号。
#### 双向端口：
* `sda`: 位宽位1位，I2C协议的`SDA`信号，用于数据的输入和输出。
### 可修改参数信息
* `DEVICE_ADDR`: LM75A器件的地址。前4位1001不可修改。中间3位分别为LM75A的`A2`、`A1`、`A0`地址位，应根据实际情况修改，驱动程序中
  默认为`000`。最后一位表示读/写信号，`1`表示读取数据，`0`表示写入数据，由于本驱动仅包含读取温度数据的功能，因此应保持最后一位
  为`1`。
* `READ_TIME`: 读取一次温度包含的`clk`时钟信号的周期个数，用于控制读取温度的频率。在`clk`信号为50MHz的情况下，默认的读取周期为1s。
* `STEP_TIME`: 在读取过程中`scl`信号一个周期包含的clk信号的周期个数，用于控制`scl`信号的频率。该频率应根据实际的器件情况设定，不应
  过快。此外，建议将该常数（以二进制表示）的最后2位数据设定为`0`。在`clk`信号频率为50MHz的情况下，`scl`信号的周期默认为1us。
