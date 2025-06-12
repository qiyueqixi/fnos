## 一个FnOS的脚本

# 推荐一键运行命令（国内源）
```shell
rm -f network.sh && wget http://blogpage.xiaozhuhouses.asia/api/fnscript/network.sh && chmod +x network.sh && ./network.sh
```
# 手动运行1
```shell
#从Github运行
wget https://raw.githubusercontent.com/qiyueqixi/fnos/main/network.sh -O /tmp/network.sh
#从CloudFlare运行

#赋予权限并运行

chmod +x /tmp/network.sh
sudo /tmp/network.sh

#运行后删除（可选）
rm /tmp/network.sh
```
# 手动运行2
```shell
#从Github运行
wget https://raw.githubusercontent.com/qiyueqixi/fnos/main/fnnas.sh -O /tmp/fnnas.sh
#从CloudFlare运行

#赋予权限并运行

chmod +x /tmp/fnnas.sh
sudo /tmp/fnnas.sh

#运行后删除（可选）
rm /tmp/network.sh
```
# 本地运行
```shell
#下载到本地，然后上传到飞牛。
#给脚本权限 
chmod +x /tmp/network.sh
chmod +x /tmp/fnnas.sh
#使用
sudo /network.sh 
#或者
 ./network.sh  
#运行即可
```

![image](https://github.com/user-attachments/assets/c9b3d2be-e252-4a7d-b4d2-1f7447866b32)
