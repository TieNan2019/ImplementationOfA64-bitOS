org						0x7c00

BaseOfStack				equ			0x7c00

BaseOfLoader			equ			0x1000
OffsetOfLoader			equ			0x00

RootDirSectors			equ			14
SectorNumOfRootDirStart	equ			19
SectorNumOfFAT1Start	equ			1
SectorBalance			equ			17


; FAT12 文件系统引导扇区结构
; 注 : 12 指 该文件系统的表项位宽为 12 bit

	; ===============================================
	; 名称 : BS_jmpBoot			偏移 : 0	长度 : 3
	; ===============================================
	; BS_jmpBoot : 由于 BS_jmpBoot 字段后面不是可执行程序,
	; 而是 FAT12 文件系统的组成结构信息。因此要使得程序正常运
	; 行, 必须跳过这段内容
	jmp					short		Label_Start
	; jmp 是两字节机器码, 加上一个 nop 凑够三子节
	nop

	; ===============================================
	; 名称 : BS_OEMName			偏移 : 3	长度 : 8
	; ===============================================
	; 生产厂商名, 可自行定义
	BS_OEMName			db			'MINEboot'

	; ===============================================
	; 名称 : BPB_BytesPerSec	偏移 : 11	长度 : 2
	; ===============================================
	; 每扇区字节数
	BPB_BytesPerSec		dw			512
	; ===============================================
	; 名称 : BPB_SecPerClus		偏移 : 13	长度 : 1
	; ===============================================
	; 每簇的扇区数。由于每个扇区的容量只有512B, 过小的扇区容量
	; 可能会导致软盘读写过于频繁, 从而引入簇(cluster)概念, 簇
	; 将 2 的整数次方个扇区作为一个"原子"数据储存单元, 即每个簇 
	; 为 FAT 的最小数据储存单位
	BPB_SecPerClus		db			1
	; ===============================================
	; 名称 : BPB_RsvdSecCnt		偏移 : 14	长度 : 2
	; ===============================================
	; 保留扇区数, 指定保留扇区的数量，不能为 0。保留扇区起始于
	; FAT12 文件系统的第一个扇区, 对于 FAT12 而言此位必须为 1
	; 也就意味着引导扇区包含在保留扇区内, 所以 FAT 表从软盘的第
	; 二个扇区开始
	BPB_RsvdSecCnt		dw			1
	; ===============================================
	; 名称 : BPB_NumFATs		偏移 : 16	长度 : 1
	; ===============================================
	; FAT 表的份数, 设置为 2 是为了给 FAT 表准备一个备份表,
	; 因此 FAT 表 1 和 2 内的数据是一样的, FAT 表 2 是表 1
	; 的数据备份表
	BPB_NumFATs			db			2
	; ===============================================
	; 名称 : BPB_RootEntCnt		偏移 : 17	长度 : 2
	; ===============================================
	; 根目录可容纳的目录项数。
	BPB_RootEntCnt		dw			224
	; ===============================================
	; 名称 : BPB_TotSec16		偏移 : 19	长度 : 2
	; ===============================================
	; 总扇区数。包括保留扇区(内含引导扇区), FAT 表, 根目录区
	; 以及数据占用的全部扇区数。(1.44MB / 512B)
	BPB_TotSec16		dw			2880
	; ===============================================
	; 名称 : BPB_Media			偏移 : 21	长度 : 1
	; ===============================================
	; 介质描述符。描述储存介质类型，可移动介质常用 0xF0
	BPB_Media			db			0xf0
	; ===============================================
	; 名称 : BPB_FATSz16		偏移 : 22	长度 : 2
	; ===============================================
	; 记录 FAT 表占用的扇区数, FAT 表 1 和 2 有相同的容量, 
	; 均由此值记录
	BPB_FATSz16			dw			9
	; ===============================================
	; 名称 : BPB_SecPerTrk		偏移 : 24	长度 : 2
	; ===============================================
	; 每磁道扇区数。
	BPB_SecPerTrk		dw			18
	; ===============================================
	; 名称 : BPB_NumHeads		偏移 : 26	长度 : 2
	; ===============================================
	; 磁头数。
	BPB_NumHeads		dw			2
	; ===============================================
	; 名称 : BPB_HiddSec		偏移 : 28	长度 : 4
	; ===============================================
	; 隐藏扇区数
	BPB_HiddSec			dd			0
	; ===============================================
	; 名称 : BPB_TotSec32		偏移 : 32	长度 : 4
	; ===============================================
	; 如果 BPB_TotSec16 为 0, 则由这个值记录扇区数
	BPB_TotSec32		dd			0
	; ===============================================
	; 名称 : BS_DrvNum			偏移 : 36	长度 : 1
	; ===============================================
	; int 13 的驱动器号
	BS_DrvNum			db			0
	; ===============================================
	; 名称 : BS_Reserved1		偏移 : 37	长度 : 1
	; ===============================================
	; 保留
	BS_Reserved1		db			0
	; ===============================================
	; 名称 : BS_BootSig			偏移 : 38	长度 : 1
	; ===============================================
	; 拓展引导标记
	BS_BootSig			db			0x29
	; ===============================================
	; 名称 : BS_VolID			偏移 : 39	长度 : 4
	; ===============================================
	; 卷序列号
	BS_VolID			dd			0
	; ===============================================
	; 名称 : BS_VolLab			偏移 : 43	长度 : 11
	; ===============================================
	; 卷标
	BS_VolLab			db			'boot loader'
	; ===============================================
	; 名称 : BS_FileSysType		偏移 : 54	长度 : 8
	; ===============================================
	; 文件系统类型
	BS_FileSysType		db			'FAT12   '


