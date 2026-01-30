#!/usr/bin/python3
import redis
from redis.sentinel import Sentinel

#连接哨兵服务器(主机名也可以用域名)
sentinel = Sentinel([('10.0.0.101', 26379),
                     ('10.0.0.102', 26379),
                     ('10.0.0.103', 26379)
             ],
                    socket_timeout=0.5)

redis_auth_pass='123456'

#mymaster 是运维人员配置哨兵模式的数据库名称，实际名称按照个人部署案例来填写
#获取主服务器地址
master = sentinel.discover_master('mymaster')
print(master)


#获取从服务器地址
slave = sentinel.discover_slaves('mymaster')
print(slave)



#获取主服务器进行写入
master = sentinel.master_for('mymaster', socket_timeout=0.5, password=redis_auth_pass, db=0)
w_ret = master.set('name', 'wang')
#输出：True


#获取从服务器进行读取（默认是round-roubin）
slave = sentinel.slave_for('mymaster', socket_timeout=0.5, password=redis_auth_pass, db=0)
r_ret = slave.get('name')
print(r_ret)
#输出：wang
