# RocketMQ面试题：

## RocketMQ中的Topic和普通的Queue队列有什么区别？

queue就是来源于数据结构的FIFO队列(先进先出队列)。而Topic是个抽象的概念，每个Topic底层对应N个queue，而数据也真实存在queue上。

## RocketMQ Broker中的消息被消费后会立即删除吗？

不会，每条消息都会持久化到CommitLog中，每个Consumer连接到Broker后会维持消费进度信息，当有消息消费后只是当前Consumer的消费进度(CommitLog的offset)进行了偏移。

### 追问： 那么消息会堆积吗？什么时候清理过期消息？

4.6版本默认是48小时后删除不再使用的CommitLog文件

- 检查这个文件最后访问时间
- 判断是否大于过期时间
- 指定时间删除，默认凌晨4点

## RocketMQ消费模式有几种？

消费模型有Consumer决定，消费维度为Topic

- 集群消费
    - 一条消息只会被通Group中的一个Consumer消费
    - 多个Group同时消费一个Topic时，每个Group都会有一个Consumer消费到数据
- 广播消费
    - 消息将对一个Consumer Group下的各个Consumer实例都消费一遍。即是这些Consumer属于用一个Consumer Group, 消息会被Consumer Group中的每个Consumer都消费一次。
    

## 消费消息是push还是pull？

RockerMQ没有真正意义的push,都是pull, 虽然有push类，但实际底层实现采用的是长轮询机制，即拉取方式

- broker端属性 longPollingEnable 标记是否开启长轮询。默认开启

### 追问： 为什么要主动拉取消息而不使用事件监听方式？

事件驱动方式是建立好长连接，由事件(发送数据)的方式来实时推送。

如果Borker 主动推送消息的话，有可能Push速度快，消费速度慢的情况，那么就会造成消息在consumer端堆积过多，同时又不能被其他consumer消费的情况。而pull的方式可以根据当前自身情况来pull，不会造成过多的压力而造成瓶颈。所以采用了pull的方式。

## Broker 如何处理拉取请求的？

Consumer首次请求Broker

- Broker中有是否有符合条件的消息
- 有
    - 响应Consumer
    - 等待下次Consumer的请求
- 没有
    - DefaultMessageStore#ReputMessageService#run方法
    - PullRequestHoldService 来Hold连接，每5s执行一次检查pullRequestTable有没有消息，有的话立即推送
    - 每1ms检查commitLog中是否有新消息，有的话写入到pullRequestTable
    - 当有新消息的时候返回请求
    - 挂起consumer的请求，即不断开连接，也不返回数据
    - 使用consumer的offset
    

## RocketMQ如何做负载均衡？

通过Topic在多Broker中分布式存储实现。

### Producer端

发送端指定message queue发送消息到相应的Broker，来达到写入时的负载均衡。

- 提升写入吞吐量，当多个producer同时向一个broker写入数据时候，性能会下降。
- 消息分布在多Broker中，为负载消费做准备

### 默认策略是随机选择：

- producer 维护一个index
- 每次取节点会自增
- index向所有broker个数取余
- 自带容错策略

### Consumer 端

采用的是平均分配算法来进行负载均衡。

### 其他负载均衡算法

- 平均分配策略(默认)(AllocateMessagesQueueAveragely)
- 环形分配策略(AllocateMessageQueueAveragelyByCircle)
- 手动配置分配策略(AllocateMessageQueueByConfig)
- 机房分配策略(AllocateMessagesQueueByMachineRoom)
- 一致性哈希分配策略(AllocateMessageQueueConsistentHash)
- 靠近机房策略(AllocateMachineRoomNearby)

### 追问：当消费负载均衡consumer和queue不对等的时候会发生什么？

Consumer 和 queue会优先平均分配，如果Consumer少于queue的个数，则会存在部分Consumer消费多个queue的情况，如果Consumer等于queue的个数，那就是一个Consumer消费一个queue,如果Consumer个数大于queue的个数，那么会有部分Consumer空余出来，白白的浪费。

## 消息重复消费（幂等性）

影响消息正常发送和消费的重要原因是网络的不确定性。

- 引起重复消费的原因
    - ACK
        
        正常情况下，在consumer真正消费完消息后，应该发送ack,通知broker该消息已经正常消费，从queue中剔除当ack因为网络原因无法送到broker,borker会认为词条消息没有被消费，此后会开启消息重投机制，把消息再次投递到consumer
        
    - 消费模式
        
        在Clustering模式下，消息在broker中会保证相同group的consumer消费一次，但是针对不同Group的Consumer会推送多次
        
- 解决方案
    - 数据库表
        
        处理消息钱，使用消息主键在表中带有约束的字段中插入(通过数据库的唯一索引进行控制)
        
    - Map
        
        单机时可以使用Map，消息主键做key，每次消息来了，进行map查询看是否已处理
        
    - Redis
        
        分布式锁
        

## 如何让RocketMQ保证消息的顺序消费

