
use std
use fmt
use compiler.ast
use string
use compiler.gen
use compiler.utils

Parser::parseBlock(member)
{
    utils.debug("parser.Parser::parseBlock()")
    reader<scanner.ScannerStatic>  = this.scanner 
    node = new ast.Block()
    reader.scan()
    if member {
        stmt = this.genSuperInitStmt(this.currentFunc)
        node.stmts[] = stmt
    }
    stmts = []
    while( (p = this.parseStatement()) != null )
    {
        stmts[] = p
    }
    
    std.merge(node.stmts,stmts)

    this.expect(ast.RBRACE,"parse block ")
    reader.scan()
    return node
}

Parser::parseParameterList()
{
    utils.debug("parser.Parser.parseParameterList()")
    reader<scanner.ScannerStatic> = this.scanner
    node = []
    reader.scan()
    
    if reader.curToken == ast.RPAREN {
        reader.scan()
        return node
    }

    while reader.curToken != ast.RPAREN 
    {
        if reader.curToken == ast.VAR
        {
            if this.currentFunc {
                var = new gen.VarExpr(reader.curLex.dyn(),this.line,this.column)
                
                var.type = ast.U64
                var.size = 8
                var.isunsigned = true
                this.currentFunc.params_var[reader.curLex.dyn()] = var
                this.currentFunc.params_order_var[] = var

                reader.scan()
                
                if reader.curToken == ast.LT {
                    var.structtype = true
                    reader.scan()
                    if reader.curToken == ast.VAR {
                        sname = reader.curLex.dyn()
                        var.structname = sname
                        reader.scan()
                        if reader.curToken == ast.DOT {
                            reader.scan()
                            this.expect(ast.VAR,null)
                            var.structpkg = sname
                            var.structname = reader.curLex.dyn()
                            reader.scan()
                        }
                    }else if reader.curToken >= ast.I8 && reader.curToken <= ast.U64{
                    
                        i = reader.curToken
                        this.check(i >= ast.I8 && i <= ast.U64)
                        var.size = typesize[int(i)]
                        var.type = i
                        var.isunsigned = ast.type_isunsigned(i)
                        reader.scan()
                        if reader.curToken == ast.MUL {
                            var.pointer = true
                            reader.scan()
                        }
                    }else{
                        this.panic("unknown token " + ast.getTokenString(reader.curToken))
                    }
   
                    this.expect(ast.GT ,null)
                    reader.scan()
                    
                    // continue
                }
                
                if reader.curToken == ast.COMMA continue
                if reader.curToken == ast.RPAREN continue

                
                if reader.curToken != ast.DOT {
                    this.panic("SynatxError: should be , or . but got " + reader.curLex.dyn())
                }
                
                reader.scan()
                if reader.curToken != ast.DOT {
                    this.panic("SynatxError: must be . but got :" + reader.curLex.dyn())
                }
                
                reader.scan()
                if reader.curToken != ast.DOT{
                    this.panic("SynatxError: should be , or . but got :" + reader.curLex.dyn())
                }
                
                this.currentFunc.is_variadic = true
                var.is_variadic = true
            }
            node[] = reader.curLex.dyn()
        }
        else{
            this.expect( ast.COMMA )
        }
        
        reader.scan()
    }
    
    this.expect( ast.RPAREN )
    reader.scan()
    return node
}

Parser::genSuperInitStmt(f){
    utils.debug("parser.Parser.genSuperInitStmt()")
    if this.getImport("runtime") == "" {
        this.pkg.imports["runtime"] = "runtime"
    }
    ass = new gen.AssignExpr(this.line,this.column)
    ass.opt = ast.ASSIGN
    lhs = new gen.VarExpr("super",this.line,this.column)
    f.locals[lhs.varname] = lhs

    rhs = new gen.FunCallExpr(this.line,this.column)
    rhs.package = "runtime"
    rhs.funcname = "object_parent_get"
    var = new gen.VarExpr("this",this.line,this.column)
    rhs.args[] = var
    rhs.is_pkgcall = true
    ass.lhs = lhs
    ass.rhs = rhs
    return ass
}