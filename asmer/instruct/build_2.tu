use asmer.ast
use asmer.utils
use asmer.parser
use string

Instruct::insthead(){
    utils.debug("Instruct::insthead()".(i8))
    match this.type {
        ast.KW_MOVW: {
            this.append1(0x66.(i8))
            return true
        }
        ast.KW_MOVL | ast.KW_MOVB: return true 
    }
    if this.type == ast.KW_MOV && this.has16bits {
        this.append1(0x66.(i8))
        return  true
    }
    if ast.r8ishigh(this.tks.addr[0]) && ast.r8ishigh(this.tks.addr[1]){
        this.append1(0x4d.(i8))
        return true
    }
    if( (this.tks.addr[0] == ast.TK_NUMBER || ast.r8islow(this.tks.addr[0])) && ast.r8islow(this.tks.addr[1])){
        this.append1(0x48.(i8))
        return true
    }
    if( (this.tks.addr[0] == ast.TK_NUMBER || ast.r8islow(this.tks.addr[0])) && ast.r8ishigh(this.tks.addr[1])){
        if(this.type == ast.KW_MUL){
            if(this.tks.addr[0] == ast.TK_NUMBER)
                return this.append1(0x4d.(i8))
            else
                return this.append1(0x4c.(i8))
        }
        if(this.left == ast.TY_MEM || this.is_rel)
            this.append1(0x4c.(i8))
        else 
            this.append1(0x49.(i8))
        return true
    }
    if(ast.r8ishigh(this.tks.addr[0]) && ast.isr4(this.tks.addr[1])){
        if(this.left == ast.TY_MEM)
            return this.append1(0x41.(i8))
    }
    if(ast.r8ishigh(this.tks.addr[0]) && ast.r8islow(this.tks.addr[1])){
        if(this.left == ast.TY_MEM || this.type == ast.KW_MUL)
            this.append1(0x49.(i8))
        else 
            this.append1(0x4c.(i8))
        return true
    }
    if(ast.r8ishigh(this.tks.addr[0]) && ast.r8ishigh(this.tks.addr[1])){
        this.append1(0x4d.(i8))
        return true
    }
    if(ast.isr4(this.tks.addr[0]) && ast.r8islow(this.tks.addr[1])){
        if(this.right != ast.TY_MEM)
            return this.append1(0x48.(i8))
    }
    if(ast.isr4(this.tks.addr[0]) && ast.r8ishigh(this.tks.addr[1])){
        if(this.right == ast.TY_MEM)
            this.append1(0x41.(i8))
        else 
            this.append1(0x4c.(i8))
        return true
    }
    if(ast.isr1(this.tks.addr[0]) && this.right != ast.TY_MEM){
        if(ast.r8islow(this.tks.addr[1]))
            this.append1(0x48.(i8))
        if(ast.r8ishigh(this.tks.addr[1])){
            if(this.type == ast.KW_SHL || this.type == ast.KW_SHR || this.type == ast.KW_SAR)
                this.append1(0x49.(i8))
            else
                this.append1(0x4c.(i8))
        }
        return true
    }
}


