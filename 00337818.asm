; Luca Sartori Boni
; Cartão 00337818
; Trabalho Intel - Estenografia

.model small
.stack

CR		equ		13
LF		equ		10

.data
AskFileName     db  "Entre com o nome do arquivo de entrada: ",0
FileName        db  101 dup (?)
NewLine         db  CR,LF,0
txtExt          db  ".txt",0
krpExt          db  ".krp",0
FileNametxt     db  104 dup (?)
FileNamekrp     db  104 dup (?)
errorMsg1       db  "Falha ao abrir o arquivo, verifique o nome: ",0
AskMessage      db  CR,LF,"Entre com a mensagem a ser criptografada (maximo de 100 caracteres):",CR,LF,0
noMsgMsg        db  CR,LF,LF,"A mensagem nao possui nenhum caractere valido!",0
ErrorReadMsg    db  CR,LF,LF,"Erro ao ler o arquivo de entrada! O programa sera encerrado.",CR,LF,0
errorCreateOpen db  CR,LF,LF,"Erro ao criar/abrir o arquivo de saida! O programa sera encerrado.",CR,LF,0
errorWritingMsg db  " - Erro ao escrever no arquivo de saída! Foi gerado um arquivo parcial.",CR,LF,0
errorFileSize   db  " - Houve um erro ao medir o tamanho do arquivo de entrada.",CR,LF,0
invalidCharsMsg db  " - Ha caracteres invalidos na mensagem. Estes foram ignorados na encriptacao.",CR,LF,0
inFileTooLarge  db  " - O arquivo de entrada excede 64 kiB!",CR,LF,0
EndFileMsg      db  " - O programa chegou ao fim do arquivo de entrada; nao foi possivel encontrar um   ou mais simbolo(s) da frase. Foi gerado um arquivo de saida parcial.",CR,LF,0
infos1          db  CR,LF,LF,"**************************** Relatorio da execucao: ****************************",CR,LF,LF,0
infos2          db  " - Tamanho do arquivo de entrada: ",0
infos3          db  " bytes",CR,LF,0
infos4          db  " - Tamanho da mensagem criptografada: ",0
infos5          db  " - Nome do arquivo de saida: ",0
noErrorMsg      db  CR,LF,"**********************  Procedimento realizado sem erros. **********************",CR,LF,LF,0
tempMessage     db  101 dup (?)
Message         db  101 dup (?)
encryptedMsg    dw  101 dup (0)
messageSize     dw  0
messageSizeStr  db  6 dup (0)
inFile          dw  ?
outFile         dw  ?
readBuffer      dw  ?
DTA             dw  43 dup (?)
fileSize        dw  ?
fileSizeStr     db  6 dup (0)
errorCodes      db  0   
                        ; bit 0: mensagem tem caracteres inválidos | bit 1: problema na leitura do arquivo de entrada
                        ; bit 2: o arquivo de entrada não possui caracteres suficientes | bit 3: problema na medição do tamanho do arquivo de entrada
                        ; bit 4: o arquivo de entrada possui mais do que 64 kiB | bit 5: arquivo de entrada possui exatamente 64 kiB
                        ; bit 6: erro na criação/abertura do arquivo de saída | bit 7: erro na escrita do arquivo de saída

.code
.startup

        ;printf_s(bx=AskFileName)
        lea     bx,AskFileName
        call    printf_s

readFileName:
        ;ReadString(bx=FileName, cx=100)
    	mov	cx,100
	lea     bx,FileName
	call	ReadString
        ;addstr(bx=FileName, ax=txtExt, di=FileNametxt)
        lea     bx,FileName
        lea     ax,txtExt
        lea     di,FileNametxt
        call    addstr

        ;Pula a linha
        lea     bx, NewLine
        call    printf_s

        ;Abre o arquivo de entrada
	call    openInput
        jnc     measureSize
        lea     bx,errorMsg1
        call    printf_s
        jmp     readFileName

measureSize:
        ;Mede o tamanho do arquivo de entrada
        call    fileLength

        ;Converte o tamanho do arquivo para uma string
        mov     ax,fileSize
        lea     di,fileSizeStr
        call    itoa
