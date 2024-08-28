#include "os.h"

void plic_init(void)
{
	int hart = r_tp();
  
	/* 
	 * Set priority for UART0.
	 *
	* 可以通过将
	* 写入其 32 位内存映射优先级寄存器来为每个 PLIC 中断源分配优先级。
	* QEMU-virt（与 FU540-C000 相同）支持 7 个优先级。
	* 优先级值 0 保留表示“永不中断”并
	* 有效地禁用中断。
	* 优先级 1 是最低活动优先级，优先级 7 是最高活动优先级。
	* 相同优先级的全局中断之间的联系由
	* 中断 ID 打破；ID 最低的中断具有最高
	* 有效优先级。
	 */
	*(uint32_t*)PLIC_PRIORITY(UART0_IRQ) = 1;
 
	/*
	 * Enable UART0
	 *
	* 可以通过设置启用寄存器中的相应位来启用每个全局中断。
	 */
	*(uint32_t*)PLIC_MENABLE(hart, UART0_IRQ)= (1 << (UART0_IRQ % 32));

	/* 
	* 设置 UART0 的优先级阈值。
	*
	* PLIC 将屏蔽优先级小于或等于阈值的所有中断。
	* 最大阈值为 7。
	* 例如，阈值为零允许所有优先级为非零的中断，而阈值为 7 则屏蔽所有中断。
	* 请注意，阈值对于 PLIC 是全局的，而不是对于每个中断源都是全局的。
	 */
	*(uint32_t*)PLIC_MTHRESHOLD(hart) = 0;

	/* 启用machine态下的中断 */
	w_mie(r_mie() | MIE_MEIE);
}

/* 
 * DESCRIPTION:
* 向 PLIC 查询我们应该服务什么中断。
* 通过读取声明寄存器执行中断声明，该寄存器
* 返回最高优先级待处理中断的 ID，如果没有待处理中断，则返回零。
* 成功的声明还会自动清除中断源上相应的待处理位。
* 返回值：
* 最高优先级待处理中断的 ID，如果没有待处理中断，则返回零。
 */
int plic_claim(void)
{
	int hart = r_tp();
	int irq = *(uint32_t*)PLIC_MCLAIM(hart);
	return irq;
}

/* 
* 描述：
* 将从声明 (irq) 收到的中断 ID 写入
* 完成寄存器将向 PLIC 发出信号，告知我们已处理此 IRQ。
* PLIC 不会检查完成 ID 是否与该目标的最后一个声明 ID 相同。如果完成 ID 与当前为目标启用的
* 中断源不匹配，则将默默忽略完成。
* 返回值：无
 */
void plic_complete(int irq)
{
	int hart = r_tp();
	*(uint32_t*)PLIC_MCOMPLETE(hart) = irq;
}
