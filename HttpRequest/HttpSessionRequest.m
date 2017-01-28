//
//  HttpSessionRequest.m
//  HttpRequest
//
//  Created by Kenvin on 16/8/14.
//  Copyright © 2016年 上海方创金融股份服务有限公司. All rights reserved.
//

#import "AFNetworking.h"
#import <YYCache/YYCache.h>
#import "HttpSessionRequest.h"
#import "AFNetworkActivityIndicatorManager.h"

NSString * const HttpRequestCache = @"HttpRequestCache";

#define NTLog(...) NSLog(__VA_ARGS__)  //如果不需要打印数据, 注释掉NSLog

static NSMutableArray      *requestTasks;

static NSMutableDictionary *headers;

static NetworkStatus       networkStatus;

static NSTimeInterval      requestTimeout = 10;



#define ERROR_IMFORMATION @"网络出现错误，请检查网络连接"

#define ERROR [NSError errorWithDomain:@"请求失败" code:-999 userInfo:@{ NSLocalizedDescriptionKey:ERROR_IMFORMATION}]

@implementation HttpSessionRequest


+ (NSMutableArray *)allTasks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (requestTasks == nil) {
            requestTasks = [[NSMutableArray alloc] init];
        }
    });
    return requestTasks;
}

+ (void)configHttpHeaders:(NSDictionary *)httpHeaders {
    headers = httpHeaders.mutableCopy;
}

+ (void)setupTimeout:(NSTimeInterval)timeout {
    requestTimeout = timeout;
}

+ (AFHTTPSessionManager *)manager {
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFHTTPRequestSerializer serializer];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    manager.requestSerializer.stringEncoding = NSUTF8StringEncoding;
    AFJSONResponseSerializer *serializer = [AFJSONResponseSerializer serializer];
    [serializer setRemovesKeysWithNullValues:YES];
    
    [headers enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj) {
            [manager.requestSerializer setValue:headers[key] forHTTPHeaderField:key];
        }
    }];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithArray:@[@"application/json",
                                                                              @"text/html",
                                                                              @"text/json",
                                                                              @"text/plain",
                                                                              @"text/javascript",
                                                                              @"text/xml",
                                                                              @"image/*"]];
    manager.requestSerializer.timeoutInterval = requestTimeout;
    
    [self detectNetworkStaus];

    return manager;
}

