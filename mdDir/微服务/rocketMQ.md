# rocketMQ

## 介绍

具有高性能、低延时和高可靠等特性，主要用来提升性能、系统解耦、流量消峰。

### 特点：

- 灵活可扩展性
    
    rocketMQ 天然支持集群，其核心四组件（Name Server、Broker、 Producer、Consumer）每个都可以横向扩展。
    
- 海量消息堆积能力
    
    RocketMQ 采用零拷贝原理实现了超大的消息的堆积能力，据说单机可以支持亿级消息堆积，而且在堆积了这么多消息后依然保持写入低延迟。
    
- 支持顺序消息
    
    可以保证消息消费者按照消息发送的顺序对消息进行消费。顺序消息分为全局有序和局部有序，一般推荐使用局部有序，即生产者通过将某一类消息按顺序发送至同一队列来实现。
    
- 多种消息过滤方式
    
    消息过滤分为在服务器端过滤和在消费端过滤。服务器端过滤时可以按照消息消费者的要求做过滤，优点是减少不必要消息传输，缺点是增加了消息服务器的负担，实现相对复杂。消费端过滤规则完全由具体应用自定义实现，这种方式更加灵活，缺点是很多无用的消息会传输给消息消费者。
    
- 支持事务消息
    
    RocketMQ除了支持普通消息，顺序消息之外还支持事务消息，这个特性对于分布式事务来说提供了又一种解决思路。
    
- 回溯消费
    
    回溯消费是指消费者已经消费成功的消息，由于业务上需求需要重新消费，RocketMQ支持按照时间回溯消费，时间维度精确到毫秒，可以向前回溯，也可以向后回溯。
    

## RocketMQ、RabbitMQ、Kafka的区别？

- kafka
    - 开发语言：Scala开发
    - 性能、吞吐量：吞吐量所有MQ里最优秀，QPS十万级、性能毫秒级、支持集群部署
    - 功能：功能单一
    - 缺点：丢数据，因为数据先写入磁盘缓存区，未直接落盘。机器故障会造成数据丢失
    - 应用场景：适当丢失数据没有关系、吞吐量要求高、不需要太多的高级功能的场景，比如大数据场景。
- RabbitMQ:
    - 开发语言：Erlang开发
    - 性能、吞吐量：吞吐量比较低，QPS几万级、性能微秒级、主从架构
    - 功能：功能单一
    - 缺点：Erlang小众语言开发，吞吐量低，集群扩展麻烦。
    - 应用场景：中小佛那个是对并发和吞吐量要求不高的场景。
- RocketMQ:
    - 开发语言：java开发
    - 性能、吞吐量：吞吐量高，QPS十万级、性能毫秒级、支持集群部署
    - 功能：支持各种高级功能，比如说延迟消息、事务消息、消息回溯、死信队列、消息积压等等。
    - 缺点：官方文档相对简单
    - 应用场景：大型公司。

## 为什么要使用MQ?

因为项目比较大，做了分布式系统，所有远程服务调用请求都是同步执行经常出现问题，所以引入MQ

作用：将系统进行解耦、没有强依赖关系异步不需要同步执行的远程调用，可以有效提高响应时间，请求达到峰值后，后端Server还可以保持固定消费速率消费，不会被压垮

## RocketMQ由哪些角色组成，每个角色作用和特点是什么？

- NameServer: 角色作用，无状态，动态列表。
- Producer: 消息生产者，负责发消息到Broker。
- Broker: MQ本身，负责收发消息，持久化消息等。
- Consumer: 消息消费者，负责从Broker上拉取消息进行消费，消息完进行ACK回应。

## 设计图及原理