> 你们线上业务用消息中间件的时候，是否需要保证消息的顺序性？
> 如果不需要保证消息顺序，为什么不需要？假如我有一个场景要保证消息的顺序，你们应该如何保证？

 首先多个queue只能保证单个queue里的顺序，queue是典型的FIFO,天然顺序。多个queue同时消费是无法绝对保证消息的有序性的。

- 所以总结如下：

同一topic，同一QUEUE,发消息的时候一个线程去发送消息，消费的时候一个线程去消费queue里的消息。

### 追问：怎么保证消息发到同一个queue？

RocketMQ给我们提供了接口，可以自己实现算法

## rocketMQ如何保证消息不丢失？

首先在如下三个部分可能会发生丢失消息的情况：

- producer端
- Broker端
- Consumer端

### Producer 端如何保证消息不丢失？

- 采取send()同步发消息，发送结果是同步感知的。
- 发送失败后可以重试，设置重试次数，默认3次。
- 集群部署，比如发送失败了的原因可能是当前Broker宕机了，重试的时候会发送到其他Broker上。

### Broker端如何保证消息不丢失？

- 修改刷盘策略为同步刷盘。默认情况下是异步刷盘的。
- 集群部署，主从模式，高可用。

### consumer端如何保证消息不丢失？

- 完全消费正常后再进行ACK应答。

## RocketMQ的消息堆积如何处理？

> 下游消费体系如果宕机了，导致几百万条消息在消息中间件里积压，此时怎么处理？
你们线上是否遇到过消息积压的生产故障？如果没有遇到过，你考虑一下如何应对？

首先要找到是什么原因导致的消息堆积，是producer太多了，还是Consumer太少了导致的还是说其它情况，总之先定位问题。

然后看下消息消费速度是否正常，正常的话，可以通过上线更多consumer临时解决消息堆积问题

### 追问：如果Consumer和Queue不对等，上线了多台也在短时间内无法消费完堆积的消息怎么办？

- 准备一个临时的topic
- queue的数量是堆积的几倍
- queue分布到多Broker中
- 上线一台Consumer做消息的搬运工，把原来的topic中的消息挪到新的topic里，不做业务逻辑处理，只是挪过去
- 上线N台Consumer同时消费临时Topic的数据
- 改BUG
- 恢复原来的Consumer,继续消费之前的Topic

### 追问：堆积时间过长消息超时了？

RocketMQ中的消息只会在commitLog被删除的时候才会消失，不会超时。也就是说未被消费的消息不会存在超时删除这种情况

### 追问：堆积的消息会不会进死信队列？

不会，消息在消费失败后会进入重试队列，18此尝试之后仍然失败才会进入死信队列。

## RocketMQ在分布式事务支持这块机制的底层原理？

「你们用的是RocketMQ?RocketMQ很大的一个特点是对分布式事务的支持，你说说他在分布式事务支持这块机制的底层原理？」

分布式系统中的事务可以使用TCC(Try、Confirm、Cancel)、2pc来解决分布式系统中的消息原子性

RocketMQ4.3+提供分布式事务功能，通过RocketMQ事务消息能达到分布式事务的最终一致

RocketMQ实现方式：

- Half Message:  预处理消息，当broker 收到此类消息后，会存储到RMQ_SYS_TRANS_HALF_TOPIC 的消费队列中
- 检查事务状态：Broker会开启一个定时任务，消费RMQ_SYS_TRANS_HALF_TOPIC 队列中的消息，每次执行任务会向消息发送者确认事务执行状态(提交、回滚、未知)，如果是为止，Broker会定时去回调再重新检查。
- 超时：如果超时回查次数，默认回滚消息。

也就是他并未真正进入Topic的queue,而是用了临时queue来放所谓的half message,等提交事务后才会真正的讲half message转移到topic下的queue。

![Untitled](Untitled.png)

## 高吞吐量下如何优化生产者和消费者的性能？

### 开发

- 同一group下，多机部署，并行消费
- 单个Consumer提高消费者线程个数
- 批量消费
    - 消息批量拉取
    - 业务逻辑批量处理

RocketMQ 是如何保证数据的高容错性的？

- 在不开启容错的情况下，轮询队列进行发送，如果失败了，重试的时候过滤失败的Broker
- 如果开启了容错策略，会通过RocketMQ的预测机制来预测一个Broker是否可用
- 如果上次失败的Broker可用那么还是会选择该Broker的队列
- 如果上述情况失败，则随机选择一个进行发送
- 在发送消息的时候会记录一下调用的时间与是否报错，根据时间去预测broker的可用时间

## 任何一台Broker突然宕机了怎么办？

Broker主从架构以及多副本策略。Master收到消息后会同步给Slave，这样一条消息就不止一份了，Master宕机了还有slave中的消息可用，保证了MQ的可靠性和高可用性。而且RocketMQ4.5.0开始支持Dlegder模式，基于raft的，做到了真正意义的HA。

## Broker 把自己的信息注册到哪个NameServer上？

Broker会向所有的NameServer上注册自己信息，而不是某一个，是每一个，全部！