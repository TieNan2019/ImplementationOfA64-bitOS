org	10000h
	jmp	Label_Start

; 引入 FAT12 的文件结构
%include	"fat12.inc"

; 内核起始于 0x100000 (1 MB) 处, 因为 1 MB 以下的物理地址
; 并非全是可用空间, 所以选择一块平坦的区域
BaseOfKernelFile				equ			0x00
OffsetOfKernelFile				equ			0x100000

; 0x7E00 是内核程序的临时转存空间, 由于 BIOS 只支持 1 MB 以下
; 的物理空间寻址, 所以先将内核程序读入临时转存空间, 然后通过搬运到
; 1 MB 以上的内存空间中。 
BaseTmpOfKernelAddr				equ			0x00
OffsetTmpOfKernelFile			equ			0x7E00
; 当内存被搬走后, 该段临时内存就作为内存结构数据的储存空间
MemoryStructBufferAddr			equ			0x7E00



; 在进入保护模式之前, 先创建临时 GDT 表, 为 GDT 创建初始数据结构
[SECTION gdt]

LABEL_GDT:						dd			0,0
LABEL_DESC_CODE32:				dd			0x0000FFFF,0x00CF9A00
LABEL_DESC_DATA32:				dd			0x0000FFFF,0x00CF9200

GdtLen							equ			$ - LABEL_GDT
GdtPtr							dw			GdtLen - 1
								dd			LABEL_GDT
; 代码和数据段选择子
SelectorCode32					equ			LABEL_DESC_CODE32 - LABEL_GDT
SelectorData32					equ			LABEL_DESC_DATA32 - LABEL_GDT




; 为了切换到 IA-32e 模式准备临时 GDT 表结构
[SECTION gdt64]

LABEL_GDT64:					dq			0x0000000000000000
LABEL_DESC_CODE64:				dq			0x0020980000000000
LABEL_DESC_DATA64:				dq			0x0000920000000000

GdtLen64						equ			$ - LABEL_GDT64
GdtPtr64						dw			GdtLen64 - 1
	dd							LABEL_GDT64

SelectorCode64					equ			LABEL_DESC_CODE64 - LABEL_GDT64
SelectorData64					equ			LABEL_DESC_DATA64 - LABEL_GDT64


[SECTION .s16]
; 将处理器位宽调整为 16 位宽。此时如果使用 32 位宽的指令
; 需要在指令前加入前缀 '0x66', 在32位宽寻址指令前加入前
; 缀 '0x67'。
[BITS 16]

Label_Start:

	mov					ax,			cs
	mov					ds,			ax
	mov					es,			ax
	mov					ax,			0x00
	mov					ss,			ax
	mov					sp,			0x7c00


; 在屏幕上显示 Start Loader
	mov					ax,			1301h
	mov					bx,			000fh
	mov					dx,			0200h		;row 2
	mov					cx,			12
	push				ax
	mov					ax,			ds
	mov					es,			ax
	pop					ax
	mov					bp,			StartLoaderMessage
	int					10h


; 开启实模式下的 4 GB 寻址功能
	; 开启 A20 功能, 只有低 20 位地址线能够有效寻址。
	push				ax
	; A20 快速门 : 使用 IO 端口 0x92 来控制
	; 具体来说是置位 0x92 端口的第一位
	in					al,			92h
	or					al,			00000010b
	out					92h,		al
	pop	ax

	; A20 总线开启后, 关闭外部中断
	cli

	; 加载保护模式数据结构信息
	db					0x66
	lgdt				[GdtPtr]	

	; 置位 CR0 寄存器的第 0 位来开启保护模式
	mov					eax,		cr0
	or					eax,		1
	mov					cr0,		eax

	; 进入保护模式后, 为 FS 段寄存器加载新的数据段值
	mov					ax,			SelectorData32
	mov					fs,			ax
	; 数据一旦加载完成就推出保护模式
	; 此举是为了让 FS 段寄存器在实模式下寻址能力超过 1 MB
	; 即所谓的 Big Real Mode 模式
	mov					eax,		cr0
	and					al,			11111110b
	mov					cr0,		eax
	; 中断使能
	sti




; 初始化软盘启动
	xor					ah,			ah
	xor					dl,			dl
	int					13h




; 从文件系统中搜索 kernel.bin
	mov					word		[SectorNo],	SectorNumOfRootDirStart

