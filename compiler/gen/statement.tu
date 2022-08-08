
condIsMtype(cond,ctx){
    ismtype = false
    match type(cond) {
        type(ast.StructMemberExpr) : ismtype = true
        type(VarExpr) : {
            tvar = cond
            ismtype = tvar.isMemtype(ctx)
        }
        type(BinaryExpr) : {
            tvar = cond
            ismtype = tvar.isMemtype(ctx)
        }
    }
    return ismtype
}

ForStmt::compile(ctx)
{
    record()
    if  range  return rangeFor(ctx)
    return triFor(ctx)
}
ForStmt::rangeFor(ctx)
{
    c = ast.incr_compileridx()
    if this.obj == null 
        parse_err("statement: for(x,y : obj) obj should pass value. line:%d column:%d",line,column)
    
    this.obj.compile(ctx)
    compile.Push()
    
    compile.writeln("   mov (%%rsp),%%rdi")
    internal.call("runtime_for_first")
    compile.Push()
    
    
    compile.writeln("L.forr.begin.%d:", c)
    
    compile.CreateCmp()
    compile.writeln("    je  L.forr.end.%d", c)

    
    if this.key{
        (std.back(ctx)).createVar(this.key.varname,this.key)
        compile.writeln("   mov 8(%%rsp),%%rdi")
        compile.writeln("   mov (%%rsp),%%rsi")
        internal.call("runtime_for_get_key")
        compile.Push()

        compile.GenAddr(this.key)
        compile.Pop("%rdi")
        compile.writeln("   mov %%rdi,(%%rax)")
    }
    if this.value {
        (std.back(ctx)).createVar(this.value.varname,this.value)
        compile.writeln("   mov 8(%%rsp),%%rdi")
        compile.writeln("   mov (%%rsp),%%rsi")
        internal.call("runtime_for_get_value")
        compile.Push()
        compile.GenAddr(this.value)
        compile.Pop("%rdi")
        compile.writeln("   mov %%rdi,(%%rax)")
    }

    compile.this.enterContext(ctx)
    
    std.back(ctx).po= c
    std.back(ctx).end_str   = "L.forr.end"
    std.back(ctx).start_str = "L.forr.begin"
    std.back(ctx).continue_str = "L.for.continue"
    
    
    for(stmt : block.stmts){
        stmt.compile(ctx)
    }
    compile.this.leaveContext(ctx)

    compile.writeln("L.for.continue.%d:",c)
    compile.writeln("   mov 8(%%rsp),%%rdi")
    compile.Pop("%rsi")
    internal.call("runtime_for_get_next")
    compile.Push()

    compile.writeln("    jmp L.forr.begin.%d",c)
    compile.writeln("L.forr.end.%d:", c)
    
    compile.writeln("   add $16,%%rsp")
    return null
}
ForStmt::triFor(ctx)
{
    c = ast.incr_compileridx()
    compile.this.enterContext(ctx)
    this.init.compile(ctx)
    
    compile.writeln("L.for.begin.%d:", c)
    this.cond.compile(ctx)
    if !condIsMtype(this.cond,ctx) {
        internal.isTrue()
    }
    compile.CreateCmp()
    compile.writeln("    je  L.for.end.%d", c)

    std.back(ctx).po= c
    std.back(ctx).end_str   = "L.for.end"
    std.back(ctx).start_str = "L.for.begin"
    std.back(ctx).continue_str = "L.for.continue"
    
    
    for(stmt : block.stmts){
        stmt.compile(ctx)
    }
    
    compile.writeln("L.for.continue.%d:",c)
    
    this.after.compile(ctx)
    compile.this.leaveContext(ctx)

    compile.writeln("    jmp L.for.begin.%d",c)
    compile.writeln("L.for.end.%d:", c)

}

WhileStmt::compile(ctx)
{
    record()
    c = ast.incr_compileridx()
    
    compile.writeln("L.while.begin.%d:", c)
    
    this.cond.compile(ctx)
    if !condIsMtype(this.cond,ctx){
        internal.isTrue()
    }
    compile.CreateCmp()
    compile.writeln("    je  L.while.end.%d", c)

    compile.this.enterContext(ctx)
    
    std.back(ctx).po= c
    std.back(ctx).end_str   = "L.while.end"
    std.back(ctx).start_str = "L.while.begin"
    
    for(stmt : block.stmts){
        stmt.compile(ctx)
    }
    compile.this.leaveContext(ctx)

    compile.writeln("    jmp L.while.begin.%d",c)
    compile.writeln("L.while.end.%d:", c)
}
ExpressionStmt::compile(ctx)
{
    record()
    this.expr.compile(ctx)
}

