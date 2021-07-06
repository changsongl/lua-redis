package main

import (
	"fmt"
	"github.com/gomodule/redigo/redis"
	"io/ioutil"
	"net"
	"os"
	"time"
)

func main(){
	servAddr := "127.0.0.1:6379"
	tcpAddr, err := net.ResolveTCPAddr("tcp", servAddr)
	if err != nil {
		println("ResolveTCPAddr failed:", err.Error())
		os.Exit(1)
	}

	conn, err := net.DialTCP("tcp", nil, tcpAddr)
	if err != nil {
		println("DialTCP failed:", err.Error())
		os.Exit(1)
	}

	c := redis.NewConn(conn, 3*time.Second, 3*time.Second)

	f, err := os.Open("./lock/lock.lua")
	if err != nil {
		println("Open failed:", err.Error())
		os.Exit(1)
	}

	script, err := ioutil.ReadAll(f)
	if err != nil {
		println("ReadAll failed:", err.Error())
		os.Exit(1)
	}

	checkSum, err := redis.String(c.Do("SCRIPT", "LOAD", script))
	if err != nil {
		println("SCRIPT LOAD failed:", err.Error())
		os.Exit(1)
	}

	result, err := redis.Int(c.Do("EVALSHA", checkSum, 1, "locker", "lock", "uuid", "80"))
	if err != nil && err != redis.ErrNil{
		println("SCRIPT LOAD failed:", err.Error())
		os.Exit(1)
	}
	fmt.Println(result, err)

	result, err = redis.Int(c.Do("EVALSHA", checkSum, 1, "locker", "unlock", "uuid"))
	if err != nil && err != redis.ErrNil{
		println("SCRIPT LOAD failed:", err.Error())
		os.Exit(1)
	}
	fmt.Println(result, err)
}