readMessage:
        ;printf_s(bx=AskMessage)
        lea     bx,AskMessage
        call    printf_s

        ;ReadString(bx=Message, cx=100)
        mov     cx,100
        lea     bx,tempMessage
        call    ReadString

        ;Remove caracteres inválidos
        lea     si,tempMessage
        lea     di,Message
        call    convertMsg

        ;Testa se a mensagem possui algum caractere
        cmp     messageSize,0
        jne     msgitoa
        lea     bx,noMsgMsg
        call    printf_s
        jmp     readMessage

msgitoa:
        ;Converte o tamanho da mensagem em string
        mov     ax,messageSize
        lea     di,messageSizeStr
        call    itoa

        ;Faz a encriptação
        call    encrypt

        ;Fecha o arquivo de entrada
        call    closeInput

        ;Testa se houve erro na leitura do arquivo
        test    errorCodes,2
        jnz     endOfProgram

continueEncryption:
        ;addstr(bx=FileName, ax=krpExt, di=FileNamekrp)
        lea     bx,FileName
        lea     ax,krpExt
        lea     di,FileNamekrp
        call    addstr

        ;Cria o arquivo de saída
        call    createOutput
        ;Abre o arquivo no modo de escrita
        call    openOutput

        ;Testa se houve erro na criação, abertura do arquivo
        test    errorCodes,64
        jz      writeMsg
        lea     bx,errorCreateOpen
        call    printf_s
        jmp     endOfProgram

writeMsg:
        ;Escreve a mensagem criptografada
        call    writeMessage
        ;Fecha o arquivo de saída
        call    closeOutput

printfInfos:
        ;Imprime o relatório
        lea     bx,infos1
        call    printf_s
                                ;Testa se houve erro na medição do tamanho do arquivo
        test    errorCodes,8
        jz      testProblem2
        lea     bx,errorFileSize
        call    printf_s
        jmp     continueinfos2
testProblem2:                   ;Testa se o arquivo de entrada é maior do que 64 kiB
        test    errorCodes,32
        jnz     fileExactly64kb
        test    errorCodes,16
        jz      continueinfos
        lea     bx,inFileTooLarge
        call    printf_s
        jmp     continueinfos2
fileExactly64kb:
        lea     bx,fileSizeStr
        mov     [bx],'6'
        mov     [bx+1],'5'
        mov     [bx+2],'5'
        mov     [bx+3],'3'
        mov     [bx+4],'6'
        mov     [bx+5],0
continueinfos:
        lea     bx,infos2
        call    printf_s
        lea     bx,fileSizeStr
        call    printf_s
        lea     bx,infos3
        call    printf_s
continueinfos2:
        lea     bx,infos4
        call    printf_s
        lea     bx,messageSizeStr
        call    printf_s
        lea     bx,infos3
        call    printf_s
        lea     bx,infos5
        call    printf_s
        lea     bx,FileNamekrp
        call    printf_s
        lea     bx,NewLine
        call    printf_s
        call    printf_s
                                ;Testa se conseguiu encontrar todos os caracteres no arquivo de entrada
        test    errorCodes,4
        jz      nextErrorTest1
        lea     bx,EndFileMsg
        call    printf_s
nextErrorTest1:                 ;Testa se há caracteres inválidos na mensagem (espaço também é considerado inválido)
        test    errorCodes,1
        jz      nextErrorTest2
        lea     bx,invalidCharsMsg
        call    printf_s
nextErrorTest2:                 ;Testa se houve erro na escrita do arquivo
        test    errorCodes,128
        jz      testNoError
        lea     bx,errorWritingMsg
        call    printf_s
testNoError:                    ;Testa se não houve erros
        mov     al,errorCodes
        test    al,0DFH         ;Bit 5 não é necessariamente um erro, somente uma exceção
        jnz     endOfProgram
        lea     bx,noErrorMsg
        call    printf_s

endOfProgram:

.exit