Lable_Search_In_Root_Dir_Begin:

	cmp					word		[RootDirSizeForLoop], 0
	jz					Label_No_LoaderBin
	dec					word		[RootDirSizeForLoop]	
	mov					ax,			00h
	mov					es,			ax
	mov					bx,			8000h
	mov					ax,			[SectorNo]
	mov					cl,			1
	call				Func_ReadOneSector
	mov					si,			KernelFileName
	mov					di,			8000h
	cld
	mov					dx,			10h
	

Label_Search_For_LoaderBin:

	cmp					dx,			0
	jz					Label_Goto_Next_Sector_In_Root_Dir
	dec					dx
	mov					cx,			11

Label_Cmp_FileName:

	cmp					cx,			0
	jz					Label_FileName_Found
	dec					cx
	lodsb
	cmp					al, byte	[es:di]
	jz					Label_Go_On
	jmp					Label_Different


Label_Go_On:
	
	inc					di
	jmp					Label_Cmp_FileName

Label_Different:

	and					di,			0FFE0h
	add					di,			20h
	mov					si,			KernelFileName
	jmp					Label_Search_For_LoaderBin

Label_Goto_Next_Sector_In_Root_Dir:
	
	add					word		[SectorNo], 1
	jmp					Lable_Search_In_Root_Dir_Begin



; 如果没有找到 kernel.bin, 在屏幕输出 ERROR:No KERNEL Found
Label_No_LoaderBin:

	mov					ax,			1301h
	mov					bx,			008Ch
	mov					dx,			0300h
	mov					cx,			21
	push				ax
	mov					ax,			ds
	mov					es,			ax
	pop					ax
	mov					bp,			NoLoaderMessage
	int					10h
	jmp					$



; 如果搜索到 kernel.bin, 则将 kernel.bin 文件
; 内到数据读取至物理内存中
Label_FileName_Found:
	mov					ax,			RootDirSectors
	and					di,			0FFE0h
	add					di,			01Ah
	mov					cx,	word	[es:di]
	push				cx
	add					cx,			ax
	add					cx,			SectorBalance
	mov					eax,		BaseTmpOfKernelAddr	;BaseOfKernelFile
	mov					es,			eax
	mov					bx,			OffsetTmpOfKernelFile	;OffsetOfKernelFile
	mov					ax,			cx

Label_Go_On_Loading_File:
	push				ax
	push				bx
	mov					ah,			0Eh
	mov					al,			'.'
	mov					bl,			0Fh
	int					10h
	pop					bx
	pop					ax

	mov					cl,			1
	call				Func_ReadOneSector
	pop					ax

;;;;;;;;;;;;;;;;;;;;;;;	
	push				cx
	push				eax
	push				fs
	push				edi
	push				ds
	push				esi

	mov					cx,			200h
	mov					ax,			BaseOfKernelFile
	; 此处对 FS 进行了写操作, 如果直接移植到物理机会出现问题, 但在 boches 上可以正常工作
	mov					fs,			ax
	mov					edi, dword	[OffsetOfKernelFileCount]

	mov					ax,			BaseTmpOfKernelAddr
	mov					ds,			ax
	mov					esi,		OffsetTmpOfKernelFile


; 将 kernel 逐字节复制到 1M 以上的物理储存空间
Label_Mov_Kernel:
	
	mov					al,	byte	[ds:esi]
	mov					byte		[fs:edi], al

	inc					esi
	inc					edi

	; 借助循环拷贝 kernel.bin
	loop				Label_Mov_Kernel

	mov					eax,		0x1000
	mov					ds,			eax

	mov					dword		[OffsetOfKernelFileCount], edi

	pop					esi
	pop					ds
	pop					edi
	pop					fs
	pop					eax
	pop					cx
;;;;;;;;;;;;;;;;;;;;;;;


	call				Func_GetFATEntry
	cmp					ax,			0FFFh
	jz					Label_File_Loaded
	push				ax
	mov					dx,			RootDirSectors
	add					ax,			dx
	add					ax,			SectorBalance

	jmp					Label_Go_On_Loading_File




Label_File_Loaded:
	; 将 GS 段寄存器的基址设置在 0B800h 地址处
	; 从内存地址 0B800h 开始, 是专门用于显示字符的内存空间
	; 每个字符占用两个字节的内存, 低位保存显示字符, 高位保存属性
	mov					ax,			0B800h
	mov					gs,			ax
	; 成功将内核加载到 1M 以上内存空间后,
	; 在屏幕上显示一个 'G'
	mov					ah,			0Fh
	mov					al,			'G'
	mov					[gs:((80 * 0 + 39) * 2)], ax


