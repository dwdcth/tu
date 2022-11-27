use ast
use compile
use fmt
use utils

class DelRefExpr  : ast.Ast { 
    expr 
    func init(line,column){
        super.init(line,column)
    }
    func toString(){
        return "DelRefExpr(" + this.expr.toString() + ")"
    }
}
class AddrExpr   : ast.Ast {
    package
    varname
    expr
    func init(line,column){ super.init(line,column) }
    func toString() {
        return fmt.sprintf("AddrExpr(&(%s.%s))" , this.package , this.varname )
    }
}
class AssignExpr : ast.Ast {
    opt
    lhs rhs
    func init(line,column){
        super.init(line,column)
    }
}
AssignExpr::toString() {
    str = "AssignExpr(lhs="
    if this.lhs
        str += this.lhs.toString()
    str += ",rhs="
    if this.rhs
        str += this.rhs.toString()
    str += ")"
    return str
}
AssignExpr::compile(ctx){
    this.record()

    utils.debugf("AssignExpr: parsing... lhs:%s opt:%s rhs:%s",
          this.lhs.toString(),
          ast.getTokenString(this.opt),
          this.rhs.toString()
    )
    if !this.rhs    this.panic("AsmError: right expression is wrong expression:" + this.toString())
    
    f = compile.currentFunc
    match type(this.lhs) {
        type(VarExpr) : {
            return this.lhs.assign(ctx,this.opt,this.rhs)
        }
        type(IndexExpr) : return this.lhs.assign(this.opt,this.rhs)
        type(StructMemberExpr) | type(DelRefExpr) : {
            return (new OperatorHelper(ctx,this.lhs,this.rhs,this.opt)).gen()
        }
        type(ChainExpr) : {
            ce = this.lhs
            if ce.ismem(ctx) 
                return ( new OperatorHelper(ctx,this.lhs,this.rhs,this.opt) ).gen()
            return ce.assign(ctx,this.opt,this.rhs)
        }
        type(MemberExpr) : {
            return this.lhs.assign(ctx,this.opt,this.rhs)
        }
    }
    this.panic("SyntaxError: can not assign to %s" ,this.lhs.toString())
}
DelRefExpr::compile(ctx){
    utils.debugf("gen.DelExpr::compile()")
    this.record()
    
    if type(this.expr) == type(StringExpr) {
        se = this.expr
        compile.writeln("    lea %s(%%rip), %%rax", se.name)
        return this
    }
    ret = this.expr.compile(ctx)
    
    if (ret == null){
        this.check(false,"del refexpr error")
    }else if type(ret) == type(VarExpr) {
        var = ret
        
        if !var.structtype {
            internal.get_object_value() return ret
        }
        
        if !var.pointer {
            this.expr.check(false,"var must be pointer ")
        }
        if var.size != 1 && var.size != 2 && var.size != 4 && var.size != 8{
            this.panic("type must be [i8 - u64]:%s",this.expr.toString())
        }
        
        compile.LoadSize(var.size,var.isunsigned)
        return ret
    }else if type(ret) == type(StructMemberExpr) {
        sm = ret
        m = sm.ret
        if m == null{
            this.panic("del ref can't find the class member:%s",this.expr.toString())
        }
        if type(this.expr) != type(DelRefExpr) {
            
            compile.LoadMember(m)
        }
        compile.LoadSize(m.size,m.isunsigned)
        return ret
    
    }else if type(ret) == type(ChainExpr) {
        ce = ret
        
        if ce.ret {
            m = ce.ret
            compile.LoadMember(m)

            return ret
        }
    }
    this.panic("only support del ref for expression :%s",this.expr.toString())
}

