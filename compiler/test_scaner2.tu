use compiler.parser.scanner
use compiler.parser.package
use compiler.parser
use compiler.ast

use string
use fmt
use std
use os

mpkg = new package.Package("main","main",false)
func scan(abpath){
    fd = std.opendir(abpath)
    if !fd {
        fmt.printf("file|dir not exist %s",abpath)
    }
    while true {
        file = fd.readdir()
        if !file {
            break
        }
        if file.isDir() && file.name != "." && file.name != ".." scan(file.path)
        if !file.isFile() continue
        filepath = file.path
        if string.sub(filepath,std.len(filepath) - 3) == ".tu" {
            s<scanner.ScannerStatic> = new scanner.ScannerStatic(filepath,null)
            fmt.println(filepath)
            loop {
                if s.scan() == ast.END {
                    break
                }
                // fmt.println(s.curLex.dyn())
            }
        }
    }
 
}

func main(){
    scan("./compiler")
}