; ------- 名词解释 : 原谅我薄弱的基础😭😭
; CS : 代码段寄存器(Code Segment), 对应于内存中的存放代码的内存区域，用来存放内存代码段区域的入口地址(段基址)。在CPU执行指令时，通过代码段寄存器（CS，Code Segment）和指令指针寄存器（IP，Instruction Pointer）来确定要执行的下一条指令的内存地址。
; DS : 数据段寄存器(Data Segment), 指出当前程序使用的数据所存放段的最低地址，即存放数据段的段基址。
; SS : 堆栈段寄存器(Stack Segment), 指出当前堆栈的底部地址，即存放堆栈段的段基址。
; ES : 附加段寄存器(Extra Segment), 存放当前执行程序中一个辅助数据段的段地址。
; 在 8086 中，物理地址是由段地址左移 4 位，然后加上偏移地址形成的
; https://blog.csdn.net/qq_35212671/article/details/52770730

; SP : 堆栈寄存器(Stack Pointer), 存放栈的偏移地址。
; BP : 基数指针寄存器(Base Pointer)
; 参考 : https://www.cnblogs.com/dongzhiquan/p/4960602.html


; 用于指定程序的起始地址
; BIOS 自检完成后, 会将 boot 程序加载到内存的 0x7C00 地址
; 并从该地址开始执行
; 如果没有这条指令, 编译器会把 0x0000 作为程序的起始地址
; 参考 : http://www.ruanyifeng.com/blog/2013/02/booting.html
org					0x7c00

; 伪指令: 让 BaseOfStack 等同于 0x7c00
; BaseOfStack 为的是为栈指针寄存器 SP 提供栈基址
BaseOfStack			equ			0x7c00

; 将 CS 寄存器的段基址设置到 DS、ES、SS 等寄存器中
Label_Start:
    mov				ax,			cs
    mov				ds,			ax
    mov				es,			ax
    mov				ss,			ax
; 设置栈指针寄存器 SP
    mov				sp,			BaseOfStack




; 通过 BIOS 中断服务程序 INT 10h 实现屏幕信息显示的操作
; 调用 INT 10h 中断服务时，必须向 AH 寄存器传入服务程序的主功能编号

; BIOS 中断服务程序 INT10 的主功能编号有 06h, 02h, 13h
; ============================ Clear Screen
; BOIS 的终端服务 INT 10h 主功能号 AH=06h 的功能：按照指定范围清空窗口
; AL=滚动的列数, 若为 0 则则实现清屏功能
; BH=滚动后空出位置放入的属性
; CH=滚动范围左上角坐标列号
; CL=滚动范围左上角坐标行号
; DH=滚动范围右下角坐标列号
; DL=滚动范围右下角坐标行号
; BH=颜色属性
;   bit 0-2 : 字体颜色
;   bit 3   : 字体亮度
;   bit 4-6 : 背景颜色
;   bit 7   : 字体闪烁

; 用于按照指定范围滚动窗口
; AL=0 的话，则执行清屏功能
; 此时其他寄存器不起作用
	mov				ax,			0600h	; 清屏
	mov				bx,			0700h	; 字体为白色
	mov				cx,			0		; 初始化滚动弄范围
	mov				dx,			0184fh	; 翻滚范围右下角
	int				10h					; 触发中断



; 设置光标
; BOIS 的中断服务 INT 10h 主功能号 AH = 02h 的功能： 设定光标位置
; DH = 游标的列数
; DL = 游标的行数
; BH = 页码

; 将光标设置在屏幕的左上角 (0, 0) 处,
	mov				ax,			0200h	; 设置光标位置
	mov				bx,			0000h	; 第 0 页
	mov				dx,			0000h	; 左上角 0, 0 处
	int				10h					; 触发中断



; 在屏幕上显示 : Start Booting....
; BOIS 中断服务 INT 10h 的主功能号 AH=13h 可以实现字符串的显示功能

; AL=写入模式
;   AL=00h 字符串的属性由 BL 寄存器提供, CX 寄存器提供字符串长度(字节为单位), 显示后光标位置不变，即显示前的光标位置
;   AL=01h 同 AL=00h, 但是光标会移动到字符串末尾
;   AL=02h 字符串属性由每个字符后面紧跟着的字节提供，故 CX 寄存器提供的字符串长度改成以字为单位，显示后光标不变
;   AL=03h 同 AL=02h, 但是光标会移动至字符串尾端位置
; CX=字符串的长度
; DH=游标的坐标行号
; DL=游标的坐标列号
; ES:BP=>要显示字符串的内存地址
; BH=页码
; BL=字符属性/颜色属性
;   bit 0-2：字体颜色
;   bit 3  : 字体亮度
;   bit 4-6: 背景颜色
;   bit 7  : 字体闪烁
	mov				ax,			1301h	; 显示字符, 且光标移动到字符末尾
	mov				bx,			000fh	; 设置字体闪烁
	mov				dx,			0000h	; 游标置为左上角
	mov				cx,			10		; 字符串的长度为 10
	push			ax					; 备份 ax 的值
	mov				ax,			ds		; ax 储存数据段地址?
	mov				es,			ax		;  
	pop				ax					; 还原 ax 的值
	mov				bp,			StartBootMessage
	int				10h



; 重设软盘
; INT13, AH=00h 功能, 重置磁盘驱动器，为下一次读写软盘做准备
; DL=驱动器号, 00H-7FH：软盘;   80H-0FFH: 硬盘
;   DL=00h  代表第一个软盘驱动器 ("drive A:");
;   DL=01h  代表第二个软盘驱动器 ("drive B:");
;   DL=80h  代表第一个硬盘驱动器
;   DL=81h  代表第二个硬盘驱动器
	xor				ah,			ah		; 重置磁盘驱动器
	xor				dl,			dl		; 选择第一个软盘驱动器
	int				13h					; 触发 13H 中断

	jmp $


StartBootMessage:	db			"Start Boot"

	; 当前行被编译后的地址(机器码地址) - 本节(section) 的起始地址
	; 由于程序只有一个从 0x7C00 开始的节，所以($-$$)可以看作当前程序生成机器码的长度
	; 扇区大小为512字节，最后两个字节分别为 0xaa, 0x55, 故应当填充 512 - 2 - ($-$$) 个字节
	; times 伪指令用于多次重复操作，填充引导区
    times   510 - ($ - $$)      db      0
    ; 只有最后两个字节为 0xaa, 0x55 才会被识别为引导区
    dw      0xaa55