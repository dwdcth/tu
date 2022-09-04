#!/bin/bash
log(){
    str="$1"
    echo -e "\033[32m$str \033[0m "
}
failed(){
    str="$1"
    echo -e "\033[31m$str \033[0m"
    ps aux|grep test.sh|awk '{print $2}' |xargs kill -9
    exit 1
}
clean() {
    if ls $1 > /dev/null 2>&1; then
        rm -rf $1
    fi
}
check(){
    if [  "$?" != 0 ]; then
#        actual=`./a.out`
#        if [  "$?" != 0 ]; then
        failed "exec failed"
#        fi
#        rm ./a.out
    fi

}

assert(){
    log "[compile] tu -s linker/main.tu "
    tu -s main.tu
    check
    echo "gcc -g *.s /usr/local/lib/coasm/*.s -rdynamic -static -nostdlib"
    gcc -g -c *.s /usr/local/lib/coasm/*.s -rdynamic -static -nostdlib 
    echo "start linking..."
    log "[linker] tl -p ."
    tl -p .
    check
    chmod 777 a.out
    mv a.out tl_test
    cd demo;gcc -c *.s
    cd ..
    ./tl_test -p demo
    check
    chmod 777 a.out
    echo "exec a.out..."
    ./a.out
    check
    rm ./a.out ./tl_test
    clean "*.s"
    clean "*.o"
    echo "exec done..."

    return
#    failed "[compile] $input failed"
}
assert
log "all passing...."
