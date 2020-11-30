void Start_Kernel(void)
{
	/* 在 head.S 中，我们已经将帧缓存的物理基地址映射到 *
	 * 了线性地址 0xffff800000a00000 和 0xa0000 处  */
	int *addr = (int *)0xffff800000a00000;
	int i;

	/* 1440x20 的红条 */
	for(i = 0 ;i<1440*20;i++)
	{
		*((char *)addr+0)=(char)0x00;
		*((char *)addr+1)=(char)0x00;
		*((char *)addr+2)=(char)0xff;
		*((char *)addr+3)=(char)0x00;
		addr +=1;
	}

	/* 1440x20 的绿条 */
	for(i = 0 ;i<1440*20;i++)
	{
		*((char *)addr+0)=(char)0x00;
		*((char *)addr+1)=(char)0xff;
		*((char *)addr+2)=(char)0x00;
		*((char *)addr+3)=(char)0x00;
		addr +=1;
	}

	/* 1440x20 的蓝条 */
	for(i = 0 ;i<1440*20;i++)
	{
		*((char *)addr+0)=(char)0xff;
		*((char *)addr+1)=(char)0x00;
		*((char *)addr+2)=(char)0x00;
		*((char *)addr+3)=(char)0x00;
		addr +=1;
	}

	/* 1440x20 的白条 */
	for(i = 0 ;i<1440*20;i++)
	{
		*((char *)addr+0)=(char)0xff;
		*((char *)addr+1)=(char)0xff;
		*((char *)addr+2)=(char)0xff;
		*((char *)addr+3)=(char)0x00;
		addr +=1;
	}

	while(1)
		;
}