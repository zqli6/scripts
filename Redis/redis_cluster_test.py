#!/usr/bin/env python3
from rediscluster  import RedisCluster

if __name__ == '__main__':

    startup_nodes = [
        {"host":"10.0.0.101", "port":6379},
        {"host":"10.0.0.102", "port":6379},
        {"host":"10.0.0.103", "port":6379},
        {"host":"10.0.0.104", "port":6379},
        {"host":"10.0.0.105", "port":6379},
        {"host":"10.0.0.106", "port":6379}]
    try:
        redis_conn= RedisCluster(startup_nodes=startup_nodes,password='123456', decode_responses=True)
    except Exception as e:
        print(e)

    for i in range(0, 10000):
        redis_conn.set('key'+str(i),'value'+str(i))
        print('key'+str(i)+':',redis_conn.get('key'+str(i)))
