
use fmt
use os

func test_map_index()
{
    a = {1:1,"2":"2","3333":"3333","this is 4":"this is 4"}
    if  a[1] != 1 {
        fmt.println("a[1] == 1 failed")
        os.exit(1)
    }
    if  a["2"] != "2" {
        fmt.println("a[2] == 2 failed")
        os.exit(1)
    }
    if  a["3333"] != "3333" {
        fmt.println("a[2] == 3333 failed")
        os.exit(1)
    }
    if  a["this is 4"] != "this is 4" {
        fmt.println("a[3] == this is 4 failed")
        os.exit(1)
    }
    fmt.println("map_get success",a[1],a["2"],a["3333"],a["this is 4"])

}
enum {
    Invalid,
    E1,E2,E3
}
func test_map_update()
{
    a = {}
    a[0] = "sdfds"
    if  a[0] != "sdfds" {
        fmt.println("a[0] != sdfds failed")
        os.exit(1)
    }
    a["this is 1000"] = 1000
    if  a["this is 1000"] != 1000 {
        fmt.println("a[this is 1000] != 1000 failed")
        os.exit(1)
    }
    //test dynamic op
    a["var"] = 100
    if a["var"] != 100 os.panic("a[\"var\"] should be 100 ,ac:%d",a["var"])
    a["var"] = 200
    if a["var"] != 200 os.panic("a[\"var\"] should be 200 ,ac:%d",a["var"])
    a[20] = 77
    if a[20] != 77     os.panic("a[20]:%d != 77",a[20])
    a[20] = 88
    if a[20] != 88     os.panic("a[20]:%d != 88",a[20])
    //test native op
    a["var"] = E1
    if a["var"] != E1  os.die("a[var] != E1")
    a["var"] = E3
    if a["var"] != E3  os.die("a[var] != E3")

    fmt.println("map_update success ",a[0],a[1],a[2],a[3],a[4])
}

func test_map_add(){
    a   = {}
    a[0] = 1
    if  a[0] != 1 {
        fmt.println("a[0] != 0 failed")
        os.exit(1)
    }
    a["---"] = "sdfs"
    if  a["---"] != "sdfs" {
        fmt.println("a[---] != sdfs failed")
        os.exit(1)
    }
    a["999"] = "---"
    if  a["999"] != "---" {
        fmt.println("a[999] != --- failed")
        os.exit(1)
    }
    fmt.println("map_add success",a[0],a["---"],a["999"])
}

func main(){
    test_map_index()
    test_map_update()
    test_map_add()
}
