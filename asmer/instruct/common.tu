use asmer.ast
use asmer.elf
use asmer.utils
use string
use fmt
use os

I32_MAX<i32> = 2147483647 				
I32_MIN<i32> = -2147483648 		 	
U32_MAX<u32> = 4294967295 				
U32_MIN<u32> = 0 
I8_MAX<i8>   = 127 	 
I8_MIN<i8>   = -128 				 	
U8_MAX<u8>   = 255 						
U8_MIN<u8>   = 0 

False<i64>   = 0

Instruct::check(check<i8>,err)
{
    if(check) return
    if (err != ""){
        fmt.printf("AsmError:%s \n"
                "line:%d column:%d file:%s\n\n"
                "expression:\n%s\n",err,int(this.line),int(this.column),
                this.parser.filepath,string.new(this.str))
    }else{
        fmt.printf("AsmError:\n"
                "line:%d column:%d file:%s\n\n"
                "expression:\n%s\n",int(this.line),int(this.column),this.parser.filepath,
                string.new(this.str))
    }
    os.die("")
}
Instruct::opoffset(){
    len<i32> = 0
    //src
    if(this.left == ast.TY_REG){
        len = ast.reglen(this.tks.addr[0]) 
    }
    //dst
    if(this.right == ast.TY_REG){
        len = ast.reglen(this.tks.addr[1]) 
    }
    return len
}
opcode2<u16:208> = 
[
    0x88,  0x8a,0x88, 0xb0,    0x89,   0x8b,0x89,     0xc7,//mov
    0x88,  0x8a,0x88, 0xb0,    0x89,   0x8b,0x89,     0xc6,//movb
    0x88,  0x8a,0x88, 0xb0,    0x89,   0x8b,0x89,     0xc7,//movw
    0x88,  0x8a,0x88, 0xb0,    0x89,   0x8b,0x89,     0xc7,//movl
    0x88,  0x8a,0x88, 0xb0,    0x89,   0x8b,0x89,     0xc7,//movq
    0x00,  0x00,0x00, 0x00,    0x63,   0x63,0x00,     0x00,//movsxd
    0x00,  0x00,0x00, 0x00,    0x0fbe, 0x0fbe,0x0fbe, 0x0fbe,//movsbl
    0x00,  0x00,0x00, 0x00,    0x0fb6, 0x0fb6,0x0fb6, 0x0fb6,//movzb
    0x00,  0x00,0x00, 0x00,    0x0fb6, 0x0fb6,0x0fb6, 0x0fb6,//movzbl
    0x00,  0x00,0x00, 0x00,    0x0fb6, 0x0fb6,0x0fb6, 0x0fb6,//movzx
    0x00,  0x00,0x00, 0x00,    0x0fb7, 0x0fb7,0x0fb7, 0x0fb7,//movzwl
    0x00,  0x00,0x00, 0x00,    0x0fbf, 0x0fbf,0x0fbf, 0x0fbf,//movswl
    0xd2,  0xd2,0xd2, 0xd2,    0xd3,   0xd3,0xd3,     0xc1,//shl
    0xd2,  0xd2,0xd2, 0xd2,    0xd3,   0xd3,0xd3,     0xc1,//shr
    0xd2,  0xd2,0xd2, 0xd2,    0xd3,   0xd3,0xd3,     0xc1,//sar
    0x38,  0x3a,0x38, 0x80,    0x39,   0x3b,0x39,     0x83,//cmp
    0x00,  0x00,0x00, 0x00,    0x0fb1, 0x0fb1,0x0fb1, 0x0fb1,//cmpxchg
    0x97,  0x91,0x91, 0x91,    0x87,   0x87,0x87,     0x87,//xchg
    0x28,  0x2a,0x28, 0x80,    0x29,   0x2b,0x29,     0x83,//sub
    0x00,  0x02,0x00, 0x80,    0x01,   0x03,0x01,     0x83,//add
    0x00,  0x02,0x00, 0x80,    0x0fc1, 0x0fc1,0x0fc1, 0x0fc1,//xadd
    0x00,  0x00,0x00, 0x00,    0x21,   0x3b,0x21,     0x83,//and
    0x00,  0x02,0x00, 0x80,    0x0faf, 0x03,0x01,     0x6b,//imul & mul
    0x00,  0x00,0x00, 0x00,    0x09,   0x09,0x09,     0x09,//or
    0x00,  0x00,0x00, 0x00,    0x31,   0x31,0x31,     0x31,//xor
    0x00,  0x00,0x00, 0x00,    0x8d,   0x8d,0x8d,     0x8d //lea
]
opcode1<u16:29> =
[
    //CALL SETZ    SETE    SETL    SETLE    SETAE   SETGE   SETBE   SETA    SETG    SETNZ   SETNE    SETB    INT   
    0xe8,  0x0f94, 0x0f94, 0x0f9c, 0x0f9e , 0x0f93, 0x0f9d, 0x0f96, 0x0f97, 0x0f9f, 0x0f95, 0x0f95,  0x0f92, 0xcd, 
    //DIV  IDIV  NEG  INC  DEC  
    0xf7,  0xf7, 0x40,0x48,0x00,
    //JMP, JE     JG     JL     JLE    JNE  JNA   NOT
    0xeb,  0x74,  0x7f,  0x7c,  0x7e,  0x75,0x76, 0xf7,
    //PUSH POP
    0x50,  0x58
]
opcode1_extern<u16:29> =
[
    //CALL SETZ    SETE,   SETL    SETLE    SETAE   SETGE   SETBE   SETA    SETG    SETNZ   SETNE    SETB    INT   
    0xe8,  0x0f94, 0x0f94 ,0x0f9c, 0x0f9e , 0x0f93, 0x0f9d, 0x0f96, 0x0f97, 0x0f9f, 0x0f95, 0x0f95,  0x0f92, 0xcd, 
    //DIV  IDIV  NEG  INC  DEC 
    0xf7,  0xf7, 0x40,0x48,0x00,
    //JMP  JE       JG       JL     JLE      JNE    JNA     NOT
    0xe9,  0x0f84,  0x0f8f,  0x0f8c,0x0f8e,  0x0f85,0x0f86, 0xf7,
    //PUSH POP
    0x50,  0x58
]
opcode1_8<u16:29> =
[
    //CALL SETZ    SETE    SETL    SETLE    SETAE   SETGE   SETBE   SETA    SETG    SETNZ   SETNE    SETB    INT   
    0xe8,  0x0f94, 0x0f94, 0x0f9c, 0x0f9e , 0x0f93, 0x0f9d, 0x0f96, 0x0f97, 0x0f9f, 0x0f95, 0x0f95,  0x0f92, 0xcd, 
    //DIV  IDIV  NEG  INC  DEC  
    0xf6,  0xf6, 0x40,0x48,0x00,
    //JMP, JE     JG     JL     JLE    JNE  JNA   NOT
    0xeb,  0x74,  0x7f,  0x7c,  0x7e,  0x75,0x76, 0xf7,
    //PUSH POP
    0x50,  0x58
]
opcode0<u16:7> =
[
//  RET   LOCK  LEAVE  SYSCALL CLTD   CDQ   CQO
    0xc3, 0xf0, 0xc9,  0x0f05, 0x99,  0x99, 0x99
]
Instruct::append1(b<i8>) {
    if(this.parser.ready){
        this.bytes[this.size] = b
        this.size += 1
    }
    this.parser.text_size += 1
}
Instruct::append2(b<u16>) {
    this.append1(b >> 8)
    this.append1(b)
}
Instruct::append(b<u64>, len<i32>) {
    for(i<i32> = 0; i < len ; i += 1 ){
        this.append1(b >> (8 * i))
    }
}
Instruct::writeModRM() {
    if(this.modrm.mod != -1) {
        mod<u8> = (this.modrm.mod & 0x3 ) << 6
        reg<u8> = (this.modrm.reg & 0x7 ) << 3
        rm<u8>  = (this.modrm.rm  & 0x7 ) 
        mrm<u8> = mod + reg + rm
        this.append1(mrm)
    }
}
Instruct::writeSIB() {
    if(this.sib.scale != -1) {
        s<u8> = (this.sib.scale & 0x3 ) << 6
        i<u8> = (this.sib.index & 0x7 ) << 3
        b<u8> = (this.sib.base  & 0x7)
        sib<u8> = s + i + b 
        this.append1(sib)
    }
}

Instruct::updateRel() {
    utils.debug("Instruct::updateRel()".(i8))
    flag<i8> = false
    if(this.name.empty() == string.True) return flag

    sym<ast.Sym>  = this.parser.symtable.getSym(this.name)
    if(!this.is_func) {
        if(this.parser.ready && this.is_rel && sym.externed){
            this.parser.elf.addRel(
                string.S(*".text"),this.parser.text_size,this.name,elf.R_X86_64_PC32
            )
            flag = true
        }
        else if(this.parser.ready && sym.segName.cmpstr(*".data") == string.Equal ){
            this.parser.elf.addRel(
                string.S(*".text"),this.parser.text_size,this.name,elf.R_X86_64_PC32
            )
            flag = true
        }
    }
    else if(this.is_func)
    {
        if(this.parser.ready){
            this.parser.elf.addRel(
                string.S(*".text"),this.parser.text_size,this.name,42.(i8)
            )
            flag = true
        }
    }
    return flag
}
