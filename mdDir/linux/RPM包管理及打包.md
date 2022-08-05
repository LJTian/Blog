# RPM包管理及打包

# rpm使用：软件包安装/卸载/更新、查看软件包基本信息/依赖关系/文件列表等、列出系统中所有软件包，做到可以确定某个文件来源自哪个软件包；

1. rpm -i 安装
2. rpm -e 卸载
3. rpm -U 更新
4. rpm -qi 查询包基本信息
5. rpm -qR 查询依赖关系
6. rpm -ql 文件列表
7. rpm -qa 列出系统中所有软件包
8. rpm -qf 确定某个文件来源哪个软件包

# dnf使用：软件源配置、软件源制作、软件包安装/卸载/更新、modules；

## 软件源配置

```bash
cat /etc/yum.repos.d/UniontechOS.repo

[UniontechOS-$releasever-AppStream] # 软件库
name = UniontechOS $releasever AppStream # 软件库名称
baseurl = https://enterprise-c-packages.chinauos.com/server-enterprise-c/kongzi/1020/AppStream/$basearch # 软件库地址 可以是 URL 也可以是file:// 
enabled = 1 # 是否启用
username=$auth_u # 用户名
password=$auth_p # 密码
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-uos-release # key存放路径
gpgcheck = 0 #是否进行gpg检测
skip_if_unavailable = 1 # 不可用是否进行跳过
```

## 软件源制作

- 将rpm 包放置到一个目录[/software]中
- 执行`createrepo /software`生成repodate目录
- 设置新的软件库vim /etc/yum.repos.d/xxx_software.repo
    
    ```bash
    [xxx-software]
    name = xxx-software
    baseurl = file:///software
    enabled = 1
    gpgcheck = 0
    skip_if_unavailable = 1 # 不可用是否进行跳过
    ```
    
- yum repolist all 查询所有软件库，查看结果

## 软件包安装/卸载/更新

