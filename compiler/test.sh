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
    log "[compile] tu -s compiler/main.tu "
    tu -s main.tu
    check
    echo "gcc -g *.s /usr/local/lib/coasm/*.s -rdynamic -static -nostdlib -e main"
    gcc -g  *.s /usr/local/lib/coasm/*.s -rdynamic -static -nostdlib -e main 
    check
    ./a.out
    check
    clean "a.out"
    clean "*.s"
    clean "*.o"
    echo "exec done..."

    return
#    failed "[compile] $input failed"
}
assert
log "all passing...."
