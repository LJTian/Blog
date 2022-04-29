# Jenkins

## 说明

CI/CD 软件 java 开发的

## 安装

### 软件安装

- 网址

[Jenkins](https://www.jenkins.io/zh/)

- 下载软件
    
    ```bash
    # 第一步
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee \
        /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    
    # 第二步
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
        https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
        /etc/apt/sources.list.d/jenkins.list > /dev/null
    
    # 第三步
    sudo apt-get update
    sudo apt-get install fontconfig openjdk-11-jre
    sudo apt-get install jenkins
    
    # 第四步 
    # 访问 127.0.0.1:8080 【可以自己进行修改IP和端口】
    # 注意防火墙
    ```
    
    **注意：有可能服务起不来，或者卡很久，这个应该是网络问题，建议先进行下面的配置修改**
    

### 修改配置文件

- 修改配置文件【/var/lib/jenkins/hudson.model.UpdateCenter.xml】
    
    ```bash
    https://mirrors.tuna.tsinghua.edu.cn/jenkins/updates/update-center.json
    ```
    
- 修改插件源 文件位置【/var/lib/jenkins/updates/default.json】
    
    ```bash
    sed -i 's#https://updates.jenkins.io/download#https://mirrors.tuna.tsinghua.edu.cn/jenkins#g' default.json 
    sed -i 's#http://www.google.com#https://www.baidu.com#g' default.json
    ```
    

### 重新启动服务

```bash
# linux 服务的命令
systemctl start jenkins  #启动服务
systemctl status jenkins #查看状态
```

- web浏览器访问：1270.0.0.1:8080
- 按提示操作
- 建议不安装插件

### 安装插件

- 选择 左侧 [Manage]
- 中间部分的[Manage Plugins]
- 点击[Available]
- 搜 Chinese
- 勾选[Localization:Chinese...]
- 选择下方的安装并重启

汉化完成，可以选择自己需要的插件了