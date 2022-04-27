# 注册中心【consul】

## docker 方式安装 consul

官方教程

[Consul with Containers | Consul - HashiCorp Learn](https://learn.hashicorp.com/tutorials/consul/docker-container-agents?in=consul/docke)

docker 命令

```bash
docker pull consul ## 拉取镜像

## 运行镜像
docker run \
    -d \
    -p 8500:8500 \
    -p 8600:8600/udp \
    --name=badger \
    consul agent -server -ui -node=server-1 -bootstrap-expect=1 -client=0.0.0.0
```

浏览器访问[ip:8500]

代码

```go
package main

import (
	"fmt"
	"github.com/hashicorp/consul/api"
)

// 链接句柄
var GClient *api.Client

// 建立链接
func connet(addr string, port int) *api.Client {

	cfg := api.DefaultConfig()
	cfg.Address = fmt.Sprintf("%s:%d", addr, port)
	client, err := api.NewClient(cfg)
	if err != nil {
		panic(err)
	}
	return client
}

// 注册
func Register(address string, port int, name string, tags []string, id string) error {

	//生成对应的检查对象
	check := &api.AgentServiceCheck{
		HTTP:                           fmt.Sprintf("http://%s:%d/health", address, port),
		Timeout:                        "5s",
		Interval:                       "5s",
		DeregisterCriticalServiceAfter: "10s",
	}

	//生成注册对象
	registration := new(api.AgentServiceRegistration)
	registration.Name = name
	registration.ID = id
	registration.Port = port
	registration.Tags = tags
	registration.Address = address
	registration.Check = check

	err := GClient.Agent().ServiceRegister(registration)
	//client.Agent().ServiceDeregister()
	if err != nil {
		panic(err)
	}
	return nil
}

// 注销服务
func UnRegister(serverId string) {
	err := GClient.Agent().ServiceDeregister(serverId)
	if err != nil {
		panic(err)
	}
}

func main() {

	// 1、建立链接
	GClient = connet("10.211.55.3", 8500)
	// 2、注册服务
	Register("10.211.55.3", 8080, "test", []string{"test"}, "test")
	Register("10.211.55.3", 8080, "test1", []string{"test"}, "test1")
	// 3、摘掉服务
	UnRegister("test")
}
```