; ---------------------------------------------------------------------
; Subrotina para leitura de uma string - retirada do moodle e adaptada
; ---------------------------------------------------------------------
ReadString	proc	near

        ;Pos = 0
        mov		dx,0

RDSTR_1:
        ;while(1) {
        ;       al = Int21(7)		// Espera pelo teclado
        mov	ah,7
        int	21H

        ;	if (al==CR) {
        cmp	al,0DH
        jne	RDSTR_A

        ;		*S = '\0'
        mov	byte ptr[bx],0
        ;		return
        mov     messageSize,dx
        ret
        ;	}

RDSTR_A:
        ;	if (al==BS) {
        cmp	al,08H
        jne	RDSTR_B

        ;		if (Pos==0) continue;
        cmp	dx,0
        jz	RDSTR_1

        ;		Print (BS, SPACE, BS)
        push	dx
        
        mov	dl,08H
        mov	ah,2
        int	21H
        
        mov	dl,' '
        mov	ah,2
        int	21H
        
        mov	dl,08H
        mov	ah,2
        int	21H
        
        pop	dx

        ;		--s
        dec	bx
        ;		++M
        inc	cx
        ;		--Pos
        dec	dx
        
        ;	}
        jmp	RDSTR_1

RDSTR_B:
        ;	if (M==0) continue
        cmp	cx,0
        je	RDSTR_1

        ;	if (al>=SPACE) {
        cmp	al,' '
        jb	RDSTR_1

        ;		*S = al
        mov	[bx],al

        ;		++S
        inc	bx
        ;		--M
        dec	cx
        ;		++Pos
        inc	dx

        ;		Int21 (s, AL)
        push	dx
        mov	dl,al
        mov	ah,2
        int	21H
        pop	dx

        ;	}
        ;}
        jmp	RDSTR_1

ReadString	endp

; ---------------------------------------------------------------------
; Subrotina para impressão de uma string - retirada do moodle e adaptada
; ---------------------------------------------------------------------
printf_s	proc	near

        push    dx
        push    ax
        push    bx
ps_1:
;	while (*s!='\0') {
        mov	dl,[bx]
        cmp	dl,0
        je	ps_2

;		putchar(*s)
        push	bx
        mov	ah,2
        int	21H
        pop	bx

;		++s;
        inc	bx
		
;	}
	jmp	ps_1
		
ps_2:
        pop     bx
        pop     ax
        pop     dx
	ret
	
printf_s	endp

; ---------------------------------------------------------------------
; Subrotina para concatenar uma string em outra (adiciona str2 em str1)
; e retorna em strout

;void addstr(char *str1 -> BX, char *str2 -> AX, char *strout -> DI){
;   while(*str1!='\0'){
;       *strout=*str1;
;       strout++;
;       str1++;
;   }
;   while(*str2!='\0'){
;       *strout=*str2;
;       strout++;
;       str2++;
;   }
;   strout++;
;   *strout='\0';
;}
; ---------------------------------------------------------------------
addstr      proc    near
;   while(*str1!='\0'){
        mov	dl,[bx]
        cmp	dl,0
        je	ads1

;       *strout=*str1;
        mov     [di],dl
;       strout++;
        inc     di
;       str1++;
        inc     bx
        jmp     addstr

ads1:
;   while(*str2!='\0'){
        mov     bx,ax
        mov	dl,[bx]
        cmp	dl,0
        je	ads2

;       *strout=*str2;
        mov     dl,[bx]
        mov     byte ptr [di],dl

;       strout++;
        inc     di
;       str2++;
        inc     ax
;   }
        jmp     ads1

ads2:
;   strout++;
        inc     di
;   *strout='\0';
        mov     byte ptr [di],0
;}
        ret

addstr endp

; ---------------------------------------------------------------------
; Subrotina para abrir o arquivo de entrada e salvar o handle na variável
; ---------------------------------------------------------------------
openInput     proc    near

        lea     dx,FileNametxt
        mov     ah,3DH
        mov     al,0
        int     21H
        mov     inFile,ax

        ret

openInput     endp

