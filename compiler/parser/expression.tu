use ast
use os
use std
use fmt
use gen
use utils
use parser.scanner

Parser::parseChainExpr(first){
    utils.debug("parser.Parser::parseChainExpr()")
    chainExpr = new gen.ChainExpr(this.line,this.column)
    ret  = chainExpr
    chainExpr.first = first
    var = null
    is_gmvar = false
    if type(first) == type(gen.DelRefExpr) {
        dr = first
        this.check(type(dr.expr) == type(gen.StructMemberExpr))
        
        chainExpr.first = dr.expr
        dr.expr = chainExpr
        ret = dr
    }else if type(first) == type(gen.AddrExpr) {
        ae = first
        
        sm = new gen.StructMemberExpr(ae.package,ae.line,ae.column)
        sm.member = ae.varname
        sm.var    = var
        
        chainExpr.first = sm
        ae.expr = chainExpr
        ret = ae
    }else if type(first) == type(gen.VarExpr) {
        var = first
        if var.package != "" {
            gv = this.getGlobalVar(var.package,var.varname)
            if (gv != null && gv.structtype){
                var = gv
                is_gmvar = true
            }
        }
    }
    
    while this.ischain() { 
        match this.scanner.curToken {
            ast.DOT : {
                this.scanner.scan() //eat.
                ta = null
                if this.scanner.curToken == ast.LPAREN {
                    ta = this.parseTypeAssert(true)
                }
                this.expect(ast.VAR)
                membername = this.scanner.curLex
                this.scanner.scan()
                if this.scanner.curToken == ast.LPAREN {
                    mc = new gen.MemberCallExpr(this.line,this.column)
                    mc.tyassert = ta
                    mc.membername = membername 
                    mc.call = this.parseFuncallExpr("")
                    chainExpr.fields[] = mc
                }else{
                    if(is_gmvar){
                        is_gmvar = false
                        sm = new gen.StructMemberExpr(var.varname,var.line,var.column)
                        sm.tyassert = ta
                        sm.member = membername
                        sm.var    = var
                        chainExpr.first = sm
                    }else{
                        me = new gen.MemberExpr(this.line,this.column)
                        me.tyassert = ta
                        me.membername = membername
                        chainExpr.fields[] = me
                    }
                }
            }
            ast.LPAREN :   chainExpr.fields[] = this.parseFuncallExpr("")
            ast.LBRACKET : chainExpr.fields[] = this.parseIndexExpr("")
            _ : break
        }
    }
    if std.len(chainExpr.fields) == 0 {
        return chainExpr.first
    }
    this.check(std.len(chainExpr.fields),"parse chain expression,need at least 2 field")
    chainExpr.last = std.pop(chainExpr.fields)

    return ret
}

Parser::parseExpression(_oldPriority<u64>)
{
    //TODO: support default args value
    oldPriority = 1
    if _oldPriority != 0 oldPriority = _oldPriority
    utils.debugf("parse.Parser::parseExpression() pri:%i",oldPriority)
    p = this.parseUnaryExpr()
    
    if this.ischain() {
        p = this.parseChainExpr(p)
    }
    
    if this.isassign() {
        this.check(p != null)
        if type(p) != type(gen.VarExpr) &&
            type(p) != type(gen.ChainExpr) &&
            type(p) != type(gen.IndexExpr) &&
            type(p) != type(gen.MemberExpr) &&
            type(p) != type(gen.DelRefExpr) &&
            type(p) != type(gen.StructMemberExpr)  
        {
            this.check(false,"ParseError: can not assign to " + p.name())
        }
        
        if type(p) == type(gen.StructMemberExpr) && this.currentFunc {
            sm = p
            sm.assign = true
        }
        if type(p) == type(gen.VarExpr) && this.currentFunc {
            var = p
            
            if !std.exist(var.varname,this.currentFunc.params_var) && !std.exist(var.varname,this.currentFunc.locals) {
                this.currentFunc.locals[var.varname] = var
            }
        }

        
        assignExpr = new gen.AssignExpr(this.line, this.column)
        assignExpr.opt = this.scanner.curToken
        assignExpr.lhs = p
        this.scanner.scan()
        assignExpr.rhs = this.parseExpression()
        return assignExpr
    }

    
    while this.isbinary() {
        currentPriority = this.scanner.priority(this.scanner.curToken)
        if (oldPriority > currentPriority)
            return p
        
        tmp = new gen.BinaryExpr(this.line, this.column)
        tmp.lhs = p
        tmp.opt = this.scanner.curToken
        this.scanner.scan()
        tmp.rhs = this.parseExpression(currentPriority + 1)
        p = tmp
    }
    return p
}