[7张图带你轻松入门RocketMQ](https://baijiahao.baidu.com/s?id=1717719991300685095&wfr=spider&for=pc)

![Untitled](Untitled.png)

### 集群架构图

- Name Server 集群
    
    NameServer 集群部署，但是节点之间并不会同步数据，因为每个节点都会宝尊完整的数据。因此单个节点挂掉，并不会对集群产生影响。
    
- Broker
    
    Broker采用主从集群，实现多副本存储和高可用。每个Broker节点都要跟所有的NameServer节点建立场长连接，定义注册Topic路由信息和发送心跳。
    
    > 跟所有Name Server建立连接，就不会因为单个Name Server挂了影响Broker使用。Broker主从模式中，Slave节点主动从Master节点拉取消息。
    > 
- Producer
    
    Producer 跟Name Server的任意一个节点建立长连接，定期从Name Server 拉取Topic路由信息。Producer 是否采用集群，取决于它所以在的业务系统。
    
- Consumer
    
    Consumer跟Name Server的任意一个节点建立长连接，定期从Name Server拉取Topic路由信息。Consumer是否采用集群，取决于它所在的业务系统。
    
    > Producer 和Consumer 只跟任意一个Name Server 节点建立链接，因为Broker 会向所有Name Server 注册Topic信息，所以每个Name Server 保存的数据其实都是一致的。
    > 
    

### MessageQueue

Producer 发送的消息会在Broker的MessageQueue中保存，如下图：

![Untitled](Untitled%201.png)

有了MessageQueue，Topic 就可以在Broker中实现分布式存储，如上图，Broker集群中保存了4个MessageQueue(0-3),这些MessageQueue保存了Topic1-Topic3这三个Topic的消息。

MessageQueue类似于Kafka中的Partition,有了MessageQueue,Producer可以并发地想Broker中发送消息，Consumer也可以并发地消费消息。

> 默认Topic可以创建的MessageQueue数量是4，Broker可以创建的MessageQueue数量是8，RocketMQ选择二者中数量小的，也就是4。不过这连个值都可以配置。
> 

### Consumer

RocketMQ的消费者模式如下：

![Untitled](Untitled%202.png)

图中，Topic1的消息写入了两个消息管道，连个队列保存在Broker1和Broker2上。

RocketMQ通过Consumer Group实现消息广播。比如上图中有两个消费者组，每个消费者组有两个消费者。

一个消费者可以消费多个消息管道，但是同一个消息管道只能被同一个消费者组的一个消费者消费，比如Message0 只能被Gorup1中的Consumer1 消费，不能被Gourp2中的Consumer2消费。

### Broker 高可用集群

Broker 集群如下图：

![Untitled](Untitled%203.png)

Broker 通过主从集群来实现消息高可用。跟Kafka 不同的是，RocketMQ并没有Master节点选举功能，而是采用多Master多Slave的集群架构。Producer写入消息时写入Master节点，Slave节点主动从Master节点拉取数据来保持跟Master节点的数据一致。

Consumer消费消息时，即可以从Master节点拉取数据，也可以从Slave节点拉取数据。

**到底是从Master拉取还是从Slave拉取取决于Master节点的负载和Slave的同步情况。**

如果Master负载很高，Master会通知Consumer从Slave拉取消息，而如果Slave同步消息进度延后，则Master会通知Consumer从Master拉取数据。总之，从Master拉取还是从Slave拉取由Master来决定。

如果Master节点发生故障，RocketMQ会使用基于raft协议的DLedger算法来进行主从切换。

> Broker 每隔30s向Name Server发送心跳，Name Server如果120s 没有收到心跳，就会判断Broker宕机了。
> 

### 消息存储

RocketMQ 的存储设计师非常有创造性的。存储文件主要有三个：CommitLog、ConsumerQueue、Index

关系如下图：

![Untitled](Untitled%204.png)

- commitLog 文件
    
    RocketMQ的消息保存在CommitLog中，CommitLog每个文件1G大小。有趣的，文件名并不叫CommitLog，而是用消息的偏移量来命名。比如第一个文件文件名是0000000000000000000，第二个文件名是00000000001073741824，依次类推就可以得到所有文件的文件名。
    
    有了上面的命名规则，给定一个消息的偏移量，就可以根据二分查找快速找到消息所在的文件，并且用消息偏移量减去文件名就可以得到消息在文件中的偏移量。
    
    > RocketMQ写CommitLog时采用顺序写，大大提高了写入性能。
    > 
- ConsumerQueue
    
    ![Untitled](Untitled%205.png)
    
    如果直接从CommitLog中检索Topic中的一条消息，效率会很低，因为需要从文件的第一条消息开始依次查找。引入了ConsumeQueue作为CommitLog的管道索引文件，会让检索效率大增。
    
    ConsumerQueue中的元素内容如下：
    
    - 前8个字节记录消息在CommitLog中的偏移量。
    - 中间4个字节记录消息大小。
    - 最后8个字节记录消息中tag的hashcode。
    
    这个tag的作用非常重要，假如一个Consumer订阅了TopicA，tag1和tag2，那么这个Consumer的订阅关系如下图：
    
    ![Untitled](Untitled%206.png)
    

可以看到，这个订阅关系是一个hash类型的结构，key是topic名称，value是一SubscriptionData类型的对象，这个对象封装了tag。

拉取消息时，首先从Name Server 获取订阅关系，得到当前Consumer所有订阅tag的hashcode集合codeSet， 然后从ConsumerQueue获取一条记录，判断最后8个字节tag hashcode 是否在codeSet中， 已决定是否将该消息发送给Consumer。

- Index 文件
    
    ![Untitled](Untitled%207.png)
    
    RocketMQ 支持按照消息的属性查找消息，为了支持这个功能，RocketMQ引入了Index索引文件。Index文件有三部分组成，文件头 IndexHead、500万个hash槽和2000万个Index条目组成。
    
    - IndexHead
        
        总共有6个元素组成，前两个元素标识当前这个Index文件中第一条消息和最后一条消息的落盘时间，第三、第四两个元素表示当前这个Index文件中第一条消息和最后一条消息在CommitLog文件中的物理偏移量，第五个元素标识当前这个Index文件中hash槽的数量，第六个元素表示当前这个Index文件中索引条目的个数。
        
        > 查找的时候除了传入key还需要传入第一条消息和最后一条消息的落盘时间，这是因为index文件名字是时间戳命名的，传入落盘时间可以更加精确地定位Index文件。
        > 
    - Hash 槽
        
        哈希散列，Index文件中Hash槽有500万个数组元素，每个元素是4个字节Int类型元素，保存当前槽下最新的那个index条目的序号。
        
    - Index 条目
        
        每个Index 条目中，Key的hashcode 占4个字节，phyoffset表示消息在CommitLog中的物理偏移量占8个字节，timediff 表示消息的落盘时间与header里的 heginTimestamp的差值占4个字节，pre index no 占4个字节
        
        > pre index no 保存的是当前的Hash 槽中前一个index 条目的序号，一般在key 发生Hash冲突是才会有值，否则这个值就是0，表示当前元素是Hash槽中第一个元素。
        > 
        
        > Index 条目中保存的timeDiff，是为了防止key重复。查找key时，在key相同的情况下，如果传入的时间范围跟timediff不满足，则会查找pre index no 这个条目。
        > 
- 总结：
    
    通过上面的分析，我们可以总结一个通过Key在Index文件中查找消息的流程，如下图：
    
    - 计算key的hashcode；
    - 根据hashcode在Hash槽中查找位置s;
    - 计算Hash槽在Index文件中位置 40+(s-1)*4;
    - 读取这个槽的值，也就是Index条目序号n;
    - 计算该Index条目在Index文件中的位置，公式: 40 + 500万 * 4 + (n-1) *20;
    - 读取这个条目，比较key的hashcode和inde条目中hashcode是否相同，以及key传入的时间范围跟Index条目中的timediff是否匹配。如果条件不符合，则查找pre index no 这个条目，找到后，从CommitLog中取出消息。

### 刷盘策略

RocketMQ 采用灵活的刷盘策略。

- 异步刷盘
    
    消息写入CommitLog时，并不会直接写入磁盘，而是先写入PageCache缓存中，然后用后台线程异步把消息刷入磁盘。异步刷盘策略就是消息写入PageCache后立即返回成功，这样写入效率非常高。如果能容忍消息丢失，异步刷盘是最好的选择。
    
- 同步刷盘
    
    即使同步刷盘，RocketMQ也不是每条消息都要刷盘，线程将消息写入内存后，会请求刷盘线程进行刷盘，但是刷盘线程并不会只把当前请求的消息刷盘，而是会把待刷盘的消息一同刷盘。同步刷盘策略保证了消息的可靠性，但是也降低了吞吐量，增加了延迟。
    

## 交互方式

- 同步
- 异步
- 只发送

## 消息类型

- 普通消息
- 消费消息
- 延迟消息
    - 订单超时取消
- 事务消息
    
    
## 基于rocketMq的设计
    
![Untitled](Untitled%208.png)
    

## 面试题

[面试题](https://www.notion.so/954232c507bb498a9ad97eaf442d3b6f)