; ---------------------------------------------------------------------
; Subrotina para determinar o tamanho do arquivo de entrada
; ---------------------------------------------------------------------
fileLength      proc    near
        lea     dx,DTA
        mov     ah,1AH
        int     21H                     ; faz com que os dados do arquivo sejam salvos em DTA
        mov     ah,4EH
        mov     cx,0
        lea     dx,FileNametxt
        int     21H                     ; recebe os dados do arquivo em DTA
        jc      errorInMeasuring        ; se houve carry, houve erro
        lea     bx,DTA
        mov     ax,word ptr[bx+26]      ; o tamanho do arquivo fica salvo em uma dword em DTA+26
        mov     fileSize,ax
        mov     ax,word ptr[bx+28]
        cmp     ax,0                    ; testa se é maior que 64kiB
        jne     testFileTooLarge
        ret

errorInMeasuring:
        or      errorCodes,8
        ret

testFileTooLarge:
        cmp     ax,1
        jne     fileTooLarge
        cmp     fileSize,0
        jne     fileTooLarge
        or      errorCodes,32
        ret

fileTooLarge:
        or      errorCodes,16
        ret

fileLength      endp

; ---------------------------------------------------------------------
; Subrotina para fechar o arquivo de entrada
; ---------------------------------------------------------------------
closeInput      proc    near

        lea     bx,inFile
        mov     ah,3EH
        int     21H
        ret

closeInput      endp

; ---------------------------------------------------------------------
; Subrotina para converter a mensagem lida em uma string que contenha
; somente caracteres válidos. Também informa se há caracteres inválidos
;
;void convertMsg(char *strs -> SI, char *strd -> DI){
;   while(*strs!='\0'){
;       if(*strs<'!' || *strs>'~'){
;           *strd=*strs;
;           strd++;
;       }else{
;           errorCodes=(errorCodes|(01H));
;       }
;       strs++;
;   }
;   strd++;
;   *strd='\0';
;}
; ---------------------------------------------------------------------
convertMsg      proc    near

;   while(*strs!='\0'){
        mov     dl,[si]
        cmp     dl,0
        je      ct2
;       if(*strs<'!' || *strs>'~'){
        cmp     dl,'!'
        jb      invalidchar
        cmp     dl,'~'
        ja      invalidchar
;           *strd=*strs;
        mov     byte ptr [di],dl
;           strd++;
        inc     di
        jmp     ct1
;       }

invalidchar:
;       }else{
;           errorCodes=(errorCodes|(01H));
        or     errorCodes,1
        dec    messageSize              ; diminui o tamanho da mensagem, uma vez que o caractere não é processado.
;       }
        jmp     ct1

ct1:
;       strs++;
        inc     si
;   }
        jmp     convertMsg

ct2:
;   strd++;
        inc     di
;   *strd='\0';
        mov     byte ptr [di],0
;}
        ret

convertMsg      endp

; ---------------------------------------------------------------------
; Subrotina para criptografar a mensagem
; SI: mensagem a ser criptografada
; DI: contador da posição
; BP: vetor que armazena a mensagem encriptada
; ---------------------------------------------------------------------
encrypt         proc    near
    
        lea     si,Message
        mov     di,1
        lea     bp,encryptedMsg
        mov     bx,inFile               ; preapara os registradores

en1:
        mov     ah,42H
        mov     al,0
        mov     cx,0
        mov     dx,1
        int     21H                     ; interrupção 21,42 com AL e CX em zero -> retorna ao começo do arquivo
        jc      handleReadError