Parser::parseUnaryExpr()
{
    utils.debugf("parser.Parser::parseUnaryExpr() %s \n",
        ast.getTokenString(this.scanner.curToken),
        // this.scanner.curLex
    )
    //unary expression: like -num | !var | ~var
    if this.isunary() {
        val = new gen.BinaryExpr(this.line,this.column)
        val.opt = this.scanner.curToken
        
        this.scanner.scan()
        val.lhs = this.parseUnaryExpr()
        if this.ischain() {
            val.lhs = this.parseChainExpr(val.lhs)
        }
        return val
    }else if this.isprimary() {
        return this.parsePrimaryExpr()
    }
    utils.debugf(
        "parseUnaryExpr: not found token:%d-%s file:%s line:%d\n",
        int(this.scanner.curToken),
        this.scanner.curLex,
        this.filepath,
        this.line
    )
    return null
}

Parser::parsePrimaryExpr()
{
    utils.debug("parser.Parser::parsePrimaryExpr()")
    tk   = this.scanner.curToken
    prev = this.scanner.prevToken
    
    if tk == ast.BUILTIN {
        builtinfunc = new gen.BuiltinFuncExpr(this.scanner.curLex,this.scanner.line,this.scanner.column)
        this.next_expect( ast.LPAREN )
        this.scanner.scan()
        
        if this.scanner.curToken == ast.MUL {
            builtinfunc.expr = this.parsePrimaryExpr()
        }else{
            builtinfunc.expr = this.parseExpression()
        }
        this.expect(ast.RPAREN)
        this.scanner.scan()
        return builtinfunc
    }
    
    if tk == ast.BITAND {
        addr = new gen.AddrExpr(this.scanner.line,this.scanner.column)
        tk = this.scanner.scan()
        if tk == ast.VAR {
            addr.varname = this.scanner.curLex
        }
        tk = this.scanner.scan()
        if tk == ast.DOT {
            addr.package = addr.varname
            this.scanner.scan()
            this.expect( ast.VAR )
            addr.varname = this.scanner.curLex
            this.scanner.scan()
        }
        return addr
    }
    if tk == ast.DELREF || tk == ast.MUL{
        utils.debug("find token delref")
        
        this.scanner.scan()
        
        p = this.parsePrimaryExpr()
        delref = new gen.DelRefExpr(this.line,this.column)
        delref.expr = p
        return delref
    
    }else if tk == ast.DOT{
        this.scanner.scan()
        this.expect(ast.VAR)
        me = new gen.MemberExpr(this.line,this.column)
        me.membername = this.scanner.curLex
        
        this.scanner.scan()
        return me
    }else if tk == ast.LPAREN {
        this.scanner.scan()
        val = this.parseExpression()
        this.expect( ast.RPAREN )
        
        this.scanner.scan()
        return val
    }else if tk == ast.LBRACKET && (prev == ast.RBRACKET || prev == ast.RPAREN) {
        return this.parseIndexExpr("")
    }
    else if tk == ast.FUNC
    {
        prev    = this.currentFunc
        closure = this.parseFuncDef(false,true)
        prev.closures[] = closure
        
        var = new gen.ClosureExpr("placeholder",this.line,this.column)
        closure.receiver = var
        
        this.currentFunc = prev
        return var
    }else if tk == ast.VAR
    {
        var = this.scanner.curLex
        this.scanner.scan()
        return this.parseVarExpr(var)
    }else if tk == ast.INT
    {
        ret = new gen.IntExpr(this.line,this.column)
        ret.lit = this.scanner.curLex
        this.scanner.scan() //eat i
        if this.scanner.curToken == ast.DOT {
            this.scanner.scan()//eat .
            ty = this.parseTypeAssert(false)
            ret.tyassert = ty
        }
        return ret
    }else if tk == ast.FLOAT
    {
        val     = string.tonumber(this.scanner.curLex)
        this.scanner.scan()
        ret    = new gen.DoubleExpr(this.line,this.column)
        ret.lit = val
        return ret
    }else if tk == ast.STRING {
        val     = this.scanner.curLex
        this.scanner.scan()
        ret    = new gen.StringExpr(this.line,this.column)

        if this.scanner.curToken == ast.DOT {
            this.scanner.scan()
            ret.tyassert = this.parseTypeAssert(false)
        }        

        this.strs[] = ret
        ret.lit = val
        return ret
    }else if tk == ast.CHAR
    {
        val     = this.scanner.curLex
        this.scanner.scan()
        ret    = new gen.CharExpr(this.line,this.column)

        if this.scanner.curToken == ast.DOT {
            this.scanner.scan()
            ret.tyassert = this.parseTypeAssert(false)
        }        
        ret.lit = val
        return ret
    }else if tk == ast.BOOL
    {
        val = 0
        if this.scanner.curLex == "true"
            val = 1
        this.scanner.scan()
        ret    = new gen.BoolExpr(this.line,this.column)
        ret.lit = val
        return ret
    }else if tk == ast.EMPTY
    {
        this.scanner.scan()
        return new gen.NullExpr(this.line,this.column)
    }else if tk == ast.LBRACKET
    {
        this.scanner.scan()
        ret = new gen.ArrayExpr(this.line,this.column)
        if this.scanner.curToken != ast.RBRACKET {
            while(this.scanner.curToken != ast.RBRACKET) {
                ret.lit[] = this.parseExpression()
                if this.scanner.curToken == ast.COMMA
                    this.scanner.scan()
            }
            this.expect( ast.RBRACKET )
            this.scanner.scan()
            return ret
        }
        this.scanner.scan()
        return ret
    }else if tk == ast.LBRACE
    {
        this.scanner.scan()
        ret = new gen.MapExpr(this.line,this.column)
        if this.scanner.curToken != ast.RBRACE{
            while(this.scanner.curToken != ast.RBRACE) {
                kv = new gen.KVExpr(this.line,this.column)
                kv.key    = this.parseExpression()

                if(this.scanner.curToken == ast.RBRACE) {
                    ret.lit[] = kv.key
                    break
                }
                if(this.scanner.curToken == ast.COMMA){
                    this.scanner.scan()
                    ret.lit[] = kv.key
                    continue
                }

                this.expect( ast.COLON )
                this.scanner.scan()
                kv.value  = this.parseExpression()
                ret.lit[] = kv
                if this.scanner.curToken == ast.COMMA
                    this.scanner.scan()
            }
            this.expect( ast.RBRACE )
            this.scanner.scan()
            return ret
        }
        this.scanner.scan()
        return ret
    }else if tk == ast.NEW
    {
        this.scanner.scan()
        utils.debugf("got new keywords:%s",this.scanner.curLex)
        return this.parseNewExpr()
    }
    return null
}