; 等到 Loader 加载内核完毕, 便不需要软盘驱动器
; 利用 BIOS IO端口 3F2h 关闭软驱电机
KillMotor:
	push				dx
	mov					dx,			03F2h
	mov					al,			0
	out					dx,			al
	pop					dx




; 内核成功拷贝后, 就可以将临时转存空间用于保存物理地址空间信息
	mov					ax,			1301h
	mov					bx,			000Fh
	mov					dx,			0400h		;row 4
	mov					cx,			24
	push				ax
	mov					ax,			ds
	mov					es,			ax
	pop					ax
	mov					bp,			StartGetMemStructMessage
	int					10h


	mov					ebx,		0
	mov					ax,			0x00
	mov					es,			ax
	mov					di,			MemoryStructBufferAddr



Label_Get_Mem_Struct:
	; 通过 BIOS 的 INT 15h 中断来获取物理地址空间信息
	mov					eax,		0x0E820
	mov					ecx,		20
	mov					edx,		0x534D4150
	int					15h
	jc					Label_Get_Mem_Fail

	; 保存至 0x7E00 地址处的临时转存空间处
	add					di,			20

	cmp					ebx,		0
	jne					Label_Get_Mem_Struct
	jmp					Label_Get_Mem_OK



Label_Get_Mem_Fail:

	mov					ax,			1301h
	mov					bx,			008Ch
	mov					dx,			0500h		;row 5
	mov					cx,			23
	push				ax
	mov					ax,			ds
	mov					es,			ax
	pop					ax
	mov					bp,			GetMemStructErrMessage
	int					10h
	jmp					$



Label_Get_Mem_OK:
	
	mov					ax,			1301h
	mov					bx,			000Fh
	mov					dx,			0600h		;row 6
	mov					cx,			29
	push				ax
	mov					ax,			ds
	mov					es,			ax
	pop					ax
	mov					bp,			GetMemStructOKMessage
	int					10h	




; SVGA 信息
	mov					ax,			1301h
	mov					bx,			000Fh
	mov					dx,			0800h		;row 8
	mov					cx,			23
	push				ax
	mov					ax,			ds
	mov					es,			ax
	pop					ax
	mov					bp,			StartGetSVGAVBEInfoMessage
	int					10h

	mov					ax,			0x00
	mov					es,			ax
	mov					di,			0x8000
	mov					ax,			4F00h

	int					10h

	cmp					ax,			004Fh

	jz					.KO
	
;=======	Fail

	mov					ax,			1301h
	mov					bx,			008Ch
	mov					dx,			0900h		;row 9
	mov					cx,			23
	push				ax
	mov					ax,			ds
	mov					es,			ax
	pop					ax
	mov					bp,			GetSVGAVBEInfoErrMessage
	int					10h

	jmp					$

.KO:

	mov					ax,			1301h
	mov					bx,			000Fh
	mov					dx,			0A00h		;row 10
	mov					cx,			29
	push				ax
	mov					ax,			ds
	mov					es,			ax
	pop					ax
	mov					bp,			GetSVGAVBEInfoOKMessage
	int					10h

;=======	Get SVGA Mode Info

	mov					ax,			1301h
	mov					bx,			000Fh
	mov					dx,			0C00h		;row 12
	mov					cx,			24
	push				ax
	mov					ax,			ds
	mov					es,			ax
	pop					ax
	mov					bp,			StartGetSVGAModeInfoMessage
	int					10h


	mov					ax,			0x00
	mov					es,			ax
	mov					si,			0x800e

	mov					esi, dword	[es:si]
	mov					edi,		0x8200

Label_SVGA_Mode_Info_Get:

	mov					cx, word	[es:esi]

;=======	display SVGA mode information

	push				ax
	
	mov					ax,			00h
	mov					al,			ch
	call				Label_DispAL

	mov					ax,			00h
	mov					al,			cl	
	call				Label_DispAL
	
	pop					ax

;=======
	
	cmp					cx,			0FFFFh
	jz					Label_SVGA_Mode_Info_Finish

	mov					ax,			4F01h
	int					10h

	cmp					ax,			004Fh

	jnz					Label_SVGA_Mode_Info_FAIL	

	add					esi,		2
	add					edi,		0x100

	jmp					Label_SVGA_Mode_Info_Get




Label_SVGA_Mode_Info_FAIL:

	mov					ax,			1301h
	mov					bx,			008Ch
	mov					dx,			0D00h		;row 13
	mov					cx,			24
	push				ax
	mov					ax,			ds
	mov					es,			ax
	pop					ax
	mov					bp,			GetSVGAModeInfoErrMessage
	int					10h

