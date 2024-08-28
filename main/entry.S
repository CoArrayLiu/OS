#define LOAD		lw
#define STORE		sw
#define SIZE_REG	4

# 将所有通用 (GP) 寄存器保存到上下文。
# struct context *base = &ctx_task;
# base->ra = ra;
# ......
# 这些要保存的 GP 寄存器不包括 gp
# 和 tp，因为它们不是调用者保存的或
# 被调用者保存的。这两个寄存器通常用于
# 特殊用途。例如，在 RVOS 中，“tp”
#（又名“线程指针”）用于存储 hartid，
# 这是一个全局值，在上下文切换期间不会更改。
.macro reg_save base
	STORE ra,   0*SIZE_REG(\base)
	STORE sp,   1*SIZE_REG(\base)
	STORE t0,   4*SIZE_REG(\base)
	STORE t1,   5*SIZE_REG(\base)
	STORE t2,   6*SIZE_REG(\base)
	STORE s0,   7*SIZE_REG(\base)
	STORE s1,   8*SIZE_REG(\base)
	STORE a0,   9*SIZE_REG(\base)
	STORE a1,  10*SIZE_REG(\base)
	STORE a2,  11*SIZE_REG(\base)
	STORE a3,  12*SIZE_REG(\base)
	STORE a4,  13*SIZE_REG(\base)
	STORE a5,  14*SIZE_REG(\base)
	STORE a6,  15*SIZE_REG(\base)
	STORE a7,  16*SIZE_REG(\base)
	STORE s2,  17*SIZE_REG(\base)
	STORE s3,  18*SIZE_REG(\base)
	STORE s4,  19*SIZE_REG(\base)
	STORE s5,  20*SIZE_REG(\base)
	STORE s6,  21*SIZE_REG(\base)
	STORE s7,  22*SIZE_REG(\base)
	STORE s8,  23*SIZE_REG(\base)
	STORE s9,  24*SIZE_REG(\base)
	STORE s10, 25*SIZE_REG(\base)
	STORE s11, 26*SIZE_REG(\base)
	STORE t3,  27*SIZE_REG(\base)
	STORE t4,  28*SIZE_REG(\base)
	STORE t5,  29*SIZE_REG(\base)
	# we don't save t6 here, due to we have used
	# it as base, we have to save t6 in an extra step
	# outside of reg_save
.endm

# 从上下文中恢复所有通用 (GP) 寄存器
# 除 gp 和 tp 外。
# struct context *base = &ctx_task;
# ra = base->ra;
# ......
.macro reg_restore base
	LOAD ra,   0*SIZE_REG(\base)
	LOAD sp,   1*SIZE_REG(\base)
	LOAD t0,   4*SIZE_REG(\base)
	LOAD t1,   5*SIZE_REG(\base)
	LOAD t2,   6*SIZE_REG(\base)
	LOAD s0,   7*SIZE_REG(\base)
	LOAD s1,   8*SIZE_REG(\base)
	LOAD a0,   9*SIZE_REG(\base)
	LOAD a1,  10*SIZE_REG(\base)
	LOAD a2,  11*SIZE_REG(\base)
	LOAD a3,  12*SIZE_REG(\base)
	LOAD a4,  13*SIZE_REG(\base)
	LOAD a5,  14*SIZE_REG(\base)
	LOAD a6,  15*SIZE_REG(\base)
	LOAD a7,  16*SIZE_REG(\base)
	LOAD s2,  17*SIZE_REG(\base)
	LOAD s3,  18*SIZE_REG(\base)
	LOAD s4,  19*SIZE_REG(\base)
	LOAD s5,  20*SIZE_REG(\base)
	LOAD s6,  21*SIZE_REG(\base)
	LOAD s7,  22*SIZE_REG(\base)
	LOAD s8,  23*SIZE_REG(\base)
	LOAD s9,  24*SIZE_REG(\base)
	LOAD s10, 25*SIZE_REG(\base)
	LOAD s11, 26*SIZE_REG(\base)
	LOAD t3,  27*SIZE_REG(\base)
	LOAD t4,  28*SIZE_REG(\base)
	LOAD t5,  29*SIZE_REG(\base)
	LOAD t6,  30*SIZE_REG(\base)
.endm

# 关于保存/恢复需要注意的事项：
# - 我们使用 mscratch 保存指向当前任务上下文的指针
# - 我们使用 t6 作为 reg_save/reg_restore 的“基数”，因为它是
# 最底部的寄存器 (x31)，在加载期间不会被覆盖。

.text

# 机器模式下的中断和异常发生在这里。
.globl trap_vector
# 陷阱向量基地址必须始终与 4 字节边界对齐
.balign 4
trap_vector:
	# 保存上下文（寄存器）。
	csrrw	t6, mscratch, t6	# swap t6 and mscratch
	reg_save t6

	# 保存实际的 t6 寄存器，将其交换到mscratch
	mv	t5, t6			# t5 points to the context of current task
	csrr	t6, mscratch		# read t6 back from mscratch
	STORE	t6, 30*SIZE_REG(t5)	# save t6 with t5 as base

	# 将 mepc 保存到当前任务的上下文中
	csrr	a0, mepc
	STORE	a0, 31*SIZE_REG(t5)

	# 将上下文指针恢复到 mscratch 中
	csrw	mscratch, t5

	# 调用 trap.c 中的 C 陷阱处理程序
	csrr	a0, mepc
	csrr	a1, mcause
	csrr	a2, mscratch
	call	trap_handler

	# trap_handler 将通过 a0 返回返回地址。
	csrw	mepc, a0

	# 恢复上下文（寄存器）。
	csrr	t6, mscratch
	reg_restore t6

	# 返回到在trap之前所做的一切。
	mret

# void switch_to(struct context *next);
# a0：指向下一个任务上下文的指针
.globl switch_to
.balign 4
switch_to:
	# 切换 mscratch 以指向下一个任务的上下文
	csrw	mscratch, a0
	# 将 mepc 设置为下一个任务的 pc
	LOAD	a1, 31*SIZE_REG(a0)
	csrw	mepc, a1

	# 恢复所有 GP 寄存器
	# 使用 t6 指向新任务的上下文
	mv	t6, a0
	reg_restore t6

	# 进行实际的上下文切换。
	# 启用全局中断
	mret

.end

