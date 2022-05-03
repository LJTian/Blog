# G0-面试题

# 八股文

主要内容来自于网址[[https://xie.infoq.cn/article/ac87ac5f9e8def9f91b817bf9](https://xie.infoq.cn/article/ac87ac5f9e8def9f91b817bf9)]

## 垃圾回收

垃圾回收就是对程序中不再使用的内存资源进行自动回收的操作。

### 常见的垃圾回收算法

- 引用计数：每个对象维护一个引用计数，当对象创建或被赋值给其它对象时引用计数自动加1；销毁则减1。计数为0进行回收。
    - 优点：对象回收快，不会出现内存耗尽或到阀值才回收。
    - 缺点：不能很好的处理循环引用。
- 标记-清楚：从跟变量开始遍历所有应用的对象，引用的对象标记“被应用”，没有标记的就被回收。
    - 优点：解决了引用技术的缺点。
    - 缺点：需要STW(stop the world)，需要停止程序运行。
- 分代收集：按照对象生命周期长短划分不同的代空间[什么意思？]，生命周期长的放入老年代，短的放入新生代，不同代有不同的回收算法和回收频率。
    - 优点：回收性能好。
    - 缺点：算法复杂。

### 三色标记法

- 初始状态下所有的对象都是白色的。
- 从根节点开始遍历所有对象，把遍历到的对象标记成灰色对象。
- 遍历灰色对象，将灰色对象引用的对象也标记成灰色对象，将已遍历过的灰色对象标记呈黑色对象。
- 循环第三步，直到所有的灰色对象都变成黑色对象。
- 通过写屏障(write-barrier)检测对象有变化，重复以上操作[这个不一定对]。
- 回收白色对象。

![Untitled](Untitled.png)

### STW(stop the world)

- 为了防止在GC标记过程中，对象之间的引用关系发生新的变更导致标记错，故停止程序的运行。
- STW对性能有一些影响，Go目前已经可以做到1ms一下的STW。

### 写屏障(write Barrier)

- 为了防止在GC标记过程中，对象之间的引用关系发生新的变更导致标记错，我们需要进行STW，但是STW会暂停程序的运行导致服务不可用。所以引入了写屏障技术来减少暂停时间。
- 造成引用对象被回收的条件：
    
    一个黑色对象A新增了指向白色对象C的引用，并且白色对象C没有被除A对象以外的其它灰色节点的引用，或者存在之前的引用对象已被GC回收。即一下条件：
    
    - 对象A已扫描完毕，A指向C的引用无法再被扫描到；
    - 对象C无其它灰色对象引用，扫描结束就回被当做回收对象
    
    解决方式：
    
    - 破坏条件1：Dijistra 写屏障
        
        满足强三色不变性：黑色对象不允许引用白色对象，当有白色对象引用时将白色对象标记为灰色。
        
    - 破坏条件2：Yuasa 写屏障
        
        满足弱三色不变行：黑色对象允许引用白色对象，但是此白色对象已被灰色对象引用，如果这个灰色对象对白色对象的引用删除，就认为白色对象已被黑色对象引用，需要标记为灰色。
        
        ![Untitled](Untitled%201.png)
        

## GPM调度和CSP模型

### CSP 模型

- CSP(Communication Sequential Process) 通信顺序进程，CSP模型是”以通讯的方式来共享内存“，不同于传统的多线程通过共享内存来通讯。用于描述两个独立的并发实体通过共享的通讯channel(管道)进行通信的并发模型。[具体的CSP概念请百度，这个知识在golang中可以这么说]

### GMP 含义

- G(Goroutine): 协程，用户态的线程。以函数执行
- M(Machine): 线程，CPU最小的调用单位，传统意义中的线程。
- P(Processor): 处理器(GO中定义的一个概念，非CPU), 真正运行的线程数，并行数。通过GOMAXPROCS()来设置，默认为CPU核心数。

**注意：M必须绑定到P上面才可以运行协程G。P含有一个包含多个G的队列，P调用G交由M进行执行。**

**注意:  G的阻塞一般为channel或者network I/O, 此时的阻塞不会影响M的运行，M会寻找下一个G进行执行。当遇到系统调用等阻塞时，会释放P。P会绑定其它可用的M继续执行。**

### Goroutine 调度策略

- 队列分为两种：
    - P的局部队列
    - 全局队列
- 调度对象有三种,对应着GMP描述
- 调度流程：
    - P先绑定到M,让M执行P局部队列中的G(**注意：**这里有1/61的概率会取全局队列中的G，以防止全局队列中的G饿死),按顺序逐个执行。
    - 新来的G会优先加入产生自己P的局部队列，如果局部队列满了，会添加到全局队列中
    - 当P的局部队列为空时，P绑定的M会从全局队列中获取一半G到本地队列中
    - 当全局队列也为空时，会从Netpoll和事件池中获取
    - 当Netpoll和事件池中为空时，就会窃取其它P的局部队列中的一半G到本地队列中
    - 当其它P的局部队列中也没有G可执行时，这时的P和M会有什么操作？ 睡眠？还是阻塞？还是自旋？
        - 答案线程会先自旋，如果自旋线程数过多的时候会暂停
    
    ![Untitled](Untitled%202.png)
    

## chan 原理

### 结构体(类描述)

```go
// 文件路径：runtime/chan.go 
// channel类描述
type hchan struct {
	qcount   uint           // total data in the queue 队列中的总元素个数
	dataqsiz uint           // size of the circular queue 队列空间(环形存储)
	buf      unsafe.Pointer // points to an array of dataqsiz elements 队列地址
	elemsize uint16 // 每个元素的大小
	closed   uint32 // 关闭标识
	elemtype *_type // element type   每个元素的类型
	sendx    uint   // send index  发送索引
	recvx    uint   // receive index  接收索引 
	recvq    waitq  // list of recv waiters 等待接收消息的协程队列
	sendq    waitq  // list of send waiters 等待写消息的协程队列

	// lock protects all fields in hchan, as well as several
	// fields in sudogs blocked on this channel.
	//
	// Do not change another G's status while holding this lock
	// (in particular, do not ready a G), as this can deadlock
	// with stack shrinking.

	// 锁保护hchan中的所有字段，以及几个
	// sudogs 中的字段在此通道上被阻止。
	//
	// 持有这个锁时不要改变另一个 G 的状态
	//（特别是不要准备一个G），因为这会死锁
	// 堆栈收缩。
	lock mutex // 控制并发的
}

// 协程队列类描述
type waitq struct {
	first *sudog
	last  *sudog
}

// 文件路径：runtime/runtime2.go
// sudog 代表等待列表中的一个g，例如用于在channel上发送/接收。.
type sudog struct {
	// The following fields are protected by the hchan.lock of the
	// channel this sudog is blocking on. shrinkstack depends on
	// this for sudogs involved in channel ops.
	// 以下字段受此 sudog 阻塞的通道的 hchan.lock 保护。 对于参与通道操作的 sudog，收缩堆栈取决于此。

	g *g                // 协程

 	next *sudog         // 下一个协程
	prev *sudog         // 上一个协程 (双向链表)
	elem unsafe.Pointer // data element (may point to stack) 数据元素(有可能是堆上的地址)

	// The following fields are never accessed concurrently.
	// For channels, waitlink is only accessed by g.
	// For semaphores, all fields (including the ones above)
	// are only accessed when holding a semaRoot lock.

	// 以下字段永远不会同时访问。 对于通道，waitlink 只能被 g 访问。对于信号量，所有字段（包括上面的那些）只有在持有 semaRoot 锁时才被访问。

	acquiretime int64   // 获取时间
	releasetime int64   // 释放时间
	ticket      uint32  // 票

	// isSelect indicates g is participating in a select, so
	// g.selectDone must be CAS'd to win the wake-up race.

	// is Select 表示 g 正在参与选择，因此 g.selectDone 必须经过 CAS 处理才能赢得唤醒竞赛。
	isSelect bool       // 参与选择标识

	// success indicates whether communication over channel c
	// succeeded. It is true if the goroutine was awoken because a
	// value was delivered over channel c, and false if awoken
	// because c was closed.

  // success 表示通过通道 c 的通信是否成功。 如果 goroutine 因为通过通道 c 传递了一个值而被唤醒，则为 true，如果因为 c 已关闭而唤醒，则为 false。
	success bool  // c channel 通信成功标识

	parent   *sudog // semaRoot binary tree // semaRoot 二叉树 (目前不知道是做什么的，等以后再详细看)
	waitlink *sudog // g.waiting list or semaRoot 
	waittail *sudog // semaRoot
	c        *hchan // channel
}

```

### 读写流程

- 向channel写数据：
    - 1.若等待接收队列recvq不为空，则缓存冲区中无数据或无缓存区，将直接从recvq取出G,并把数据写入，最后把该G唤醒，结束发送过程。
    - 2.若缓冲区中有空余位置，则将数据写入缓冲区，结束发送过程。
    - 3.若缓冲区中没有空余位置，则将发送数据写入G,将当前G加入sendq,进入睡眠，等待被读goroutine唤醒。
- 从channel读数据：
    - 1.若等待发送队列sendq不为空，且没有缓冲区，直接从sendq中读取G,把G中数据读出，最后把G唤醒，结束读取过程。
    - 2.如果等待发送队列sendq不为空，说明缓冲区已满，从缓冲区中首部读出数据，把G中数据写入缓冲区尾部，把G唤醒，结束读取过程。
    - 3.如果缓冲区中有数据，则从缓冲区取出数据，结束读取过程。
    - 4.将当前goroutine加入recvq,进入睡眠，等待被写goroutine唤醒。
    
    ![Untitled](Untitled%203.png)
    
- 关闭 channel
    - 1.关闭channel 时会将recvq中的G全部唤醒，本该写入G的数据位置为nil.将sendq中的G全部唤醒，但是这些G会panic。
        
        panic出现的场景还有：
        
        - 关闭值为nil的channel
        - 关闭已经关闭的channel
        - 向已经关闭的channel中写数据

### 无缓冲chan 的发送和接收是否同步？

```go
ch := make(chan int) // 无缓冲的channel
ch := make(chan int, 2) // 缓存为2的channel
```

channel无缓存时，发送阻塞直到数据被接收，接收阻塞直到读到数据；

channel有缓存时，当缓冲满时发送阻塞，当缓冲空时接收阻塞。

## context 上下文 结构原理

### 用途

context(上下文)是golang应用开发常用的并发控制技术，它可以控制一组程树状结构的goroutine，每个goroutine拥有相同的上下文，context是并发安全的，主要用于控制多个协程之间的协作、取消操作。

![Untitled](Untitled%204.png)

### 数据结构

Context 只定义了接口，凡是实现该接口的类都可称为是一种context。

```go
// 代码位置： src/context/context.go

type Context interface {
   Deadline() (deadline time.Time, ok bool)
   Done() <-chan struct{}
   Err() error
   Value(key interface{}) interface{}
}
```

- Deadline() 方法：可以获取设置的截止时间，返回值deadline是截止时间，到了这个时间，Context会自动发起取消请求，返回值ok表示是否设置了截止时间。
- Done() 方法：返回一个只读的channel，类型为struct{}。如果这个chan可以读取，说明已经发出了取消信号，可以做清理操作，然后退出协程，释放资源。
- Err() 方法：返回Context被取消的原因。
- Value() 方法：获取Context上绑定的值，是一个键值对，通过Key来获取对应的值。

## 竞态、内存逃逸

### 竞态

资源竞争，就是在程序中，同一块内存同时被多个goroutine访问。我们使用go build、 go run、 go test 命令时，添加 -race 标识可以检查代码中是否存在资源竞争。

这个问题可以通过给资源加锁的方式解决，一个资源同一时刻只能被一个协程来操作。

- sync.Mutex：竞争锁
- sync.RWMutex：读写锁

### 逃逸分析

逃逸分析：就是程序运行时内存的分配位置(栈或堆)。由编译器来确定的。堆适合不可预知大小的内存分配，但是为此付出的代价是分配速度较慢，而且会形成内存碎片。【这个说的不准确】

逃逸场景：

- 指针逃逸
- 栈空间不足逃逸
- 动态类型逃逸
- 闭包引用对象逃逸

## 快问快答

### go中除了加Mutex锁以外还有哪些方式安全读写共享变量？

go 中 Goroutine 可以通过 Channel 进行安全读写共享变量，而且官网建议使用这种方式，此方式的并发是由官方进行保证的。

### go 中 new 和 make 的区别？

- make 仅用来分配及初始化类型为应引用型的数据【slice、map、chan】。
- new 可分配任意类型的数据，根据传入的类型申请一块内存，返回指向这块内存的指针，即类型 *Type。
- make 返回引用，即Type, new分配的空间被清零，make 分配空间后，会进行初始。

### go 中对nil的 Slice 和空 Slice 的处理是一致的吗？

收钱Go的JSON标准库对nil slice 和空slice的处理是不一致。

- slice := make([]int, 0) : slice 不为 nil, 但是slice没有值， slice的底层的空间是空的。
- slice := []nil{}: slice 的值是nil，可用于需要返回slice的函数，当函数出现异常的时候，保证函数依然会有nil的返回值。

### 协程和线程和进程的区别？

- 调度：
    - 线程作为调度和分配的基本单元.
    - 进程作为拥有资源的基本单位.
    - 协程是不通过系统调用的，由用户态进行上下文切换
- 并发性：
    - 进程可以并发执行
    - 同一进程内的线程也可以并发执行。
    - 协程是基于线程实现的，线程的并发性，协程也同样有
- 拥有资源：
    - 进程是拥有资源的基本独立单元
    - 线程共享进程的资源
    - 有一种说法，线程是一种特殊进程。而协程是用户态的线程。
- 切换上下文时：
    - 线程的资源消费小于进程。因为进程需要对资源进行额为处理。
    - 协程的上下文切换，只需要修改三个寄存器值：PC/SP/DX，相比与线程的切换需要修改16个寄存器值以及用户态到内核态的切换等时间相比，协程切换特别快。

### go 的内存模型中为什么小对象多了会造成GC压力？

通常小对象过多会导致GC三色法消耗过多的CPU。优化思路是，减少对象分配。

### channel 为什么它可以做到线程安全？

channel 可以理解是一个先进先出的队列，通过管道进行通信，发送一个数据到channel和从channel接收一个数据都是原子性的。不要通过共享内存来通信，而是通过通信来共享内存，前者就是传统的加锁，后者就是channel。设计channel的主要目的就是在多任务间传递数据的，本身就是安全的。

### GC的触发条件？

- 主动触发(手动触发)，通过调用runtime.GC来触发GC，此调用是阻塞式地等待当前GC运行完毕。
- 被动触发，分为两种方式：
    - 使用系统监控，当超过两分钟没有产生任何GC时，强制触发GC.
    - 使用步调(pacing)算法，其核心思想是控制内存增长的比例，每次内存分配是检查当前内存分配量是否已达到阀值(环境变量 GOGC)：默认100%，即当内存扩大一倍时启用GC。

### 怎么查看协程的数量？怎么限制协程的数量？

- 在Go中，GOMAXPROCS 中控制的是未被阻塞的所有协程，可以被Multiplex到多少个线程运行，通过GOMAXPROCS可以查看协程的数量。(这个是并行数，描述的不对)
- 使用管道。每次执行的Go之前向管道写入值，知道管道满的时候就阻塞。(实现方式很多，这个属于通过管道进行缓存进行控制的)

### go 的struct 能不能比较？

- 相同struct 类型的可以比较
- 不同的struct 类型的不可以比较，编译都不过，类型不匹配。

### go 主协程如何等其余协程执行完再操作？

使用sync.WaitGroup. WaitGroup, 就是用来等待一组操作完成。WaitGroup内部实现了一个计数器，用来记录未完成的操作个数。

- Add()用来添加计数
- Done() 用来再操作结束时调用，是计数减一
- Wait() 用来等待所有的操作结束，计数不为0时阻塞等待。为0时，立即返回。

### Go的slice如果扩容？

- 若slice容量够的情况下： 将新元素追加进去， 长度增加， 返回原slice
- 若slice容量不够得情况下：
    - 若slice元素小于1024，创建新的slice 并将容量*2
    - 若slice语速大于1024，创建新的slice并将容量*1.25
    

### Go中的map 如何实现顺序读取？

Go 中map 如果要实现顺序读取的话，可以先把map中的Key，通过sort包排序。

### Go 值接收者和指正接受者的区别？

方法的接收者：

- 值类型，既可以调用值接收者的方法，也可以调用指针接收者的方法。
- 以指针类型接收者实现的接口，只有对应的指针类型才被认为实现接口。

通常我们使用指针作为方法的接收者的理由：

- 使用指针方法能够修改接收者指向的值。
- 可以避免在每次调用方法时复制该值，在值得类型为大型结构体时，这样做会更加高效。

### 在Go函数中为什么会有内存泄漏？

Goroutine 需要维护执行用户代码的上下文信息，在运行过程中需要消耗一定的内存来保存这类信息，如果一个程序持续不断地产生新的goroutine,且不结束已创建的goroutine并复用这部分内存，就会造成内存泄漏的现象。

### Goroutine 发生了泄漏如何检测？

可以通过Go 自带的工具pprof或者使用Gops去检测诊断当前在系统上运行的Go进程的占用的资源。

### Go 中两个Nil可能不相等吗？（主要看类型和值是否都相等，如果类型不相等的话，值都为Nil也不会相等）

Go 中两个Nil可能不相等。

接口(interface)是对非接口值(例如指针，struct等)的封装，内部实现包含2个字段，类型T和值V。一个借口等于nil，当且仅当T和V处于unset状态(T=nil,V is unset). 【？？？？？？？？？？？？？】

两个接口值比较时，会先比较T，再比较V。接口值与非接口值比较时，会先将非接口值尝试转换为接口值，再比较。

```go
func main(){

	var p *int =nil 
	var i interface{} = p

	fmt.Println(i==p) // true
	fmt.Println(p== nil) // true
	fmt.Println(i==nil) // false
}
```

- 例子中，将一个nil非接口值p赋值给接口i,此时i的内部字段为(T=*int,V=nil), i与p作比较时，将p装换为接口后再比较，因此i==p，p与nil 比较，直接比较值，所以p== nil.
- 但是当i与nil比较时，会将nil 转换为接口(T=nil，V=nil),与i(T=*int,V=nil)不相等，因此i≠nil。 因此V为nil，但T不为nil的接口不等于nil。

### Go语言函数传参是值类型还是引用类型？

- 在go语言中只存在值传递，要么是值得副本，要么是指针的副本。无论是值类型的变量还是引用类型的变量亦或者是指针类型的变量作为参数传递都会发生值拷贝，开辟新的内存空间。
- 另外值传递、引用传递和值类型、引用类型是两个不同的概念，不要混淆了。
    - 引用类型作为变量传递可以影响到函数外部是因为发生值拷贝后修旧变量指向了相同的内存地址。(原因是这个值是一个地址，地址被拷贝后的值依旧指向相同内存)
    

### Go语言中的内存对齐了解吗？

CPU访问内存时，并不是逐个字节访问，而是以字节(word size)长度为单位访问。比如32位的CPU,字节为4字节，那么CPU访问内存单位也是4字节。

CPU始终以字长访问内存，如果不进行内存对齐，很有可能增加CPU访问内存的次数，例如：

![Untitled](Untitled%205.png)

- 变量 a、b 各占据 3 字节的空间，内存对齐后，a、b 占据 4 字节空间，CPU 读取 b 变量的值只需要进行一次内存访问。如果不进行内存对齐，CPU 读取 b 变量的值需要进行 2 次内存访问。第一次访问得到 b 变量的第 1 个字节，第二次访问得到 b 变量的后两个字节。
- 也可以看到，内存对齐对实现变量的原子性操作也是有好处的，每次内存访问是原子的，如果变量的大小不超过字长，那么内存对齐后，对该变量的访问就是原子的，这个特性在并发场景下至关重要。
- 简言之：合理的内存对齐可以提高内存读写的性能，并且便于实现变量操作的原子性。

### 两个interface 可以比较吗？(可以通过反射)

- 判断类型是否一样？
    
    reflect.TypeOf(a).Kind() == reflect.TypeOf(b).Kind()
    
- 判断两个 interface{}是否相等
    
    reflect.DeepEqual(a, b interface{})
    
- 将一个 interface{}赋值给另一个 interface{}
    
    reflect.ValueOf(a).Elem().Set(reflect.ValueOf(b))
    

### go 打印时 %v %+v %#v的区别？

- %v 只输出所有的值
- %+v 先输出字段名字，再输出该字段的值
- %#v 先输出结构体名字值，在输出结构体(字段名字+字段的值)

```go
package main
import "fmt"
 
type student struct {
  id   int32
  name string
}
 
func main() {
  a := &student{id: 1, name: "微客鸟窝"}

  fmt.Printf("a=%v  \n", a) // a=&{1 微客鸟窝}  
  fmt.Printf("a=%+v  \n", a) // a=&{id:1 name:微客鸟窝}  
  fmt.Printf("a=%#v  \n", a) // a=&main.student{id:1, name:"微客鸟窝"}
}
```

### 什么是rune 类型？

Go 语言的字符有以下两种：

- uint8 类型，或者叫 byte类型，代表了ASCII码的一个字符。
- rune 类型，代表一个UTF-8字符，当需要处理中文、日文或者其它复合字符时，则需要用到rune类型。rune类型等价于int32类型。

```go
package main
import "fmt"

func main() {
    var str = "hello 你好" //思考下 len(str) 的长度是多少？
    
    //golang中string底层是通过byte数组实现的，直接求len 实际是在按字节长度计算  
    //所以一个汉字占3个字节算了3个长度
    fmt.Println("len(str):", len(str))  // len(str): 12

    //通过rune类型处理unicode字符
    fmt.Println("rune:", len([]rune(str))) //rune: 8
}
```

### 空struct{} 占用空间吗？

可以使用unsafe.Sizeof计算出一个数据类型实例需要占用的字节数：

```go
package main

import (
  "fmt"
  "unsafe"
)

func main() {
  fmt.Println(unsafe.Sizeof(struct{}{}))  //0
}
```

空结构体 struct{}实例不占据任何的内存空间。

空struct{}的用途？

因为空结构体不占据内存空间，因此被广泛作为各种场景的占位符使用。

- 将map作为集合(set)使用时，可以将值类型定义为空结构体，仅作为占位符使用即可。

```go
type Set map[string]struct{}

func (s Set) Has(key string) bool {
  _, ok := s[key]
  return ok
}

func (s Set) Add(key string) {
  s[key] = struct{}{}
}

func (s Set) Delete(key string) {
  delete(s, key)
}

func main() {
  s := make(Set)
  s.Add("Tom")
  s.Add("Sam")
  fmt.Println(s.Has("Tom"))
  fmt.Println(s.Has("Jack"))
}
```

- 不发送数据的信道(channel)
    
    使用channel不需要发送任何的数据，只用来通知子协程(goroutine)执行任务，或只用来控制协程并发度。
    
    ```go
    func worker(ch chan struct{}) {
    	<-ch // 阻塞等待
    	fmt.Println("do something")
    	close(ch)
    }
    
    func main() {
    	ch := make(chan struct{})
    	go worker(ch)
    	ch <- struct{}{}             // 通知协程执行
    	time.Sleep(10 * time.Second) // 这需要睡眠等待，否则，子协程还没有执行，就进程就退出了
    }
    ```
    
- 结构体只包含方法，不包含任何的字段
    
    ```go
    type Door struct{}
    
    func (d Door) Open() {
      fmt.Println("Open the door")
    }
    
    func (d Door) Close() {
      fmt.Println("Close the door")
    }
    ```