Parser::parseNewExpr()
{
    utils.debug("parser.Parser::parseNewExpr()")
    if this.scanner.curToken == ast.INT {
        ret = new gen.NewExpr(this.line,this.column)
        ret.len = string.tonumber(this.scanner.curLex)
        this.scanner.scan()
        return ret
    }
    name    = this.scanner.curLex
    //new i8[3] 
    if this.isbase()
    match name {
        "i8" | "u8" | "i16" | "u16" |
        "i32"| "u32"| "i64" | "U64" : 
        {
            ret = new gen.NewExpr(this.line,this.column)
            ret.len = typesize[scanner.keywords[name]]
            this.scanner.scan()
            if this.scanner.curToken != ast.LBRACKET
                return ret //new  i8
            // scanner.scan() //eat [
            arr = this.parseExpression()
            if type(arr) != type(gen.ArrayExpr) this.check(false,"should be [] expression in new")
                expr = arr.lit[0]
           if type(expr) == type(gen.IntExpr) {
                i = expr
                ret.len *= string.tonumber(i.lit)
                return ret
            }
            if this.scanner.curToken != ast.RBRACKET this.check(false,"should be ] in new expr")
            ret.arrsize = expr
            return ret
        }
    }

    package = ""
    
    this.scanner.scan()
    if this.scanner.curToken == ast.DOT {
        this.scanner.scan()
        this.expect( ast.VAR )
        package = name
        name = this.scanner.curLex
        this.scanner.scan()
    }
    if this.scanner.curToken == ast.LBRACE {

        ret = new gen.NewStructExpr(this.line,this.column)
        ret.init = this.parseStructInit(package,name)
        return ret
    }
    if this.scanner.curToken != ast.LPAREN {
        ret = new gen.NewExpr(this.line,this.column)
        ret.package = package
        ret.name    = name
        return ret
    }
    ret = new gen.NewClassExpr(this.line,this.column)
    ret.package = package
    ret.name = name
    this.scanner.scan()
    
    while this.scanner.curToken != ast.RPAREN {
        ret.args[] = this.parseExpression()
        
        if this.scanner.curToken == ast.COMMA
            this.scanner.scan()
    }
    
    this.expect( ast.RPAREN )
    this.scanner.scan()
    return ret
}
Parser::parseVarExpr(var)
{
    utils.debugf("parser.Parser::parseVarExpr() var:%s",var)
    //FIXME: the var define order
    // package(var)
    package = var
    if var != "_" && var != "__" && this.import[var] {
        package = this.import[var]
    }
    match this.scanner.curToken {
        ast.DOT : {
            this.scanner.scan()
            ta = null
            if this.scanner.curToken == ast.LPAREN {
                ta = this.parseTypeAssert(true)
            }
            this.expect( ast.VAR)
            pfuncname = this.scanner.curLex
            
            this.scanner.scan()
            if  this.scanner.curToken == ast.LPAREN
            {
                call = this.parseFuncallExpr(pfuncname)
                call.tyassert = ta
                call.is_pkgcall  = true
                
                call.package = package
               if package == "_" || package == "__"
                    call.is_extern = true
                call.is_delref = package == "__"
                
                obj = null
                if this.currentFunc != null {
                    if std.exist(var,this.currentFunc.locals)
                        obj = this.currentFunc.locals[var]
                    else
                        obj = this.currentFunc.params_var[var]
                }else if std.exist(var,this.gvars) {
                    obj = this.gvars[var]
                }
                
                if obj {
                    obj = obj.clone()
                    obj.line = call.line
                    obj.column = call.line
                    call.is_pkgcall = false
                    params = call.args
                    call.args = []
                    //insert obj to head
                    call.args[] = obj
                    std.merge(call.args,params)
                }
                return call
            }else if this.scanner.curToken == ast.LBRACKET {
                index = this.parseIndexExpr(pfuncname)
                if this.currentFunc != null  {
                    if this.currentFunc.parser.import[package] != null {
                        index.is_pkgcall  = true
                    }
                }
                index.is_pkgcall  = true
                index.package = package
                return index
            }else{
                mvar = null
                if this.currentFunc == null && this.import[var] == null {
                    me = new gen.MemberExpr(this.line,this.column)
                    me.tyassert = ta
                    me.varname = var
                    me.membername = pfuncname
                    return me
                }else if(this.currentFunc && (mvar = this.currentFunc.getVar(package)) && mvar != null ){
                    if ( mvar.structname != "") {
                        mexpr = new gen.StructMemberExpr(package,this.scanner.line,this.scanner.column)
                        mexpr.tyassert = ta
                        mexpr.var = mvar
                        mexpr.member = pfuncname
                        return mexpr
                    }else{
                        me = new gen.MemberExpr(this.line,this.column)
                        me.tyassert = ta
                        me.varname = package
                        me.membername = pfuncname
                        return me
                    }            
                }else if (mvar = this.getGvar(package)) && mvar.structname != "" {
                    mexpr = new gen.StructMemberExpr(package,this.scanner.line,this.scanner.column)
                    mexpr.tyassert = ta
                    
                    mexpr.var = mvar
                    mexpr.member = pfuncname
                    return mexpr
                }
                gvar    = new gen.VarExpr(pfuncname,this.line,this.column)
                gvar.package    = package
                gvar.is_local   = false
                return gvar
            }
        }
        ast.LPAREN:     return this.parseFuncallExpr(var)
        ast.LBRACKET:   return this.parseIndexExpr(var)
        ast.LT : {
            tx = this.scanner.transaction()

            expr = new gen.VarExpr(var,this.line,this.column)
            varexpr = new gen.VarExpr(var,this.line,this.column)
            expr.structtype = true
            expr.type = ast.U64
            expr.size = 8
            expr.isunsigned = true
            this.scanner.scan()
            
            if this.scanner.curToken == ast.VAR{
                sname = this.scanner.curLex
                expr.structname = sname
                this.scanner.scan()
                if this.scanner.curToken == ast.DOT{
                    this.scanner.scan()
                    this.expect( ast.VAR )
                    expr.structpkg = sname
                    expr.structname = this.scanner.curLex
                    this.scanner.scan()
                }
                if ( this.scanner.curToken ==  ast.COLON){
                    this.parseVarStack(expr)
                }                
                if this.scanner.curToken != ast.GT{
                    this.scanner.rollback(tx)
                    return varexpr
                }
                this.scanner.scan()

                return expr
            }else if this.scanner.curToken <= ast.U64 && this.scanner.curToken >= ast.I8{
            
                expr.size = typesize[int(this.scanner.curToken)]
                expr.type = this.scanner.curToken
                expr.isunsigned = ast.type_isunsigned(this.scanner.curToken)
                this.scanner.scan()
                if this.scanner.curToken == ast.MUL{
                    expr.pointer = true
                    this.scanner.scan()
                }
                
                if ( this.scanner.curToken ==  ast.COLON){
                    this.parseVarStack(expr)
                }
                this.expect( ast.GT,"mut be > at var expression")
                this.scanner.scan()
                return expr
            }
            
            this.scanner.rollback(tx)
            return varexpr
        }
         ast.COLON : {
            if this.scanner.emptyline(){
                this.scanner.scan()
                return new gen.LabelExpr(var,this.line,this.column)
            }else{
                return new gen.VarExpr(var,this.line,this.column)
            }
        }
        _ : {
            varexpr = new gen.VarExpr(var,this.line,this.column)
            return varexpr
        }
    } 
}
Parser::parseFuncallExpr(callname)
{
    utils.debug("parser.Parser::parseFuncallExpr() callname:%s",callname)
    this.scanner.scan()
    val = new gen.FunCallExpr(this.line,this.column)
    val.funcname = callname

    while this.scanner.curToken != ast.RPAREN {
        val.args[] = this.parseExpression()
        
        if this.scanner.curToken == ast.COMMA
            this.scanner.scan()
    }
    
    this.expect( ast.RPAREN )
    this.scanner.scan()
    return val  
}
Parser::parseIndexExpr(varname){
    utils.debugf("parser.Parser::parseIndexExpr() varname:%s",varname) 
    this.scanner.scan()
    val = new gen.IndexExpr(this.line,this.column)
    val.varname = varname
    val.index = this.parseExpression()
    this.expect( ast.RBRACKET )
    
    this.scanner.scan()
    return val
}