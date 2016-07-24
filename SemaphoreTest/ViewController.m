//
//  ViewController.m
//  SemaphoreTest
//
//  Created by Clark on 16/7/13.
//  Copyright © 2016年 CK. All rights reserved.
//

#import "ViewController.h"
#import <pthread.h>
#import <libkern/OSAtomic.h>
#import <QuartzCore/QuartzCore.h>

@interface ViewController ()

@end

@implementation ViewController

#pragma mark - life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
//    [self testSynchronized];
//    [self testDispatch_semaphore];
//    [self testNSLock];
//    [self testNSRecursiveLock];
//    [self testNSConditionLock];
//    [self testNSCondition];
//    [self testPthread_mutex];
//    [self test_pthread_mutex_recursive];
    [self test_OOSpinLock];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - private methods
#pragma mark - 线程同步8种方式和性能对比
#pragma mark 1、@synchronized
- (void)testSynchronized {
    /*
     1、obj 作为该锁的唯一标识，只有当标识相同时，才满足互斥（线程2阻塞），执行结果：
     2016-07-13 23:54:15.251 SemaphoreTest[1040:22522] 需要线程同步的操作1 开始
     2016-07-13 23:54:18.255 SemaphoreTest[1040:22522] 需要线程同步的操作1 结束
     2016-07-13 23:54:18.255 SemaphoreTest[1040:22486] 需要线程同步的操作2

     2、如果线程2中的obj换成self，则线程2不会被阻塞，执行结果：
     2016-07-13 23:48:17.733 SemaphoreTest[974:19734] 需要线程同步的操作1 开始
     2016-07-13 23:48:18.736 SemaphoreTest[974:19708] 需要线程同步的操作2
     2016-07-13 23:48:20.735 SemaphoreTest[974:19734] 需要线程同步的操作1 结束
     */
    NSObject *obj = [[NSObject alloc] init];
    // 线程 1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized (obj) {
            NSLog(@"需要线程同步的操作1 开始");
            sleep(3);
            NSLog(@"需要线程同步的操作1 结束");

        }
    });
    
    // 线程 2
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
       
        sleep(1);
        @synchronized (obj) {
            NSLog(@"需要线程同步的操作2");
        }
    });
    
}
// 2、dipatch_semaphore
- (void)testDispatch_semaphore {

    //dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) 取得一个全局的并发队列
    dispatch_semaphore_t signal = dispatch_semaphore_create(1);
    dispatch_time_t overTime = DISPATCH_TIME_FOREVER;//dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程1开始。。。。");
        dispatch_semaphore_wait(signal, overTime);
        NSLog(@"需要线程同步的操作1 开始");
        sleep(2);
        NSLog(@"需要线程同步的操作1 结束");
        dispatch_semaphore_signal(signal);
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSLog(@"线程2开始。。。。");
        sleep(1);
        dispatch_semaphore_wait(signal, overTime);
        NSLog(@"需要线程同步的操作2 开始");
        dispatch_semaphore_signal(signal);
        
    });
    
    
    // 并发数为10线程队列
    dispatch_group_t group = dispatch_group_create();
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(10);
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    for (int i = 0; i < 100; i++)
    {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        dispatch_group_async(group, queue, ^{
            NSLog(@"%i",i);
            sleep(2);
            dispatch_semaphore_signal(semaphore);
        });
//        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//            NSLog(@"%i",i);
//            sleep(2);
//            dispatch_semaphore_signal(semaphore);
//        });
    }
    //多个队列组完成后会自动通知
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"完成 - 100个队列组");
    });