Label_SET_SVGA_Mode_VESA_VBE_FAIL:
	jmp					$


Label_SVGA_Mode_Info_Finish:

	mov					ax,			1301h
	mov					bx,			000Fh
	mov					dx,			0E00h		;row 14
	mov					cx,			30
	push				ax
	mov					ax,			ds
	mov					es,			ax
	pop					ax
	mov					bp,			GetSVGAModeInfoOKMessage
	int					10h

	; 可以在此处加入踏步观察加载结果
	;jmp					$

;=======	set the SVGA mode(VESA VBE)

	mov					ax,			4F02h
	mov					bx,			4180h	;========================mode : 0x180 or 0x143
	int					10h

	cmp					ax,			004Fh
	jnz					Label_SET_SVGA_Mode_VESA_VBE_FAIL



;=======	init IDT GDT goto protect mode

	; 屏蔽硬件中断, 保证切换到保护模式的过程中不产生异常和中断
	cli			;======close interrupt

	; 加入 0x66 前缀, 用于修饰当前的指令操作数是 32 位宽
	db					0x66
	lgdt				[GdtPtr]

;	db	0x66
;	lidt	[IDT_POINTER]

	mov					eax,		cr0
	or					eax,		1
	mov					cr0,		eax	

	jmp					dword		SelectorCode32:GO_TO_TMP_Protect




; 
[SECTION .s32]
[BITS 32]

GO_TO_TMP_Protect:
	; 初始化段寄存器及其指针
	mov					ax,			0x10
	mov					ds,			ax
	mov					es,			ax
	mov					fs,			ax
	mov					ss,			ax
	mov					esp,		7E00h

	; 检测处理器是否支持长模式 (IA-32e)
	call				support_long_mode
	test				eax,		eax

	jz					no_support



; 位 IA-32e 模式配置临时页目录项和页表项
	mov					dword		[0x90000], 0x91007
	mov					dword		[0x90800], 0x91007
	mov					dword		[0x91000], 0x92007
	mov					dword		[0x92000], 0x000083
	mov					dword		[0x92008], 0x200083
	mov					dword		[0x92010], 0x400083
	mov					dword		[0x92018], 0x600083
	mov					dword		[0x92020], 0x800083
	mov					dword		[0x92028], 0xa00083




; 

	db					0x66
	; 利用 lgdt 指令将 IA-32e 模式的临时 GDT
	; 加载到 GDTR 寄存器, 并将临时 GDT 的表初
	; 始化到各个数据段寄存器 (CS 寄存器除外)。由于
	; CS 寄存器不能够采用直接赋值的方式改变, 所以
	; 必须借助跨字段跳转 (far JMP) 或者 跨字段调
	; 用 (far CALL) 才能实现。
	lgdt				[GdtPtr64]
	mov					ax,			0x10
	mov					ds,			ax
	mov					es,			ax
	mov					fs,			ax
	mov					gs,			ax
	mov					ss,			ax

	mov					esp,		7E00h
	; DS, ES, FS, GS, SS 段寄存器加载了 IA-32e
	; 模式的段描述符后, 他们的段集地址和段限长都已经
	; 失效 (清零)。而代码段寄存器(CS)仍然在保护模式
	; 下, 其基地址和段限长仍然有效。



; 继续执行 IA32-e 模式的切换
; 通过置位 CR4 控制器的的 PAE 标志位
; 开启物理地址拓展功能
	mov	eax,	cr4
	bts	eax,	5
	mov	cr4,	eax



; 将临时页目录的收地址设置到 CR3 控制寄存器中。
	mov	eax,	0x90000
	mov	cr3,	eax



; 置位 IA32_EFER 寄存器的 LME 使能 IA-32e 模式
	mov	ecx,	0C0000080h		;IA32_EFER
	rdmsr

	bts	eax,	8
	wrmsr



;=======	open PE and paging
; 最后使能分页机制, 完成了 IA-32e 的模式切换工作
	mov	eax,	cr0
	bts	eax,	0
	bts	eax,	31
	mov	cr0,	eax

; 至此, 处理器进入了 IA-32e 模式。但是处理器仍然在
; 执行保护模式的程序,这种状态成为兼容模式。
; 若要真的进入 IA-32e 模式, 需要用跳转/调用指令将
; CS 段寄存器的值更新位 IA-32e 模式的代码段描述符。