Instruct::need2byte_op2(){
    match this.type {
        ast.KW_MOVSBL: return true
        ast.KW_MOVZB:  return true
        ast.KW_MOVZBL: return true
        ast.KW_MOVZX:  return true
        ast.KW_MOVZWL: return true
        ast.KW_MOVSWL: return true
        ast.KW_CMPXCHG: return true//cmpxchg
        ast.KW_XADD:    return true//xadd
        ast.KW_SYSCALL: return true
    }
    return false
}
Instruct::genTwoInst()
{
    utils.debug("Instruct::genTwoInst()".(i8))
    index<i32> = -1
    ilen<i32> = this.opoffset()
    len<i32>   = 1
    if(this.left == ast.TY_IMMED)
        index = 3
    else
        index = (this.right - 2) * 2 + this.left - 2
    index = (this.type - ast.KW_MOV ) * 8  + (1 - ilen%4) * 4 + index
    opcode<u16> = opcode2[index]
    exchar<u8> = 0
    needprefix<i32> = true

    match this.modrm.mod {
        -1 : {
            this.insthead()
            match this.type {
                ast.KW_MOV:{
                    if(ast.isr4(this.tks.addr[1])){
                        opcode = 0xb8 + this.modrm.reg
                        this.append1(opcode)
                        this.append(this.inst.imm,4.(i8))
                        return true
                    }
                    if(this.is_rel){
                        opcode = 0x8b
                        len    = 4
                        exchar = 0x05 + 0x08 * this.modrm.reg
                    }else{
                        if this.inst.negative {
                            _c<i64> = this.inst.imm
                            len = 4
                            exchar = 0xc0 + this.modrm.reg
                            if(_c < I32_MIN){
                                len = 8
                                opcode = 0xb8 + this.modrm.reg
                            }
                        }else if this.inst.imm > I32_MAX {
                            len = 8
                            opcode = 0xb8 + this.modrm.reg
                        }else{
                            len = 4
                            exchar = 0xc0 + this.modrm.reg
                        }
                    }
                }
                ast.KW_MOVSXD | ast.KW_MOVZX |  ast.KW_MOVZB |  ast.KW_MOVZBL | ast.KW_MOVSBL | ast.KW_MOVZWL | ast.KW_MOVSWL : {
                    len = 4
                    if(this.left == ast.TY_IMMED)
                        exchar = 0x05 + 0x08 * this.modrm.reg
                    else
                        exchar = 0xc0 + this.modrm.reg
                }
                ast.KW_CMP:{
                    if(this.inst.imm > I8_MAX){
                        len = 4
                    }
                    exchar = 0xf8
                    exchar += this.modrm.reg
                }
                ast.KW_ADD:{
                    if this.inst.imm > I8_MAX {
                        if(this.tks.addr[1] == ast.KW_RAX || this.tks.addr[1] == ast.KW_EAX)
                            opcode = 0x05
                        else
                            opcode = 0x81
                        len = 4
                    }
                    exchar = 0xc0
                    exchar += this.modrm.reg
                }
                ast.KW_AND: {
                    if this.inst.imm > I8_MAX {
                        if(this.tks.addr[1] == ast.KW_RAX || this.tks.addr[1] == ast.KW_EAX)
                            opcode = 0x25
                        else
                            opcode = 0x81
                        len = 4
                    }
                    exchar = 0xe0
                    exchar += this.modrm.reg
                }
                ast.KW_SUB:{
                    if(this.inst.imm > I8_MAX){
                        if(this.tks.addr[1] == ast.KW_RAX || this.tks.addr[1] == ast.KW_EAX)
                            opcode = 0x2d
                        else
                            opcode = 0x81
                        len = 4
                    }
                    exchar = 0xe8
                    exchar += this.modrm.reg
                }ast.KW_MUL:{
                    if(this.inst.imm > I8_MAX){
                        opcode = 0x69
                        len = 4
                    } 
                    exchar = 0xc0
                    exchar += (this.modrm.reg) * 0x09
                }
                ast.KW_LEA:{
                    this.check(this.left == ast.TY_IMMED,"unsupport instruct in lea:" + ast.tk_to_string(this.type))
                    sym<ast.Sym> = this.parser.symtable.getSym(this.name)
                    this.inst.imm  = 0
                    len        = 4
                    exchar = 0x05 + 0x08 * this.modrm.reg
                }
                ast.KW_SAR:{
                    len = 1 
                    exchar = 0xf8
                    exchar += this.modrm.reg
                }
                ast.KW_SHL:{
                    len = 1 
                    exchar = 0xe0
                    exchar += this.modrm.reg
                }
                ast.KW_SHR:{
                    len = 1 
                    exchar = 0xe8
                    exchar += this.modrm.reg
                }
                _:{
                    this.check(False,"unknown inst in immed:")
                }
            }
            this.check(opcode != 0,"opcode is null")
            if(this.need2byte_op2())
                this.append2(opcode)
            else
                this.append1(opcode)

            if this.inst.negative {
                _c<i64> = this.inst.imm
                if _c >= I32_MIN
                    this.append1(exchar)
            }else if this.inst.imm <= I32_MAX {
                if(
                (this.type == ast.KW_ADD || this.type == ast.KW_AND || this.type == ast.KW_SUB) &&
                this.inst.imm > I8_MAX && 
                this.left == ast.TY_IMMED && 
                (this.tks.addr[1] == ast.KW_RAX || this.tks.addr[1] == ast.KW_EAX)
                ){}else
                    this.append1(exchar)
            }
            this.updateRel()
            if this.is_rel {
                sym<ast.Sym> = this.parser.symtable.getSym(this.name)
                rel<i32> = 0
                if !sym.externed && sym.segName.cmpstr(*".data") != string.Equal {
                    rel = sym.addr - this.parser.text_size - len
                }
                this.append(rel,len)
                break
            }
            this.append(this.inst.imm,len)
        }
        0  :{
            len = 1
            match this.type {
                ast.KW_ADD:{
                    if(this.left == ast.TY_IMMED){
                        imm<i64> = this.inst.imm
                        if imm > I8_MAX {
                            opcode = 0x81
                            len = 4
                        }else if( imm < I8_MIN){
                            opcode = 0x81
                            len = 4
                        }else{
                            needprefix = false
                        }
                    }
                }
                ast.KW_MOVW: len = 2
                ast.KW_MOVQ | ast.KW_MOVL: len = 4
            }
            if(needprefix)
                this.insthead()

            if(this.need2byte_op2())
                this.append2(opcode)
            else
                this.append1(opcode)
            this.writeModRM()
            if(this.modrm.rm == 5){
                this.updateRel()
                if this.inst.dispLen
                    this.append(this.inst.disp,this.inst.dispLen)
            }else if(this.modrm.rm == 4){
                this.writeSIB()
            }
            if(this.left == ast.TY_IMMED){
                this.append(this.inst.imm , len)
            }
        }
        1 | 2 : {
            len = 1
            match this.type {
                ast.KW_ADD:{
                    if(this.left == ast.TY_IMMED){
                        imm<i64> = this.inst.imm
                        if(imm > I8_MAX){
                            opcode = 0x81
                            len = 4
                        }else if(imm < I8_MIN){
                            opcode = 0x81
                            len = 4
                        }else{
                            needprefix = false
                        }
                    }
                }
                ast.KW_SUB:{
                    if(this.left == ast.TY_IMMED && this.right == ast.TY_MEM) {
                        opcode = 0x68 +  this.modrm.rm
                    }
                }
                ast.KW_CMP:{
                    if(this.left == ast.TY_IMMED && this.right == ast.TY_MEM){
                        opcode = 0x78 + this.modrm.rm
                    }
                }
                ast.KW_MOVW: len = 2
                ast.KW_MOVQ | ast.KW_MOVL : len = 4
            }
            if(needprefix)
                this.insthead()

            if(this.need2byte_op2())
                this.append2(opcode)
            else
                this.append1(opcode)
            this.writeModRM()
            if(this.modrm.rm == 4 || this.modrm.rm == 5)
                this.writeSIB()
            if(this.inst.dispLen)
                this.append(this.inst.disp,this.inst.dispLen)
            if(this.left == ast.TY_IMMED)
                this.append(this.inst.imm,len)
        }
        3 : {
            this.insthead()
            match this.type {
                ast.KW_XCHG:{
                    if(this.tks.addr[0] == ast.KW_RAX){
                        opcode = 0x90 + this.modrm.rm
                        return this.append1(opcode)
                    }
                }
            }
            if(this.need2byte_op2() || this.type == ast.KW_MUL)
                this.append2(opcode)
            else
                this.append1(opcode)
            
            if(this.type == ast.KW_SHL || this.type == ast.KW_SHR || this.type == ast.KW_SAR){
                // 48 d3 e7 shl    %cl,%rdi
                // 49 d3 e0 shl    %cl,%r8
                exchar = 0xe0
                if(this.type == ast.KW_SAR)
                    exchar = 0xf8
                exchar += (this.modrm.reg)

                if(this.type == ast.KW_SHR)  exchar += 0x08
                this.append1(exchar)
            }else{
                this.writeModRM()
            }
        }
    }
}