//    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
}
// 2、NSLock
- (void)testNSLock {

    NSLock *lock = [[NSLock alloc] init];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [lock lockBeforeDate:[NSDate date]];
        NSLog(@"需要线程同步操作1 开始");
        sleep(5);
        NSLog(@"需要线程同步操作1 结束");
        [lock unlock];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        if ([lock tryLock]) {// 尝试获取锁，如果获取不到返回NO,不会阻塞该线程
            NSLog(@"锁可用的操作");
            [lock unlock];
        }else {
        
            NSLog(@"锁不可用的操作");
        }
        NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:DISPATCH_TIME_FOREVER];
        if ([lock lockBeforeDate:date]) {// 尝试在未来3s内获取锁，并阻塞该线程，如果3s内获取不到恢复线程，返回NO，不会阻塞该线程
            NSLog(@"没有超时,获得锁");
            [lock unlock];
        } else {
        
            NSLog(@"超时，没有获得锁");
        }
        
    });
}
//4、NSRecursiveLock
- (void)testNSRecursiveLock {

    NSRecursiveLock *lock = [[NSRecursiveLock alloc] init];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        static void (^RecursiveMethod)(int);
        RecursiveMethod = ^(int value) {
        
            [lock lock];
            if (value > 0) {
                NSLog(@"value = %d",value);
                sleep(1);
                RecursiveMethod(value - 1);
            }
            [lock unlock];
            
        };
        RecursiveMethod(5);
    });
    
}
// 6、NSConditionLock
- (void)testNSConditionLock {

    NSMutableArray *productcs = [NSMutableArray array];
    NSConditionLock *lock = [[NSConditionLock alloc] init];
    NSInteger HAS_DATA = 1;
    NSInteger NO_DATA = 0;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (1) {
            [lock lockWhenCondition:NO_DATA];
            [productcs addObject:[[NSObject alloc] init]];
            NSLog(@"produc a product , 总量:%zi",productcs.count);
            [lock unlockWithCondition:HAS_DATA];
            sleep(1);
            
        }
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (1) {
            NSLog(@"wait for product");
            [lock lockWhenCondition:HAS_DATA];
            [productcs removeObjectAtIndex:0];
            NSLog(@"custome a product");
            [lock unlockWithCondition:NO_DATA];
//            sleep(1);
        }
    });
}

// 6、NSConditionLock
- (void)testNSCondition {
    
    NSMutableArray *productcs = [NSMutableArray array];
    NSCondition *lock = [[NSCondition alloc] init];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (1) {
            
            [lock lock];
            if ([productcs count] == 0) {
                NSLog(@"wait for product");
                [lock wait];
            }
            [productcs removeObjectAtIndex:0];
            NSLog(@"custome a product");
            [lock unlock];
            
        }
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (1) {
            
            [lock lock];
            [productcs addObject:[[NSObject alloc] init]];
            NSLog(@"produce a product , 总量:%zi",productcs.count);
            [lock signal];
            [lock unlock];
            sleep(1);
        }
    });
}

- (void)testPthread_mutex {

    __block pthread_mutex_t theLock;
    pthread_mutex_init(&theLock,NULL);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        pthread_mutex_lock(&theLock);
        NSLog(@"需要线程同步的操作1 开始");
        sleep(3);
        NSLog(@"需要线程同步的操作1 结束");
        pthread_mutex_unlock(&theLock);
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        pthread_mutex_lock(&theLock);
        NSLog(@"需要线程同步的操作2");
        pthread_mutex_unlock(&theLock);
    });
    
}

// pthread_mutex(recursive)
- (void)test_pthread_mutex_recursive {

    __block pthread_mutex_t theLock;
    // pthread_mutex_init(&theLock,NULL);//这行代码创建锁，下面会出现死锁
    
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&theLock, &attr);
    pthread_mutexattr_destroy(&attr);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        static void (^RecursiveMethod)(int);
        RecursiveMethod = ^(int value) {
            
            pthread_mutex_lock(&theLock);
            if (value > 0) {
                NSLog(@"value = %d",value);
                sleep(1);
                RecursiveMethod(value-1);
            
            }
            pthread_mutex_unlock(&theLock);
        
        };
        RecursiveMethod(5);
        
    });
}

// OSSPinLock 效率最高的锁！！不过听说不安全了！！
- (void)test_OOSpinLock {
    
    __block OSSpinLock theLock = OS_SPINLOCK_INIT;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSpinLockLock(&theLock);
        NSLog(@"需要线程同步操作1 开始");
        sleep(3);
        NSLog(@"需要线程同步的操作2 结束");
        OSSpinLockUnlock(&theLock);
        
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSpinLockLock(&theLock);
        sleep(1);
        NSLog(@"需要线程同步的操作2");
        OSSpinLockUnlock(&theLock);
    });

}

@end
