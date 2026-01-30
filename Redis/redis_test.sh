#!/bin/bash
#
#********************************************************************
#Author:		wangxiaochun
#QQ: 			29308620
#Date: 			2020-10-03
#FileName：		redis.sh
#URL: 			http://www.wangxiaochun.com
#Description：		The test script
#Copyright (C): 	2020 All rights reserved
#********************************************************************

NUM=100
PASS=
HOST=127.0.0.1
PORT=6379
DATABASE=0


for i in `seq $NUM`;do
    redis-cli -h ${HOST}  -a "$PASS" -p ${PORT} -n ${DATABASE} --no-auth-warning  set key${i} value${i}
    #redis-cli -h ${HOST} -p ${PORT} -n ${DATABASE} --no-auth-warning  set key${i} value${i}
    echo "key${i} value${i} 写入完成"
done
echo "$NUM个key写入到Redis完成"  