#pragma 请求
+ (URLSessionTask *)requestWithUrl:(NSString *)url
                            params:(NSDictionary *)params
                          useCache:(BOOL)useCache
                       httpMedthod:(RequestType)httpMethod
                     progressBlock:(NetWorkingProgress)progressBlock
                      successBlock:(ResponseSuccessBlock)successBlock
                         failBlock:(ResponseFailBlock)failBlock {
    
    //处理中文和空格问题
    url = [url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    //拼接
    NSString * cacheUrl = [self urlDictToStringWithUrlStr:url WithDict:params];
    
    YYCache *cache = [[YYCache alloc] initWithName:HttpRequestCache];
    
    cache.memoryCache.shouldRemoveAllObjectsOnMemoryWarning = YES;
    cache.memoryCache.shouldRemoveAllObjectsWhenEnteringBackground = YES;
    
    id cacheData;
    
    if (useCache) {
        //根据网址从Cache中取数据
        cacheData = [cache objectForKey:cacheUrl];
        if (cacheData != 0) {
            //将数据统一处理
            if ([cacheData isKindOfClass:[NSDictionary  class]]) {
                NSDictionary *  requestDic = (NSDictionary *)cacheData;
                //根据返回的接口内容来变
                NSString * succ = [NSString stringWithFormat:@"%@",requestDic[@"code"]];
                if ([succ isEqualToString:@"2000"]) {
                    if ([requestDic isKindOfClass:[NSDictionary  class]]) {
                        NTLog(@"requestDic>>>  %@",requestDic);
                    }
                    successBlock ? successBlock(cacheData) : nil;
                }else{
                   failBlock ? failBlock(requestDic[@"msg"]) : nil;
                }
            }
        }
    }

    
    AFHTTPSessionManager *manager = [self manager];
    URLSessionTask *session;
    NSString *versionStr = [[[NSBundle mainBundle]infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    //版本号
    //kCFBundleIdentifierKey
    [params setValue:versionStr forKey:@"version"];
    //区分来源
    [params setValue:@"ios" forKey:@"os"];
    //当前使用的语言
    NSString *currentLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
    if (currentLanguage != nil && [currentLanguage length]>0) {
        [params setValue:currentLanguage forKey:@"language"];
    }
    
    if (httpMethod == POST) {
        
        if (networkStatus == NetworkStatusNotReachable ||  networkStatus == NetworkStatusUnknown) {
            failBlock ? failBlock(ERROR) : nil;
            
            return nil;
        }
        session = [manager POST:url parameters:params progress:^(NSProgress * _Nonnull downloadProgress) {
            if (progressBlock) {
                progressBlock(downloadProgress.completedUnitCount, downloadProgress.totalUnitCount);
            }
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
            if (useCache) {
                [cache setObject:responseObject forKey:cacheUrl];
            }
            
            NTLog(@">>>responseObject  %@",responseObject);
            
            if (!useCache || ![cacheData isEqual:responseObject]) {
                successBlock ? successBlock(responseObject) : nil;
            }
            
            [[self allTasks] removeObject:task];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            failBlock ? failBlock(error) : nil;
            
            [[self allTasks] removeObject:task];
        }];
        
    }else if(httpMethod == GET){
        
        if (networkStatus == NetworkStatusNotReachable ||  networkStatus == NetworkStatusUnknown) {
            failBlock ? failBlock(ERROR) : nil;
            
            return nil;
        }
        
        session = [manager GET:url parameters:params progress:^(NSProgress * _Nonnull downloadProgress) {
            if (progressBlock) {
                progressBlock(downloadProgress.completedUnitCount, downloadProgress.totalUnitCount);
            }
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            if (useCache) {
                [cache setObject:responseObject forKey:cacheUrl];
            }
            //这里可能会出现一种情况就是时间戳的问题，可能其他都是一样的，只有时间戳是不同的，那么就需要差异处理，最好不要返回不同的信息。
            if (!useCache || ![cacheData isEqual:responseObject]) {
                successBlock ? successBlock(responseObject) : nil;
                NTLog(@">>>responseObject  %@",responseObject);
            }
            
            [[self allTasks] removeObject:task];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            failBlock ? failBlock(error) : nil;
            
            [[self allTasks] removeObject:task];
        }];
    }
    if (session) {
        [requestTasks addObject:session];
    }
    return  session;
}


+ (void)updateRequestSerializerType:(SerializerType)requestType responseSerializer:(SerializerType)responseType {
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    
    if (requestType) {
        switch (requestType) {
            case HTTPSerializer: {
                manager.requestSerializer = [AFHTTPRequestSerializer serializer];
                break;
            }
            case JSONSerializer: {
                manager.requestSerializer = [AFJSONRequestSerializer serializer];
                break;
            }
            default:
                break;
        }
    }
    if (responseType) {
        switch (responseType) {
            case HTTPSerializer: {
                manager.responseSerializer = [AFHTTPResponseSerializer serializer];
                break;
            }
            case JSONSerializer: {
                manager.responseSerializer = [AFJSONResponseSerializer serializer];
                break;
            }
            default:
                break;
        }
    }
}


#pragma 图片，文件上传下载方法
+ (URLSessionTask *)uploadWithImage:(UIImage *)image
                                  url:(NSString *)url
                                 name:(NSString *)name
                                 type:(NSString *)type
                               params:(NSDictionary *)params
                        progressBlock:(NetWorkingProgress)progressBlock
                         successBlock:(ResponseSuccessBlock)successBlock
                            failBlock:(ResponseFailBlock)failBlock {
    AFHTTPSessionManager *manager = [self manager];
    
    URLSessionTask *session = [manager POST:url parameters:params constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        NSData *imageData = UIImageJPEGRepresentation(image, 0.4);
        
        NSString *imageFileName;
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        
        formatter.dateFormat = @"yyyyMMddHHmmss";
        
        NSString *str = [formatter stringFromDate:[NSDate date]];
        
        imageFileName = [NSString stringWithFormat:@"%@.png", str];
        
        NSString *blockImageType = type;
        
        if (type.length == 0) blockImageType = @"image/jpeg";
        
        [formData appendPartWithFileData:imageData name:name fileName:imageFileName mimeType:blockImageType];
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        if (progressBlock) {
            progressBlock(uploadProgress.completedUnitCount, uploadProgress.totalUnitCount);
        }
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        successBlock ? successBlock(responseObject) : nil;
        
        [[self allTasks] removeObject:task];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        failBlock ? failBlock(error) : nil;
        
        [[self allTasks] removeObject:task];
    }];
    
    [session resume];
    
    if (session) {
        [[self allTasks] addObject:session];
    }
    
    return session;
}

+ (URLSessionTask *)uploadFileWithUrl:(NSString *)url
                          uploadingFile:(NSString *)uploadingFile
                          progressBlock:(NetWorkingProgress)progressBlock
                           successBlock:(ResponseSuccessBlock)successBlock
                              failBlock:(ResponseFailBlock)failBlock {
    AFHTTPSessionManager *manager = [self manager];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    URLSessionTask *session = nil;
    
    [manager uploadTaskWithRequest:request fromFile:[NSURL URLWithString:uploadingFile] progress:^(NSProgress * _Nonnull uploadProgress) {
        if (progressBlock) {
            progressBlock(uploadProgress.completedUnitCount, uploadProgress.totalUnitCount);
        }
    } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        [[self allTasks] removeObject:session];
        
        successBlock ? successBlock(responseObject) : nil;
        
        failBlock && error ? failBlock(error) : nil;
    }];
    
    if (session) {
        [[self allTasks] addObject:session];
    }
    
    return session;
}

+ (URLSessionTask *)downloadWithUrl:(NSString *)url
                           saveToPath:(NSString *)saveToPath
                        progressBlock:(NetWorkingProgress)progressBlock
                         successBlock:(ResponseSuccessBlock)successBlock
                            failBlock:(ResponseFailBlock)failBlock {
    NSURLRequest *downloadRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    AFHTTPSessionManager *manager = [self manager];
    
    URLSessionTask *session = nil;
    
    session = [manager downloadTaskWithRequest:downloadRequest progress:^(NSProgress * _Nonnull downloadProgress) {
        if (progressBlock) {
            progressBlock(downloadProgress.completedUnitCount, downloadProgress.totalUnitCount);
        }
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return [NSURL URLWithString:saveToPath];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        [[self allTasks] removeObject:session];
        
        successBlock ? successBlock(filePath.absoluteString) : nil;
        
        failBlock && error ? failBlock(error) : nil;
    }];
    
    [session resume];
    
    if (session) {
        [[self allTasks] addObject:session];
    }
    
    return session;
}
+ (void)cancelAllRequest {
    @synchronized(self) {
        [[self allTasks] enumerateObjectsUsingBlock:^(URLSessionTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([task isKindOfClass:[URLSessionTask class]]) {
                [task cancel];
            }
        }];
        [[self allTasks] removeAllObjects];
    };
}

+ (void)cancelRequestWithURL:(NSString *)url {
    @synchronized(self) {
        [[self allTasks] enumerateObjectsUsingBlock:^(URLSessionTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([task isKindOfClass:[URLSessionTask class]]
                && [task.currentRequest.URL.absoluteString hasSuffix:url]) {
                [task cancel];
                [[self allTasks] removeObject:task];
                return;
            }
        }];
    };
}

/**
 *  拼接post请求的网址
 *
 *  @param urlStr     基础网址
 *  @param parameters 拼接参数
 *
 *  @return 拼接完成的网址
 */
+ (NSString *)urlDictToStringWithUrlStr:(NSString *)urlStr WithDict:(NSDictionary *)parameters{
    if (!parameters) {
        return urlStr;
    }
    
    NSMutableArray *parts = [NSMutableArray array];
    [parameters enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        //接收key
        NSString *finalKey = [key stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        //接收值
        NSString *finalValue = [obj stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        
        
        NSString *part =[NSString stringWithFormat:@"%@=%@",finalKey,finalValue];
        
        [parts addObject:part];
        
    }];
    
    NSString *queryString = [parts componentsJoinedByString:@"&"];
    
    queryString = queryString ? [NSString stringWithFormat:@"?%@",queryString] : @"";
    
    NSString *pathStr = [NSString stringWithFormat:@"%@?%@",urlStr,queryString];
    
    return pathStr;
}


#pragma mark - 网络状态的检测
+ (void)detectNetworkStaus {
    AFNetworkReachabilityManager *reachabilityManager = [AFNetworkReachabilityManager sharedManager];
    [reachabilityManager startMonitoring];
    [reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        if (status == AFNetworkReachabilityStatusNotReachable){
            networkStatus = NetworkStatusNotReachable;
        }else if (status == AFNetworkReachabilityStatusUnknown){
            networkStatus = NetworkStatusUnknown;
        }else if (status == AFNetworkReachabilityStatusReachableViaWWAN || status == AFNetworkReachabilityStatusReachableViaWiFi){
            networkStatus = NetworkStatusNormal;
        }
    }];
}

@end