AddrExpr::compile(ctx){
    utils.debugf("gen.AddrExpr::compile()")
    this.record()
    
    if this.expr != null && type(this.expr) == type(ChainExpr) {
        ce = this.expr
        if !ce.ismem(ctx){
            this.panic("only support & struct.menber %s\n",this.expr.toString())
        }
        ce.compile(ctx)
        
        return ce
    }
    if this.package != ""{
        
        var = ast.getVar(ctx,this.package)
        if var != null && var.structtype {
            
            sm = new StructMemberExpr(this.package,this.line,this.column)
            sm.member = this.varname
            sm.var    = var
            m = sm.getMember()
            if m != null{
                
                compile.GenAddr(var)
               
                if(var.structname != "" && var.stack){
                }else compile.Load()
                
                compile.writeln("	add $%d, %%rax", m.offset)
                
                if m.bitfield {
                    this.panic(
                        "AsmError: adress to bitfield error! "
                        "line:%d column:%d \n\n"
                        "expression:\n%s\n",
                        this.line,this.column,this.toString())
                }
                return this
            }
        }
        
        var = GP().getGlobalVar(this.package,this.varname)
        compile.GenAddr(var)
        return this
    }
    var = ast.getVar(ctx,this.varname)
    if var == null
        this.panic("AddExpr: var:%s not exist\n",this.varname)
    realVar = var.getVar(ctx)
    compile.GenAddr(realVar)

    return this
}
class BinaryExpr : ast.Ast {
    opt
    lhs rhs
    func init(line,column){
        super.init(line,column)
    }
}
BinaryExpr::isMemtype(ctx)
{    
    this.check(this.lhs != Null)

    if this.lhs != null && exprIsMtype(this.lhs,ctx) return True
    if this.rhs != null && exprIsMtype(this.lhs,ctx) return True
    return False
}

BinaryExpr::compile(ctx)
{
    this.record()

    utils.debug( "BinaryExpr: parsing... lhs:%s opt:%s rhs:%s",
          this.lhs.toString(),
          ast.getTokenString(this.opt),
          this.rhs.toString()
    )
    if !this.rhs && (this.opt != ast.BITNOT && this.opt != ast.LOGNOT)
        this.panic("AsmError: right expression is wrong expression:" + this.toString())
    
    if this.isMemtype(ctx) {
        (new OperatorHelper(ctx,this.lhs,this.rhs,this.opt)).gen()
    }
    if this.opt == ast.LOGOR || this.opt == ast.LOGAND 
        return this.FirstCompile(ctx)
    
    this.lhs.compile(ctx)
    compile.Push()

    if this.rhs   this.rhs.compile(ctx)
    else            compile.writeln("   mov $0,%%rax")
    compile.Push()

    
    internal.call_operator(this.opt,"runtime_binary_operator")
    return null
}

BinaryExpr::FirstCompile(ctx){
    utils.debugf("gen.BinaryExpr::Firstcompile()")
    this.record()
    c = ast.incr_labelid()
    this.lhs.compile(ctx)
    internal.isTrue()
    match this.opt {
        ast.LOGAND:{
            compile.writeln("    cmp $0, %%rax")
			compile.writeln("	je .L.false.%d", c) 
        }
        ast.LOGOR: {
            compile.writeln("    cmp $1, %%rax")
			compile.writeln("	je .L.true.%d", c) 
        }
    }
    this.rhs.compile(ctx)
    internal.isTrue()
    match this.opt {
        ast.LOGAND: {
            compile.writeln("	cmp $0,%%rax")    
            compile.writeln("	je .L.false.%d", c)
            compile.writeln("	jmp .L.true.%d", c)
        }
        ast.LOGOR:{
            compile.writeln("	cmp $1,%%rax")    
            compile.writeln("	je .L.true.%d", c)
            compile.writeln("	jmp .L.false.%d", c)
        }
    }

    compile.writeln(".L.false.%d:", c)
    internal.gen_false()
    compile.writeln("	jmp .L.end.%d", c)
    compile.writeln(".L.true.%d:", c) 
    internal.gen_true()
    compile.writeln(".L.end.%d:", c)
    return null
}


BinaryExpr::toString() {
    str = "BinaryExpr("
    str += "opt=" + ast.getTokenString(this.opt)
    if this.lhs {
        str += ",lhs="
        str += this.lhs.toString()
    }
    if this.rhs {
        str += ",rhs="
        str += this.rhs.toString()
    }
    str += ")"
    return str
}
