								;=======================================================
								; 文件名: Keyscan.asm
								; 功能描述: 键盘及数码管显示实验，通过8255控制。
								;     8255的B口控制数码管的段显示，A口控制键盘列扫描
								;     及数码管的位驱动，C口控制键盘的行扫描。
								;     按下按键，该按键对应的位置将按顺序显示在数码管上。
								;=======================================================

								IOY0         EQU   0600H          ;片选IOY0对应的端口始地址
								IOY1         EQU   0640H          ;片选IOY0对应的端口始地址
								
								MY8255_A     EQU   IOY0+00H*2     ;8255的A口地址
								MY8255_B     EQU   IOY0+01H*2     ;8255的B口地址
								MY8255_C     EQU   IOY0+02H*2     ;8255的C口地址
								MY8255_CON   EQU   IOY0+03H*2     ;8255的控制寄存器地址
								
								MY8254_COUNT0	EQU IOY1+00H*2   		;8254计数器0端口地址
								MY8254_COUNT1	EQU IOY1+01H*2   		;8254计数器1端口地址
								MY8254_COUNT2	EQU IOY1+02H*2   		;8254计数器2端口地址
								MY8254_MODE		EQU IOY1+03H*2   		;8254控制寄存器端口地址	
								




								SSTACK	SEGMENT STACK
										DW 16 DUP(?)
								SSTACK	ENDS		

								DATA  	SEGMENT
								
								Note		     DB 00H       ;音符索引			默认为10H，到时索引为LED全亮	
								Tone             DB 00H		;音调索引
								Range			 DB 00H		;音区索引
								
								Key               DB 00H		;保存当前键值   默认为10H,到时索引为LED全亮
								Flag              DB 00H		;录制状态FLAG	
								HAHA              DB 00H
								FREQ			DW 00H
								Time             DW 00H		;记录按下时间	
								REG_POINT DW 00H							
								DTABLE	DB 3FH,06H,5BH,4FH,66H,6DH,7DH,07H
										DB 7FH,6FH,77H,7CH,39H,5EH,79H,71H	
										

								
								
								
								
							
								List1 DW 221,248,278,294,330,371,416        ;音调×14 加音符×2
										DW 131,147,165,175,196,221,248
										DW 248,278,312,330,371,416,467
										DW 147,165,185,196,221,248,278
										DW 165,185,208,221,248,278,312
										DW 175,196,221,234,262,294,330
										DW 196,221,248,262,294,330,371
										
								List2 DW 441,495,556,589,661,742,833
										DW 495,556,624,661,742,833,935
										DW 262,294,330,350,393,441,495
										DW 294,330,371,393,441,495,556
										DW 330,371,416,441,495,556,624
										DW 350,393,441,467,525,589,661
										DW 393,441,495,525,589,661,742
										
								List3 DW 882,990,1112,1178,1322,1484,1665 
										DW 990,1112,1248,1322,1484,1665,1869
										DW 525,589,661,700,786,882,990
										DW 589,661,742,786,882,990,1112
										DW 661,742,833,882,990,1112,1248
										DW 700,786,882,935,1049,1178,1322
										DW 786,882,990,1049,1178,1322,1484
														
								REG DW 400 DUP(00H)               ; (频率＋N)  x 100  最多存一百个音符和长度

								
								
								
								DATA  	ENDS







								CODE 	SEGMENT
										ASSUME CS:CODE,DS:DATA
								START:	
										MOV AX,DATA
										MOV DS,AX       
										MOV AL,00H
										MOV DX,MY8255_CON			;写8255控制字  A：方式0输出 B：方式0输出 
																						;				      PC3~PC0 方式0输入  
																						;    A口控制键盘列扫描及数码管的位驱动
										MOV AL,81H							;    B口控制数码管的段显示
										OUT DX,AL                             ;    C口控制键盘的行扫描。
										
																			
										
										;MOV DX, MY8254_MODE			;初始化8254工作方式
										;MOV AL, 36H					;定时器0、方式3
										;OUT DX, AL

										
										
										
										
										
										
								BEGIN:	CALL DIS					;调用显示子程序
										CALL CLEAR					;清屏
										CALL CCSCAN				;扫描
										JNZ INK1                   ;有键按下，转到INK1
										JMP BEGIN                ;无键按下，转回begin 继续扫描                     
										
								INK1:	CALL DIS					; INK1：消抖子程序
										CALL DALLY					
										CALL DALLY					
										CALL CLEAR
										CALL CCSCAN
										JNZ INK2					;有键按下，转到INK2
										JMP BEGIN              ;无键按下，为抖动 回到BEGIN
										
								;确定按下键的位置
								INK2:	MOV CH,0FEH					;CH保存当前扫描的列数的驱动位数
										MOV CL,00H						;CL保存当前扫描的列数
								COLUM:	MOV AL,CH				;配置扫描的输出子程序
										MOV DX,MY8255_A 
										OUT DX,AL                         ;将1110送给控制列的A口（输出1110）
										MOV DX,MY8255_C 
										IN AL,DX							   ;读入行数据到AL
								L1:		TEST AL,01H         			;is Line1?      
										JNZ L2									;no,go on 
										MOV AL,00H          			;yes,is L1
										JMP KCODE
								L2:		TEST AL,02H         			;is L2?
										JNZ L3
										MOV AL,04H          			;L2
										JMP KCODE
								L3:		TEST AL,04H         			;is L3?
										JNZ L4
										MOV AL,08H          			;L3
										JMP KCODE
								L4:		TEST AL,08H         			;is L4?
										JNZ NEXT                            ;都不是 说明当前扫描的列无按键按下 跳到next
										MOV AL,0CH          			;L4
										
								;##########################################   检测键值区   ##########################################################################
								KCODE:	ADD AL,CL              ;计算键值 AL=4*行 CL=列
								
										CALL CHANGE_FLAG      ;根据是否是KEY10判断FLAG是否反转    
										CALL PUT_BUFF             ;根据键值存索引的子程序
										CALL GET_FREQ                 ;根据索引存频率
										CALL PUT_mode3				;置8253方式3
										CALL PLAY
										CALL CLEAR_REG
										;CALL START              ;开始播放
										
										
										PUSH AX
										
								KON: 	CALL DIS
										CALL CLEAR
										CALL DALLY
										CALL Time_add1           ;时间缓冲区＋1
										CALL CCSCAN
										
										JNZ KON					;如果有按键按下 继续显示

										
										;无按键按下  8253置方式1 按键和音符索引改FF  将存入录制内存  ;清时间缓存
										

										CALL PUT_mode1    
										CALL PUT_REG         ;要判断FLAG是否为1 来判断是否执行，还是直接RET
										CALL PUT_RESBUFF		;改变按键和音符的索引为00H
										CALL PUT_BLANK      ;要判断FLAG是否为1 来判断是否执行，还是直接RET
										CALL CLEAR_Time
										
										POP AX                ; 
									
								NEXT:	INC CL	                  ;列数+1						
										MOV AL,CH			  ;
										TEST AL,08H			 ; 检测驱动位数第四位是否为0 即判断是否扫描完成
										JZ KERR					 ;扫描完成 转KERR
										ROL AL,1					 ;扫描未完成，循环左移CH，继续扫描 
										MOV CH,AL
										JMP COLUM
										
								KERR:	JMP BEGIN          ;无按键按下 回去扫描
								;##########################################   检测键值区   ##########################################################################
								
								
								
								
								
								;##########################################①扫描显示部分   ##########################################################################
								CCSCAN:	
								PUSH AX
								PUSH DX
							MOV AL,00H					;键盘扫描子程序
										MOV DX,MY8255_A  
										OUT DX,AL								;A口控制的列输出0
										MOV DX,MY8255_C 					
										IN  AL,DX								;读入C口控制的行数据 此时C口为输入 全为1
										NOT AL									;翻转C口的数据 若有按键按下 则数据为一个1 其它0
										AND AL,0FH							;读入的行数据与1111相与 去除高位数据
										POP DX
										POP AX
										
										RET			
										
								CLEAR:	
										PUSH AX
										MOV DX,MY8255_B 			;清屏子程序
										MOV AL,00H
										OUT DX,AL
										POP AX
										RET
										
								DIS:	PUSH AX						;显示子程序
										LEA SI,Note           ; @@@将要显示的数的索引存在偏移地址为3000H的地方
										MOV DL,0DFH                       ;保存位段码到DL
										MOV AL,DL
										
								AGAIN:	PUSH DX
										MOV DX,MY8255_A 
										OUT DX,AL                                ;位驱动赋值 01_1111 选中最高位的数码管
										MOV AL,[SI]                               ;3000H开始的第一个数送给AL
										MOV BX,OFFSET DTABLE
										AND AX,00FFH                               ;@@@先定义好DTABLE 然后取DTABLE 第AL([SI]所指的数）个数送给AL
										ADD BX,AX
										MOV AL,[BX]
										MOV DX,MY8255_B 
										OUT DX,AL                                  ;输出存入的缓冲值
										
										CALL DALLY										    ; 延时
										INC SI												;[SI+1]
										POP DX											
										MOV AL,DL
										TEST AL,01H                           ;测试DL的第0位是否为0 若为0 则单次扫描完成，退出显示函数
										JZ  OUT1                                 ;若不为0  将DL的向右移一位  继续回到显示函数
										ROR AL,1								
										MOV DL,AL
										JMP AGAIN
								OUT1:	POP AX
										RET
										
								DALLY:	PUSH CX						;延时子程序
										PUSH AX
										MOV CX,0006H
								T1:		MOV AX,009FH
								T2:		DEC AX
										JNZ T2
										LOOP T1
										POP AX
										POP CX
										RET
								;##########################################①扫描显示部分   ##########################################################################


								;########################################## PUT_BUFF：②保存索引子程序   ##########################################################################
								PUT_BUFF:
										PUSH SI 
										PUSH BX
										
										LEA SI,Key
										MOV [SI],AL              ;存入键值
										
										CMP AL,00H
										JE BUF_Note
										CMP AL,01H
										JE BUF_Note										
										CMP AL,02H
										JE BUF_Note		
										CMP AL,03H
										JE BUF_Note
										CMP AL,04H
										JE BUF_Note
										CMP AL,05H
										JE BUF_Note
										CMP AL,06H
										JE BUF_Note
										CMP AL,07H
										JE BUF_Tone
										CMP AL,08H
										JE BUF_Range		
										POP BX
										POP SI
										RET												;非有效按键，返回
								BUF_Note:
										LEA SI,Note
										MOV [SI],AL
										POP BX
										POP SI
										RET
										
								BUF_Tone:                                 ;音调＋1
										LEA SI,Tone
										MOV BL,01H
										MOV BH,[SI]
										ADD BH,BL
										MOV [SI],BH
										CMP BH,07H					;音调防止溢出
										JE Tone_res
										POP BX
										POP SI
										RET
								Tone_res:
										MOV BH,00H					;音调防止溢出
										MOV [SI],BH
										POP BX
										POP SI
										RET
										
								BUF_Range:                                 ;音区＋1
										LEA SI,Range
										MOV BL,01H
										MOV BH,[SI]
										ADD BH,BL
										MOV [SI],BH
										CMP BH,03H					;音区防止溢出
										JE Range_res
										POP BX
										POP SI
										RET
								Range_res:
										MOV BH,00H					;音区防止溢出
										MOV [SI],BH
										POP BX
										POP SI
										RET
										

								;########################################## CHANGE_FLAG：③key10 改变录制FLAG子程序   #####################################################################
								CHANGE_FLAG:
										PUSH SI
										PUSH BX									
										CMP AL,10
										JE GOFLAG
										POP BX
										POP SI			
										RET
								GOFLAG:
										LEA SI,Flag
										MOV BL,01H
										MOV BH,00H
										CMP [SI],BL
										JE to_0
										CMP [SI],BH
										JE to_1
								to_0:MOV BYTE PTR[SI],00H
										POP BX
										POP SI			
										RET								
								to_1:MOV BYTE PTR [SI],01H
										POP BX
										POP SI			
										RET


								;########################################## GET_FREQ：④根据索引保存频率子程序   #####################################################################					
								GET_FREQ:
									PUSH SI
									PUSH BX
									PUSH AX
									PUSH DX
									

									;判断音区索引，跳转到对应音区的子程序
									LEA SI,Range
									MOV BL,[SI]
									CMP BL,00H
									JE GET_List1
									CMP BL,01H
									JE GET_List2
									CMP BL,02H
									JE GET_List3
									
								GET_List1:
								
									;存入音调，音符索引进BH，BL
									LEA SI,Note
									MOV BL,[SI]            ;BL保存音符索引
									LEA SI,Tone	
									MOV BH,[SI]			;BH保存音调索引
									
									;计算频率索引，保存进AL
									MOV AL,BH			   ;计算频率索引  频率索引=音调索引*7+音符索引
									MOV BH,14
									MUL BH					;AL(音调索引)*14 保存在AX
									ADD BL,BL
									AND BX,00FFH
									ADD AX,BX
									
									
									;根据频率索引，获得频率，保存在BX,再保存进FREQ
									LEA BX,List1        		;获得List1入口地址
									ADD BX,AX               	;获得目标频率的地址
									MOV BX,[BX]            ;获得频率，保存在BX
									LEA SI,FREQ
									MOV [SI],BX
									
									
									;弹出堆栈，中断返回
									POP DX
									POP AX
									POP BX
									POP SI
									RET

								GET_List2:

									;存入音调，音符索引进BH，BL
									LEA SI,Note
									MOV BL,[SI]            ;BL保存音符索引
									LEA SI,Tone	
									MOV BH,[SI]			;BH保存音调索引
									
									;计算频率索引，保存进AL
									MOV AL,BH			   ;计算频率索引  频率索引=音调索引*7+音符索引
									MOV BH,14
									MUL BH					;AL(音调索引)*14 保存在AX
									ADD BL,BL
									AND BX,00FFH
									ADD AX,BX
									
									;根据频率索引，获得频率，保存在BX
									LEA BX,List2        		;获得List1入口地址
									ADD BX,AX               	;获得目标频率的地址
									MOV BX,[BX]            ;获得频率，保存在BX
									LEA SI,FREQ
									MOV [SI],BX								

									
									;弹出堆栈，中断返回
									POP DX
									POP AX
									POP BX
									POP SI
									RET
								
								GET_List3:
								
									;存入音调，音符索引进BH，BL
									LEA SI,Note
									MOV BL,[SI]            ;BL保存音符索引
									LEA SI,Tone	
									MOV BH,[SI]			;BH保存音调索引
									
									;计算频率索引，保存进AL
									MOV AL,BH			   ;计算频率索引  频率索引=音调索引*7+音符索引
									MOV BH,14
									MUL BH					;AL(音调索引)*14 保存在AX
									ADD BL,BL
									AND BX,00FFH
									ADD AX,BX
									
									;根据频率索引，获得频率，保存在BX
									LEA BX,List3        		;获得List1入口地址
									ADD BX,AX               	;获得目标频率的地址
									MOV BX,[BX]            ;获得频率，保存在BX
									LEA SI,FREQ
									MOV [SI],BX																											
									
									;弹出堆栈，中断返回
									POP DX
									POP AX
									POP BX
									POP SI
									RET								
								
								
								
								
								
								
								
								
								
								
					
					
									
									
								;########################################## Time_add1：⑤时间缓冲加一子程序 #####################################################################	
								Time_add1:
								
									PUSH SI
									PUSH BX
								
									;时间索引+1
									LEA SI,Time
									MOV BX,WORD PTR [SI]
									INC BX
									MOV WORD PTR [SI],BX
									
									;弹出堆栈，中断返回
									POP BX
									POP SI
									RET
						
								
								
								
								;########################################## PUT_mode3：⑤置8253方式3，根据当前频率缓存，算出初值并送8253子程序 #########################################
								PUT_mode3:
									PUSH AX
									PUSH DX
									PUSH BX
									PUSH SI
									
									
										
									LEA SI,Key
									MOV [SI],AL              ;存入键值
									
									CMP AL,00H
									JE PUT_mode3_1
									CMP AL,01H
									JE PUT_mode3_1										
									CMP AL,02H
									JE PUT_mode3_1		
									CMP AL,03H
									JE PUT_mode3_1
									CMP AL,04H
									JE PUT_mode3_1
									CMP AL,05H
									JE PUT_mode3_1
									CMP AL,06H
									JE PUT_mode3_1		
									CMP AL,11
									JE PUT_mode3_1	
									POP SI
									POP BX
									POP DX
									POP AX
									RET	
									
								PUT_mode3_1:	
									MOV DX, MY8254_MODE			;初始化8254工作方式
									MOV AL, 36H					;定时器0、方式3
									OUT DX, AL

									;计算计数初值，并给8253送控制字，方式3，并送入计数初值
									MOV DX,0FH					;输入时钟为1MHz，1M = 0F4240H  
									MOV AX,4240H
									LEA SI,FREQ
									
									
									MOV BX,[SI]
									
									DIV  BX			;取出频率值计算计数初值，0F4240H / 输出频率（BX）
									MOV DX,MY8254_COUNT0
									OUT DX,AL					;装入计数初值
									MOV AL,AH
									OUT DX,AL	
							
							
									POP SI
									POP BX
									POP DX
									POP AX
									RET	
										
								;########################################## PUT_mode3：⑥置8253方式1，停止播放子程序 #########################################																
								PUT_mode1:
									PUSH DX
									PUSH AX
	
									;定时器0，置方式1
									MOV DX, MY8254_MODE			
									MOV AL, 32H					
									OUT DX, AL
									MOV AL,01H
									MOV DX,MY8254_COUNT0
									OUT DX,AL
									OUT DX,AL
	
									POP AX
									POP DX
									
									RET

								;########################################## PUT_RESBUFF：⑦清空键值和音符索引子程序 #########################################
								
								PUT_RESBUFF:
									PUSH SI
									
									;重置音符，键值索引为00H
									LEA SI,Note
									MOV BYTE PTR [SI],00
									LEA SI,Key
									MOV BYTE PTR [SI],00


								
									POP SI
									
									RET
								
								;########################################## CLEAR_Time：⑧清空时间缓存子程序 #########################################								
								CLEAR_Time:
								
									PUSH SI
									
									LEA SI,Time
									MOV BYTE PTR [SI],00H
									POP SI
									
									RET
									
								;########################################## PUT_REG：⑨录制子程序 #########################################		
								PUT_REG:
									
									PUSH AX
									PUSH BX
									PUSH CX
									PUSH DX
									PUSH SI
									
									;0到6的按键才判断是否录制
									CMP AL,00H
									JE PUT_REG_1
									CMP AL,01H
									JE PUT_REG_1										
									CMP AL,02H
									JE PUT_REG_1		
									CMP AL,03H
									JE PUT_REG_1
									CMP AL,04H
									JE PUT_REG_1
									CMP AL,05H
									JE PUT_REG_1
									CMP AL,06H
									JE PUT_REG_1	
									
									
									
									POP SI
									POP DX
									POP CX
									POP BX
									POP AX
									RET 
									
									
									
							
								PUT_REG_1:
								
									LEA SI,Flag
									CMP BYTE PTR [SI],00H
									JE FLAG0
								
								FLAG1:

									LEA SI,Time
									MOV AX,WORD PTR[SI]  ;AX保存时间量
									LEA SI,FREQ
									MOV DX,WORD PTR[SI]  ;DX保存频率
									
									LEA SI,REG_POINT    ;取内存指针保存在CX
									MOV CX,WORD PTR [SI]
									
									LEA BX,REG          ;BX保存播放首地址
									ADD BX,CX
									
									MOV WORD PTR [BX],DX         ;存频率
									INC CX              ;指针加2
									INC CX

									INC BX 
									INC BX            ;当前指向地址＋2
									
									MOV WORD PTR [BX],AX			;存时间
									
									INC CX              ;指针加2
									INC CX
									
									LEA SI,REG_POINT    ;取内存指针保存在CX									
									MOV [SI],CX         ;保存指针	
									
									POP SI
									POP DX
									POP CX
									POP BX
									POP AX
									
									RET 
									
								FLAG0:
								
									POP SI
									POP DX
									POP CX
									POP BX
									POP AX
								
									RET

								;########################################## PUT_BLANK：⑩key9的录制空白时间子程序 #########################################											
								PUT_BLANK:
									
									PUSH AX
									PUSH BX
									PUSH CX
									PUSH DX
									PUSH SI
									
									;0到6的按键才判断是否录制

									CMP AL,09H
									JE PUT_BLANK_1	
									
									
									
									POP SI
									POP DX
									POP CX
									POP BX
									POP AX
									RET 
									
									
									
							
								PUT_BLANK_1:
								
									LEA SI,Flag
									CMP BYTE PTR [SI],00H
									JE PUT_BLANK_1_FLAG0
								
								PUT_BLANK_1_FLAG1:

									LEA SI,Time
									MOV AX,WORD PTR[SI]  ;AX保存时间量
									LEA SI,FREQ
									MOV DX,0FFFFH  ;DX保存频率
									
									LEA SI,REG_POINT    ;取内存指针保存在CX
									MOV CX,WORD PTR [SI]
									
									LEA BX,REG          ;BX保存播放首地址
									ADD BX,CX
									
									MOV WORD PTR [BX],DX         ;存频率
									INC CX              ;指针加2
									INC CX

									INC BX 
									INC BX            ;当前指向地址＋2
									
									MOV WORD PTR [BX],AX			;存时间
									
									INC CX              ;指针加2
									INC CX
									
									LEA SI,REG_POINT    ;取内存指针保存在CX									
									MOV [SI],CX         ;保存指针	
									
									POP SI
									POP DX
									POP CX
									POP BX
									POP AX
									
									RET 
									
								PUT_BLANK_1_FLAG0:
								
									POP SI
									POP DX
									POP CX
									POP BX
									POP AX
								
									RET
								
								
								;########################################## CLEAR_REG：⑩key12的清空缓存子程序 #########################################											
								CLEAR_REG:
								
								PUSH AX
								PUSH BX
								PUSH CX
								PUSH DX
								PUSH SI
								
								CMP AL,12
								JE CLEAR_REG_0
								JMP CLEAR_REG_OUT

								CLEAR_REG_0:
								LEA SI,REG_POINT
								MOV WORD PTR [SI],00H        ;CX保存内存指针偏移量
								
	
								CLEAR_REG_OUT:
								POP SI
								POP DX
								POP CX
								POP BX
								POP AX
								RET
								;########################################## PLAY：⑪key11的播放子程序 #########################################			
								PLAY:
								
									PUSH AX
									PUSH BX
									PUSH CX
									PUSH DX
									PUSH SI
									
								CMP AL,11
								JE PLAY_0
								JMP CLEAR_REG_OUT									
									
									
									
								PLAY_0:	
									
									
									
								LEA BX,REG                   ;BX存入内存的起始地址

								
                                GOON_PLAY_0:
								
								
								
								MOV DX,WORD PTR[BX]       ;将播放频率存入DX
								CMP DX,0FFFFH
								JE PLAY_blank             ;判断是否为播放空的频率
								
								JMP PLAY_GOON           
								PLAY_blank:
								CALL PUT_mode1
								JMP PLAY_blank_GOON
								
								
								PLAY_GOON:
								LEA SI,FREQ								
								MOV [SI],DX								;将频率存入频率索引
								CALL PUT_mode3
								
								PLAY_blank_GOON:
								
								INC BX
								INC BX                                    ;指针加2 指向时间的地址
								

								MOV DX,WORD PTR[BX]  ;时间值存入DX
								CALL DALLY_PLAY
								CALL PUT_mode1								
								INC BX
								INC BX
								
								MOV CX,BX ;判断BX是否和尾指针相等 相等则播放结束，置方式1 返回 不相等则继续播放
								LEA SI,REG_POINT
								MOV BX,WORD PTR [SI]
								LEA SI,REG
								
								ADD BX,0142H
								
								
								CMP CX,BX
								JE OUT_PLAY
								MOV BX,CX
								JMP GOON_PLAY_0
								
								
								OUT_PLAY:
								;CALL PUT_mode1
									POP SI
									POP DX
									POP CX
									POP BX
									POP AX
									RET	
								
								;########################################## PLAY：⑫key12的播放时的延时子程序 #########################################			
								DALLY_PLAY:						;播放延时子程序，DX存入时间
								PUSH AX
								PUSH CX
								PUSH DX
								D0:		MOV CX,0032H
								D1:		MOV AX,009FH
								D2:		DEC AX
										JNZ D2
										LOOP D1
										DEC DX
										JNZ D0
										POP DX
										POP CX
										POP AX
										RET
									
			
								CODE	ENDS
										END START
