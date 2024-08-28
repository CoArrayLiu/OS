#include "os.h"

/* 在entry.S定义了 */
extern void switch_to(struct context *next);

#define MAX_TASKS 10
#define STACK_SIZE 1024
/*
* 在标准 RISC-V 调用约定中，堆栈指针 sp
* 始终是 16 字节对齐的。
 */
uint8_t __attribute__((aligned(16))) task_stack[MAX_TASKS][STACK_SIZE];
struct context ctx_tasks[MAX_TASKS];

/*
* _top 用于标记 ctx_tasks 的最大可用位置
* _current 用于指向当前任务的上下文
 */
static int _top = 0;
static int _current = -1;

void sched_init()
{
	w_mscratch(0);

	/* 启用machine态的软中断. */
	w_mie(r_mie() | MIE_MSIE);
}

/*
 * 实现一个简单的循环 FIFO 调度程序
 */
void schedule()
{
	if (_top <= 0) {
		panic("Num of task should be greater than zero!");
		return;
	}

	_current = (_current + 1) % _top;
	struct context *next = &(ctx_tasks[_current]);
	switch_to(next);
}

/*

128 / 5,000
* 描述
* 创建任务。
* - start_routin：任务例程条目
* 返回值
* 0：成功
* -1：如果发生错误
 */
int task_create(void (*start_routin)(void))
{
	if (_top < MAX_TASKS) {
		ctx_tasks[_top].sp = (reg_t) &task_stack[_top][STACK_SIZE];
		ctx_tasks[_top].pc = (reg_t) start_routin;
		_top++;
		return 0;
	} else {
		return -1;
	}
}

/*
* 描述
* task_yield() 导致调用任务放弃 CPU，并运行新的
* 任务。
 */
void task_yield()
{
	/* trigger a machine-level software interrupt */
	int id = r_mhartid();
	*(uint32_t*)CLINT_MSIP(id) = 1;
}

/*
一个简单实现
 */
void task_delay(volatile int count)
{
	count *= 50000;
	while (count--);
}

