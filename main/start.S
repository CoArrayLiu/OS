#include "platform.h"

	# 每个 Hart 堆栈的大小为 1024 字节
	.equ	STACK_SIZE, 1024

	.global	_start

	.text
_start:
	# park harts 的 id 为 != 0
	csrr	t0, mhartid		# 读取当前 HART ID
	mv	tp, t0			# 将 CPU 的 hartid 保存在其 tp 中以供稍后使用。
	bnez	t0, park		# 如果我们不在hart 0
					

	# 将 BSS 部分中的所有字节设置为零。
	la	a0, _bss_start
	la	a1, _bss_end
	bgeu	a0, a1, 2f
1:
	sw	zero, (a0)
	addi	a0, a0, 4
	bltu	a0, a1, 1b
2:
	# 设置堆栈，堆栈从底部向顶部增长，因此我们将
	# 堆栈指针放在堆栈范围的最末端。
	slli	t0, t0, 10		# 将 hart id 左移 1024
	la	sp, stacks + STACK_SIZE	# 设置初始堆栈指针
					# 到第一个堆栈空间的末尾
	add	sp, sp, t0		# 移动当前 HART 堆栈指针
					# 到堆栈空间中的位置

#ifdef CONFIG_SYSCALL
	li      t0, 0xffffffff
	csrw    pmpaddr0, t0
	li      t0, 0xf
	csrw    pmpcfg0, t0
#endif

	# 在start_kernel的最后，schedule()会调用MRET来切换到
	# 第一个任务，所以我们在这里准备mstatus。

#ifdef CONFIG_SYSCALL
	# 将 mstatus.MPP 设置为 0，因此我们将在 MRET 之后以用户模式运行。
	# 无需明确将 mstatus.MPIE 设置为 1，因为根据 ISA
	# 规范：高于 U 模式的 M 模式的中断
	# 始终全局启用，无论全局 MIE 位的设置如何。
	li	t0, 3 << 11
	csrc	mstatus, t0
#else
	# 将 mstatus.MPP 设置为 3，因此我们在 MRET 之后仍然在机器模式下运行。
	# 将 mstatus.MPIE 设置为 1，因此 MRET 将启用中断。
	li	t0, 3 << 11 | 1 << 7
	csrs	mstatus, t0
#endif

	j	start_kernel		# hart 0 jump to c

park:
	wfi
	j	park

	# 在标准 RISC-V 调用约定中，堆栈指针 sp
	# 始终是 16 字节对齐的。
.balign 16
stacks:
	.skip	STACK_SIZE * MAXNUM_CPU # allocate space for all the harts stacks

	.end				# End of file