en2:
        cmp     byte ptr [si],0
        je      eos                     ; verifica se a string chegou ao fim
        mov     ah,3FH
        mov     cx,1
        lea     dx,readBuffer
        int     21H                     ; chama a interrupção para leitura do arquivo de entrada
        jc      handleReadError         ; se houve erro na leitura, informa
        cmp     ax,0                
        je      eof                     ; se AX=0 (leu zero bytes), chegou ao fim do arquivo
        cmp     di,0
        je      eof                     ; se DI=0, houve overflow e o arquivo é maior que 64 kiB
        push    bx                      ; salva BX para poder usar o modo indireto
        mov     bx,dx
        mov     dl,[bx]
        pop     bx                      ; retorna BX
        call    compareChars            ; compara o caractere do arquivo com o da mensagem
        jnc     en3                     ; se são diferentes, trata em en3
        call    isValidAdd              ; vê se a posição é válida (não foi utilizada antes)
        jnc     en3                     ; se não for, trata em en3
        mov     word ptr [bp],di        ; se forem iguais, copia a posição no arquivo para o array
        add     bp,2                    ; passa para a próxima posição do array
        inc     si                      ; passa para o próximo caractere da mensagem
        mov     di,1                    
        jmp     en1                     ; começa pelo byte 1 do arquivo novamente
    
en3:
        inc     di                      ; incrementa a posição do arquivo
        jmp     en2                     ; repete a leitura para o próximo caractere do arquivo

eos:
        ret                             ; se chegou ao fim da mensagem, retorna ao programa principal

handleReadError:
        lea     bx,ErrorReadMsg         ; se houve problema na leitura, imprime a mensagem
        call    printf_s
        or      errorCodes,2            ; e retorna um código de erro
        ret

eof:
        or      errorCodes,4            ; se chegou ao fim do arquivo sem terminar a criptografia, retorna um código de erro
        ret

encrypt         endp

;---------------------------------------------------------------------
; Subrotina para determinar se dois caracteres são iguais ou, em caso
; de letras, se são a mesma letra (não importando capitalização)
; SI: ponteiro para um caractere
; DL: o outro caractere
; A função retorna em CF se os caracteres são os mesmos (1) ou não (0)
; ---------------------------------------------------------------------

compareChars    proc    near
        ; Verifica se o caractere é uma letra minúscula (e salva DL na pilha)
        push    dx
        cmp     byte ptr [si],'a'
        jb      notlower
        cmp     byte ptr [si],'z'
        ja      notlower
        ; Se for, compara se é igual à respectiva letra maiúscula
        add     dl,32
        cmp     byte ptr [si],dl
        je      sameChar
        sub     dl,32

notlower:
        ; Verifica se o caractere é uma letra maiúscula
        cmp     byte ptr [si],'A'
        jb      notupper
        cmp     byte ptr [si],'Z'
        ja      notupper
        ; Se for, compara se é igual à respectiva letra minúscula
        sub     dl,32
        cmp     byte ptr [si],dl
        je      sameChar
        add     dl,32

notupper:
        cmp     byte ptr [si],dl
        je      sameChar
        jmp     diffChar

sameChar:
        ; Retorna o valor de DL (não se pode usar DL na pilha, então foi salvo DL) e seta a CF
        pop     dx
        stc
        ret

diffChar:
        ; Retorna o valor de DL (não se pode usar DL na pilha, então foi salvo DL) e dá clear em CF
        pop     dx
        clc
        ret

compareChars    endp

;---------------------------------------------------------------------
; Subrotina para determinar se a posição é válida (não foi utilizada 
; antes)
; ---------------------------------------------------------------------
isValidAdd      proc    near
; comparar DI com cada posição do encryptedMsg
        push    ax
        push    bx                      ; salva registradores na pilha
        push    cx
        lea     bx,encryptedMsg
nextAdd:
        mov     ax,[bx]
        cmp     ax,0                    ; se chegou ao fim do vetor (encontrou um 0000H), é porque é válido
        je      validAdd
        cmp     di,ax
        je      invalidAdd              ; se o valor em DI (endereço encontrado) é igual a um já presente no vetor, é inválido
        add     bx,2                    ; passa para a próxima posição do vetor
        jmp     nextAdd

validAdd:
        pop     cx
        pop     bx
        pop     ax
        stc                             ; seta a CF
        ret

invalidAdd:
        pop     cx
        pop     bx
        pop     ax
        clc                             ; dá clear na CF
        ret


isValidAdd      endp