; 引导代码
Label_Start:

	mov					ax,			cs
	mov					ds,			ax
	mov					es,			ax
	mov					ss,			ax
	mov					sp,			BaseOfStack

;=======	clear screen
	mov					ax,			0600h
	mov					bx,			0700h
	mov					cx,			0
	mov					dx,			0184fh
	int					10h

;=======	set focus

	mov					ax,			0200h
	mov					bx,			0000h
	mov					dx,			0000h
	int					10h

;=======	display on screen : Start Booting......

	mov					ax,			1301h
	mov					bx,			000fh
	mov					dx,			0000h
	mov					cx,			10
	push				ax
	mov					ax,			ds
	mov					es,			ax
	pop					ax
	mov					bp,			StartBootMessage
	int					10h

;=======	reset floppy

	xor					ah,			ah
	xor					dl,			dl
	int					13h

;=======	search loader.bin
	mov					word		[SectorNo],	SectorNumOfRootDirStart

Lable_Search_In_Root_Dir_Begin:

	cmp					word		[RootDirSizeForLoop],0
	jz					Label_No_LoaderBin
	dec					word		[RootDirSizeForLoop]
	mov					ax,			00h
	mov					es,			ax
	mov					bx,			8000h
	mov					ax,			[SectorNo]
	mov					cl,			1
	call				Func_ReadOneSector
	mov					si,			LoaderFileName
	mov					di,			8000h
	cld
	mov					dx,			10h




Label_Search_For_LoaderBin:

	cmp	dx,	0
	jz	Label_Goto_Next_Sector_In_Root_Dir
	dec	dx
	mov	cx,	11

Label_Cmp_FileName:

	cmp	cx,	0
	jz	Label_FileName_Found
	dec	cx
	lodsb
	cmp	al,	byte	[es:di]
	jz	Label_Go_On
	jmp	Label_Different

Label_Go_On:

	inc	di
	jmp	Label_Cmp_FileName

Label_Different:

	and	di,	0ffe0h
	add	di,	20h
	mov	si,	LoaderFileName
	jmp	Label_Search_For_LoaderBin

Label_Goto_Next_Sector_In_Root_Dir:

	add	word	[SectorNo],	1
	jmp	Lable_Search_In_Root_Dir_Begin

;=======	display on screen : ERROR:No LOADER Found

Label_No_LoaderBin:

	mov	ax,	1301h
	mov	bx,	008ch
	mov	dx,	0100h
	mov	cx,	21
	push	ax
	mov	ax,	ds
	mov	es,	ax
	pop	ax
	mov	bp,	NoLoaderMessage
	int	10h
	jmp	$

;=======	found loader.bin name in root director struct

Label_FileName_Found:

	mov	ax,	RootDirSectors
	and	di,	0ffe0h
	add	di,	01ah
	mov	cx,	word	[es:di]
	push	cx
	add	cx,	ax
	add	cx,	SectorBalance
	mov	ax,	BaseOfLoader
	mov	es,	ax
	mov	bx,	OffsetOfLoader
	mov	ax,	cx

Label_Go_On_Loading_File:
	push	ax
	push	bx
	mov	ah,	0eh
	mov	al,	'.'
	mov	bl,	0fh
	int	10h
	pop	bx
	pop	ax

	mov	cl,	1
	call	Func_ReadOneSector
	pop	ax
	call	Func_GetFATEntry
	cmp	ax,	0fffh
	jz	Label_File_Loaded
	push	ax
	mov	dx,	RootDirSectors
	add	ax,	dx
	add	ax,	SectorBalance
	add	bx,	[BPB_BytesPerSec]
	jmp	Label_Go_On_Loading_File

Label_File_Loaded:

	jmp	$

;=======	read one sector from floppy

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

;=======	get FAT Entry

Func_GetFATEntry:

	push	es
	push	bx
	push	ax
	mov	ax,	00
	mov	es,	ax
	pop	ax
	mov	byte	[Odd],	0
	mov	bx,	3
	mul	bx
	mov	bx,	2
	div	bx
	cmp	dx,	0
	jz	Label_Even
	mov	byte	[Odd],	1

Label_Even:

	xor	dx,	dx
	mov	bx,	[BPB_BytesPerSec]
	div	bx
	push	dx
	mov	bx,	8000h
	add	ax,	SectorNumOfFAT1Start
	mov	cl,	2
	call	Func_ReadOneSector

	pop	dx
	add	bx,	dx
	mov	ax,	[es:bx]
	cmp	byte	[Odd],	1
	jnz	Label_Even_2
	shr	ax,	4

Label_Even_2:
	and	ax,	0fffh
	pop	bx
	pop	es
	ret

;=======	tmp variable

RootDirSizeForLoop	dw	RootDirSectors
SectorNo		dw	0
Odd			db	0

;=======	display messages

StartBootMessage:	db	"Start Boot"
NoLoaderMessage:	db	"ERROR:No LOADER Found"
LoaderFileName:		db	"LOADER  BIN",0

;=======	fill zero until whole sector

	times	510 - ($ - $$)	db	0

; 盘尾结束标志, 0xAA55 用于标记引导盘的结尾
	dw	0xaa55