ReturnStmt::compile(ctx)
{
    record()
    
    if ret == null{
        compile.writeln("   mov $0,%%rax")
    }else{
        ret = this.ret.compile(ctx)
        if ret && type(ret) == type(ast.StructMemberExpr) {
            sm = ret
            m = sm.ret
            
            compile.Load(m)
        
        }else if ret && type(ret) == type(ChainExpr) {
            ce = ret
            if ce.ret {
                compile.Load(ce.ret)
            }
        }
    }
    for(p : ctx ) {
        funcName = p.cur_funcname
        if funcName != "" 
            compile.writeln("    jmp L.return.%s",funcName)
    }
}

BreakStmt::compile(ctx)
{
    record()
    
    for(c : ctx ) {
        if c.po && c.end_str != ""  {
            compile.writeln("    jmp %s.%d",c.end_str,c.point)
        }
    }
}

ContinueStmt::compile(ctx)
{
    record()
    
    for ( c : ctx) {
        if c.po&& !c.continue_str.empty(){
            compile.writeln("    jmp %s.%d", c.continue_str, c.point)
        }
        if (c.po&& !c.start_str.empty()) {
            compile.writeln("    jmp %s.%d", c.start_str, c.point)
        }
    }
}

MatchCaseExpr::compile(ctx){
    record()
    compile.writeln("%s:",label)
    
    if block{
        for(stmt : block.stmts){
            stmt.compile(ctx)
        } 
    }
    compile.writeln("   jmp %s", endLabel)
    return this
}

MatchStmt::compile(ctx){
    record()
    mainPo= ast.incr_compileridx()
    endLabel = "L.match.end." + mainPoint
    
    for(cs : this.cases){
        c = ast.incr_compileridx()
        cs.label = "L.match.case." + c
        cs.endLabel = endLabel
    }
    
    if defaultCase == null{
        defaultCase = new MatchCaseExpr(line,column)
        defaultCase.matchCond = this.cond
    }
    defaultCase.label = "L.match.default." + compile.count++
    defaultCase.endLabel = endLabel
    
    for(cs : this.cases){
        BinaryExpr be(cs.line,cs.column)
        be.lhs = cs.matchCond
        be.opt = EQ
        be.rhs = cs.cond
        be.compile(ctx)
        
        if !condIsMtype(&be,ctx)
            internal.isTrue()
        
        compile.writeln("    cmp $1, %%rax")
        compile.writeln("    je  %s", cs.label)
    }
    
    compile.writeln("   jmp %s", defaultCase.label)
    
    compile.this.enterContext(ctx)
    for(cs : this.cases){
        
        cs.compile(ctx)
    }
    defaultCase.compile(ctx)
    compile.this.leaveContext(ctx)

    
    compile.writeln("L.match.end.%d:",mainPoint)
    return null
}

IfCaseExpr::compile(ctx){
    record()
    compile.writeln("%s:",label)
    if block {
        for(stmt : block.stmts){
            stmt.compile(ctx)
        } 
    }
    compile.writeln("   jmp %s", endLabel)
    return this
}

IfStmt::compile(ctx){
    record()
    mainPo = ast.incr_compileridx()
    endLabel = "L.if.end." + mainPoint
    
    for(cs : this.cases){
        cs.label  = "L.if.case." + compile.count ++
        cs.endLabel = endLabel
    }
    if elseCase {
        elseCase.label = "L.if.case." + compile.count ++
        elseCase.endLabel = endLabel
    }

    for(cs : this.cases){
        cs.cond.compile(ctx)
        if !condIsMtype(cs.cond,ctx)
            internal.isTrue()
        compile.writeln("    cmp $1, %%rax")
        compile.writeln("    je  %s", cs.label)
    }
    
    if (elseCase) compile.writeln("   jmp %s", elseCase.label)
    
    compile.writeln("   jmp L.if.end.%d", mainPoint)
    
    compile.this.enterContext(ctx)
    for(cs : this.cases){
        cs.compile(ctx)
    }
    if elseCase elseCase.compile(ctx)
    compile.this.leaveContext(ctx)

    compile.writeln("L.if.end.%d:",mainPoint)
    return null
}

GotoStmt::compile(ctx){
    record()
    compile.writeln("   jmp %s",label)
    return null
}