1. dnf repolist 查询软件库
2. dnf repolist all 查询所有软件库(包含可用与不可用的）
3. dnf list 查看可以从软件库上可用的软件包
    1. dnf list installed 列出所有已安装的RPM包
    2. dnf list available 列出所有软件库中可被安装的软件包
4. dnf search xxx 在软件库中搜索软件
5. dnf provides xxx 查看可以提供xxx文件的包
6. dnf info xxx 查看xxx包详情
7. dnf install xxx 安装软件包(自动更新依赖)
8. dnf update xxx 更新软件包(自动更新依赖)
9. dnf check-update 检查更新
10. dnf update/upgrade 更新所有可以更新的软件包
11. dnf remove/erase xxx 移除xxx包
12. dnf autoremove 移除不再依赖的包
13. dnf help 使用帮助
14. dnf grouplist 查看所有软件包组
15. dnf groupinstall ’xxx‘ 安装软件包组
16. dnf groupupdate ‘xxx’ 更新软件包组
17. dnf groupremove ‘xxx’ 移除软件包组
18. dnf —enablerepo=xxx install yyy 在xxx软件库中安装yyy软件
19. dnf distro-sync 更新所有软件至稳定版本
20. dnf reinstall xxx 重新安装xxx包
21. dnf downgrade xxx 降低xxx版本
22. dnf makecache 检查挂载源缓存

## modules

[Using modules in Fedora](https://docs.fedoraproject.org/en-US/modularity/using-modules/)

- dnf module list 列出可以的模块
- dnf module switch-to xxx:xxx/profile 切换模块
- dnf module info xxx 查看软件对应的模块信息
- dnf remove xxx MODULE:STREAM/PROFILE 删除模块
- dnf module enable xxx 对 xxx 启动模块化

### 注意：

- dnf update 会将系统包升级到模块对应的流的最新版本
- 先安装特定包，再使用模块化安装，卸载时，dnf install xxx 不会被卸载，需要做预处理
    
    ```bash
    dnf install ruby                    # 特定宝
    dnf module install ruby:2.6/default # 模块化安装
    
    dnf module remove ruby:2.6/default  # 移除模块包
    dnf mark group ruby                 # 将ruby 标记为 group
    dnf module remove ruby:2.6/default  # 重新进行卸载
    ```
    
    原因：
    
    那是因为 DNF 记得安装软件包的原因。共有三个，从强到弱排序: *user、group、dependency*
    
    解决冲突依赖，非 module的包不可以依赖 module的包，如果需要依赖，需要先将
    

# RPM打包编译：熟悉rpmbild目录结构、SPEC文件常见字段含义，理解编译各阶段内容，做到可以对已有SRPM源码包打patch，重新打包SRPM及编译RPM；

### 基础知识

- 目录结构
    - BUILD：源码解压以后放的目录
    - RPMS：制作完成后的rpm包存放目录
    - SOURCES：存放源文件，配置文件，补丁文件等放置的目录
    - SPECS：存放spec文件，作为制作rpm包的文件
    - SRPMS：src格式的rpm包目录
    - BuiltRoot：虚拟安装目录，即在整个install的过程中临时安装到这个目录，把这个目录当作根来用的，所以在这个目录下的文件，才是真正的目录文件。最终，Spec文件中最后有清理阶段，这个目录中的内容将被删除
- spec 文件变量介绍
    - 基础包信息
        
        ```bash
        Name: 软件包的名称，在后面的变量中即可使用%{name}的方式引用
        Summary: 软件包的内容
        Version: 软件的实际版本号，例如：1.12.1等，后面可使用%{version}引用
        Release: 发布序列号，例如：1%{?dist}，标明第几次打包，后面可使用%{release}引用
        Group: 软件分组，建议使用：Applications/System
        License: 软件授权方式GPLv2
        Source: 源码包，可以带多个用Source1、Source2等源，后面也可以用%{source1}、%{source2}引用
        BuildRoot: 这个是安装或编译时使用的临时目录，即模拟安装完以后生成的文件目录：%_topdir/BUILDROOT 后面可使用$RPM_BUILD_ROOT 方式引用。
        URL: 软件的URI
        Vendor: 打包组织或者人员
        Patch: 补丁源码，可使用Patch1、Patch2等标识多个补丁，使用%patch0或%{patch0}引用
        Prefix: %{_prefix} 这个主要是为了解决今后安装rpm包时，并不一定把软件安装到rpm中打包的目录的情况。这样，必须在这里定义该标识，并在编写%install脚本的时候引用，才能实现rpm安装时重新指定位置的功能
        Prefix: %{_sysconfdir} 这个原因和上面的一样，但由于%{_prefix}指/usr，而对于其他的文件，例如/etc下的配置文件，则需要用%{_sysconfdir}标识
        Requires: 该rpm包所依赖的软件包名称，可以用>=或<=表示大于或小于某一特定版本，例如：
        libxxx-devel >= 1.1.1 openssl-devel 。 注意：“>=”号两边需用空格隔开，而不同软件名称也用空格分开
        ```
        
    - 动作信息标签
        
        ```bash
        %description: 软件的详细说明
        %define: 预定义的变量，例如定义日志路径: _logpath /var/log/weblog
        %prep: 预备参数，通常为 %setup -q
        %build: 编译参数 ./configure --user=nginx --group=nginx --prefix=/usr/local/nginx/……
        %install: 安装步骤,此时需要指定安装路径，创建编译时自动生成目录，复制配置文件至所对应的目录中（这一步比较重要！）
        %pre: 安装前需要做的任务，如：创建用户
        %post: 安装后需要做的任务 如：自动启动的任务
        %preun: 卸载前需要做的任务 如：停止任务
        %postun: 卸载后需要做的任务 如：删除用户，删除/备份业务数据
        %clean: 清除上次编译生成的临时文件，就是上文提到的虚拟目录
        %files: 设置文件属性，包含编译文件需要生成的目录、文件以及分配所对应的权限
        %changelog: 修改历史
        ```
        

### 个人测试dome

- makefile
    
    ```makefile
    Name=ohMyZsh
    Version=1.0
    PackName=${Name}-${Version}
    
    dist: oh_my_zsh.tar.gz
    
    oh_my_zsh.tar.gz:
            rm -rf tmp/${PackName}.tar.gz
            cp -rf src/oh-my-zsh/ tmp/${PackName}/
            cd tmp;tar -zcvf ${PackName}.tar.gz ${PackName}/
    
    rpm: dist
            rm -rf tmp/rpmbuild
            mkdir -p tmp/rpmbuild/{SOURCES,SPECS,SRPMS,RPMS,BUILD}
            cp tmp/${PackName}.tar.gz tmp/rpmbuild/SOURCES
            cp ${PackName}.spec tmp/rpmbuild/SPECS
            rpmbuild --define="_topdir `cd tmp;pwd`/rpmbuild" --nodebuginfo -bb tmp/rpmbuild/SPECS/${PackName}.spec
            rm -rf out/*
            mv tmp/rpmbuild/RPMS/* out
    ```
    
- ohMyZsh-1.0.spec
    
    ```bash
    Name:           ohMyZsh
    Version:        1.0
    Release:        1%{?dist}
    Summary:        Enterprise-class open source distributed print solution
    
    Source0:        %{name}-%{version}.tar.gz
    License:        MIT
    URL:            https://gitee.com/mirrors/oh-my-zsh?_from=gitee_search
    Buildroot:      %{_tmppath}
    AutoReq:        no
    #BuildRequires:  zsh
    Requires:       zsh >= 4.3.9
    
    %description
    
    %prep
    %setup -q
    
    %build
    #编译源码
    #cd src
    #make
    echo "没有需要编译的"
    
    %install
    #安装
    echo "开始安装"
    mkdir -p $RPM_BUILD_ROOT/opt/oh-my-zsh/
    cp -r * $RPM_BUILD_ROOT/opt/oh-my-zsh/
    
    %files
    %defattr(-,root,root,-)
    /opt/oh-my-zsh/*
    
    %changelog
    
    %post
    #安装之后的操作
    
    cp -rf /opt/oh-my-zsh ~/.oh-my-zsh
    cp ~/.zshrc ~/.zshrc.orig
    cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc
    chsh -s $(which zsh)
    echo "请重新登录: [ su - root ]"
    
    %postun
    #卸载时操作
    sh ~/.oh-my-zsh/tools/uninstall.sh
    rm -rf ~/.oh-my-zsh
    chsh -s $(which bash)
    echo "请重新登录: [ su - root ]"                                                                                                                                                                       3,10-17      全部
    ```
    
- out
    - x86_64
        - rpm 文件
- src
    - 源码位置
- tmp
    - rpmbuild 打包工作目录
    - tar.gz 源码压缩文件
    - src_dir 源码目录

# mock使用：理解mock原理，做到可使用mock编译RPM包，chroot环境调试；

- mock原理
    
    [GitHub - rpm-software-management/mock: Mock is a tool for a reproducible build of RPM packages.](https://github.com/rpm-software-management/mock)
    
    - [systemd-nspawn](https://www.freedesktop.org/software/systemd/man/systemd-nspawn.html) 进行文件隔离
    - 也可以使用docker 容器进行隔离，但是需要注意容器隔离需要独占namespace和容器中不再运行其它进程
    - 编译执行流程
        
        ```bash
        # 添加编译用户
        # 将编译用户添加到mock组中
        # 切换用户
        useradd builder && usermod -a -G mock builder && su - builder 
          
        ```
        
- mock编译RPM包
    - 安装 mock
        
        ```bash
        dnf install mock # 安装mock包
        ```
        
    - 初始化x86_64
        
        ```bash
        mock -r os-version_x86_64 --init #其中os是系统名称，version是系统版本号 环境内容参考 /etc/mock/目录下的*.cfg环境配置文件
        ```
        
    - 对rpm包进行x86_64编译
        
        ```bash
        mock -r epel-6-x86_64 rebuild package-1.1-1.src.rpm 
        ```
        
    - 解决 mock error: Empty %files file /builddir/build/BUILD/ohMyZsh-1.0/debugsourcefiles.list 问题
        - `-D 'debug_package %{nil}'` 添加此编译参数，mock 和 rpmbuild 都可以使用
    - 输出目录：
        - /var/lib/mock 默认路径
        - `-resultdir=/home/builder/rpms` 指定输出路径
    - 清理环境
        - `mock -r epel-6-x86_64 --clean`
- 容器内启动mock需要再启动容器时添加下面这个参数
    
    ```docker
    --privileged
    ```
    

# koji使用：做到可测试提交编译任务至koji，熟悉koji web页面，可从koji web页面查找包、查看任务状态及编译日志。

- 什么是koji
    
    [GitHub - koji-project/koji: This is the github mirror for the koji build system. There is sometimes lag. Check pagure to sure.](https://github.com/koji-project/koji)
    

没有运行环境，搭建一个环境，应该不是很容易

[http://10.30.38.102/koji](http://10.30.38.102/koji)