;---------------------------------------------------------------------
; Subrotina para criar o arquivo de saída
; ---------------------------------------------------------------------
createOutput    proc    near

        lea     dx,FileNamekrp
        mov     cx,0
        mov     ah,3CH
        int     21H
        jnc     noErrorInCreation
        or      errorCodes,64

noErrorInCreation:
        ret

createOutput    endp

;---------------------------------------------------------------------
; Subrotina para abrir o arquivo de saída e salvar o handle em outFile
; ---------------------------------------------------------------------
openOutput      proc    near

        lea     dx,FileNamekrp
        mov     ah,3DH
        mov     al,1
        int     21H
        jnc     noErrorInOpening
        or      errorCodes,64

noErrorInOpening:
        mov     outFile,ax
        ret

openOutput     endp  


; ---------------------------------------------------------------------
; Subrotina para fechar o arquivo de saída
; ---------------------------------------------------------------------
closeOutput      proc    near

        lea     bx,outFile
        mov     ah,3EH
        int     21H

        ret

closeOutput      endp

; ---------------------------------------------------------------------
; Subrotina para escrever no arquivo de saída
; ---------------------------------------------------------------------
writeMessage    proc    near

        lea     dx,encryptedMsg
        mov     ah,40H
        mov     bx,outFile              ; prepara os registradores
writeNext:
        mov     ah,40H
        mov     cx,2
        int     21H                     ; escreve o valor
        jc      errorInWriting
        mov     di,dx
        cmp     word ptr [di],0         ; vê se o valor escrito é zero
        je      endWrite
        add     dx,2                    ; incrementa o posição do vetor
        jmp     writeNext               ; escreve o próximo valor

errorInWriting:
        or      errorCodes,128          ; se houve erro na escrita, retora um código de erro
        ret

endWrite:
        ret

writeMessage    endp

; ---------------------------------------------------------------------
; Subrotina para converter número em string (16 bits)
; AX: número
; DI: endereço da string
; ---------------------------------------------------------------------
itoa            proc    near

        push    dx
        push    bx
        push    ax
        push    di                      ; salva os registradores

        mov     dx,0                    ; 16 bits mais significativos = 0
        mov     bx,10000                ; divide por 10000 para saber o dígito da casa da dezena de milhar
        div     bx
        add     ax,'0'
        mov     [di],al                 ; salva o valor na string
        mov     ax,dx                   ; salva o resto em AX
        inc     di                      ; passa para a próxima posição do vetor
                                        ; REPETE PARA OS PRÓXIMOS DÍGITOS
        mov     dx,0
        mov     bx,1000
        div     bx
        add     ax,'0'
        mov     [di],al
        mov     ax,dx
        inc     di

        mov     dx,0
        mov     bx,100
        div     bx
        add     ax,'0'
        mov     [di],al
        mov     ax,dx
        inc     di

        mov     dx,0
        mov     bx,10
        div     bx
        add     ax,'0'
        mov     [di],al
        inc     di
                                        ; Não precisa dividir por 1, só salvar o resto no array
        add     dx,'0'
        mov     [di],dl
        inc     di
        mov     byte ptr [di],0

        pop     di                      ; restora DI (e o mantém salvo)
        push    di

leadingZeros:                           ; remove os zeros à esquerda
        cmp     byte ptr [di],'0'
        jne     enditoa                 ; se o dígito à esquerda não é zero, vai para o fim da subrotina
        push    di
        jmp     moveLeft                ; senão, move todos o array uma posição à esquerda
lZ2:
        pop     di
        jmp     leadingZeros            ; repete o processo

moveLeft:
        mov     al,[di+1]               ; move o próximo digito para a posição atual
        mov     [di],al
        inc     di                      ; passa para a próxima posição do array
        cmp     byte ptr [di],0         ; vê se chegou ao fim do array
        je      lZ2                     ; se chegou, restaura DI e testa se ainda há zeros à esquerda
        jmp     moveLeft                ; se não chegou, repete para a próxima posição

enditoa:
        pop     di
        pop     ax
        pop     bx
        pop     dx                      ; restaura os registradores

        ret

itoa            endp


end