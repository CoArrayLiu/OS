#include "os.h"

/*
* UART 控制寄存器内存映射到地址 UART0。
* 此宏返回其中一个寄存器的地址
 */
#define UART_REG(reg) ((volatile uint8_t *)(UART0 + reg))


/*
* UART 控制寄存器映射。
* 有些寄存器被多个函数重复使用
* 0（写入模式）：THR/DLL
* 1（写入模式）：IER/DLM
 */
#define RHR 0	// 接收保持寄存器（读模式）
#define THR 0	// 发送保持寄存器（写模式）
#define DLL 0	// 除数锁存器的 LSB（写入模式）
#define IER 1	// 中断使能寄存器（写入模式）
#define DLM 1	// 除数锁存器的 MSB（写入模式）
#define FCR 2	// FIFO 控制寄存器（写模式）
#define ISR 2	// 中断状态寄存器（读取模式）
#define LCR 3	// 线路控制寄存器
#define MCR 4	// 调制解调器控制寄存器
#define LSR 5	// 线路状态寄存器
#define MSR 6	// 调制解调器状态寄存器
#define SPR 7	// 暂存器寄存器


/*
* 线路状态寄存器 (LSR)
* LSR BIT 0:
* 0 = 接收保持寄存器或 FIFO 中没有数据。
* 1 = 数据已接收并保存在接收保持寄存器或 FIFO 中。
 * ......
* LSR BIT 5：
* 0 = 发送保持寄存器已满。16550 不会接受任何数据进行传输。
* 1 = 发送器保持寄存器（或 FIFO）为空。CPU 可以加载下一个字符。
 * ......
 */
#define LSR_RX_READY (1 << 0)
#define LSR_TX_IDLE  (1 << 5)

#define uart_read_reg(reg) (*(UART_REG(reg)))
#define uart_write_reg(reg, v) (*(UART_REG(reg)) = (v))

//初始化uart
void uart_init()
{
	/* 禁用中断 */
	uart_write_reg(IER, 0x00);

	/*设置串口波特率和奇偶校验位*/
	uint8_t lcr = uart_read_reg(LCR);
	uart_write_reg(LCR, lcr | (1 << 7)); /*将第七位设成1*/
	uart_write_reg(DLL, 0x03);      /*低位*/
	uart_write_reg(DLM, 0x00);		/*高位*/
	lcr = 0;
	uart_write_reg(LCR, lcr | (3 << 0));

	/*
	 * 开启接受中断
	 */
	uint8_t ier = uart_read_reg(IER);
	uart_write_reg(IER, ier | (1 << 0));
}

int uart_putc(char ch)
{
	while ((uart_read_reg(LSR) & LSR_TX_IDLE) == 0);
	return uart_write_reg(THR, ch);
}

void uart_puts(char *s)
{
	while (*s) {
		uart_putc(*s++);
	}
}

int uart_getc(void)
{
	while (0 == (uart_read_reg(LSR) & LSR_RX_READY))
		;
	return uart_read_reg(RHR);
}

/*
 * handle a uart interrupt, raised because input has arrived, called from trap.c.
 */
void uart_isr(void)
{
	uart_putc((char)uart_getc());
	/* add a new line just to look better */
	uart_putc('\n');
}