; 经过这次跳转, 处理器的控制权也将交给内核。
; Loader 程序完成了它的任务, 占用空间可以另作其他用途。
	jmp	SelectorCode64:OffsetOfKernelFile


; 检测处理器是否支持长模式
support_long_mode:
	; 只有 cpuid 指令的拓展功能号大于 0x80000000 时,
	; 才有可能支持 64 位的长模式
	mov					eax,			0x80000000
	cpuid
	cmp					eax,			0x80000001
	setnb				al	
	jb					support_long_mode_done
	mov					eax,			0x80000001
	cpuid
	bt					edx,			29
	setc				al

support_long_mode_done:
	
	movzx				eax,			al
	ret

; 不支持长模式则踏步
no_support:
	jmp					$



; 读取软盘
[SECTION .s16lib]
[BITS 16]

Func_ReadOneSector:
	
	push	bp
	mov	bp,	sp
	sub	esp,	2
	mov	byte	[bp - 2],	cl
	push	bx
	mov	bl,	[BPB_SecPerTrk]
	div	bl
	inc	ah
	mov	cl,	ah
	mov	dh,	al
	shr	al,	1
	mov	ch,	al
	and	dh,	1
	pop	bx
	mov	dl,	[BS_DrvNum]
Label_Go_On_Reading:
	mov	ah,	2
	mov	al,	byte	[bp - 2]
	int	13h
	jc	Label_Go_On_Reading
	add	esp,	2
	pop	bp
	ret


; 解析 FAT12 文件系统
Func_GetFATEntry:

	push				es
	push				bx
	push				ax
	mov					ax,			00
	mov					es,			ax
	pop					ax
	mov					byte		[Odd], 0
	mov					bx,			3
	mul					bx
	mov					bx,			2
	div					bx
	cmp					dx,			0
	jz					Label_Even
	mov					byte		[Odd], 1



Label_Even:

	xor					dx,			dx
	mov					bx,			[BPB_BytesPerSec]
	div					bx
	push				dx
	mov					bx,			8000h
	add					ax,			SectorNumOfFAT1Start
	mov					cl,			2
	call				Func_ReadOneSector
	
	pop					dx
	add					bx,			dx
	mov					ax,			[es:bx]
	cmp					byte		[Odd], 1
	jnz					Label_Even_2
	shr					ax,			4

Label_Even_2:
	and					ax,			0FFFh
	pop					bx
	pop					es
	ret



; 显示 16 进制数
Label_DispAL:

	push				ecx
	push				edx
	push				edi

	mov					edi,		[DisplayPosition]
	mov					ah,			0Fh
	mov					dl,			al
	shr					al,			4
	mov					ecx,		2

.begin:

	and					al,			0Fh
	cmp					al,			9
	ja					.1
	add					al,			'0'
	jmp					.2


.1:

	sub					al,			0Ah
	add					al,			'A'
.2:

	mov					[gs:edi],	ax
	add					edi,		2
	
	mov					al,			dl
	loop				.begin

	mov					[DisplayPosition],	edi

	pop					edi
	pop					edx
	pop	ecx
	
	ret



; 为 IDT 开辟内存空间
IDT:
	times				0x50			dq	0
IDT_END:

IDT_POINTER:
	dw					IDT_END - IDT - 1
	dd					IDT

;=======	tmp variable

RootDirSizeForLoop	dw	RootDirSectors
SectorNo		dw	0
Odd			db	0
OffsetOfKernelFileCount	dd	OffsetOfKernelFile

DisplayPosition		dd	0

;=======	display messages

StartLoaderMessage:	db	"Start Loader"
NoLoaderMessage:	db	"ERROR:No KERNEL Found"
KernelFileName:		db	"KERNEL  BIN",0
StartGetMemStructMessage:	db	"Start Get Memory Struct."
GetMemStructErrMessage:	db	"Get Memory Struct ERROR"
GetMemStructOKMessage:	db	"Get Memory Struct SUCCESSFUL!"

StartGetSVGAVBEInfoMessage:	db	"Start Get SVGA VBE Info"
GetSVGAVBEInfoErrMessage:	db	"Get SVGA VBE Info ERROR"
GetSVGAVBEInfoOKMessage:	db	"Get SVGA VBE Info SUCCESSFUL!"

StartGetSVGAModeInfoMessage:	db	"Start Get SVGA Mode Info"
GetSVGAModeInfoErrMessage:	db	"Get SVGA Mode Info ERROR"
GetSVGAModeInfoOKMessage:	db	"Get SVGA Mode Info SUCCESSFUL!"