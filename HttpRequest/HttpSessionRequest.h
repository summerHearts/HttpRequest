//
//  HttpSessionRequest.h
//  HttpRequest
//
//  Created by Kenvin on 16/8/14.
//  Copyright © 2016年 上海方创金融股份服务有限公司. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface HttpSessionRequest : NSObject
/**
 *  网络状态
 */
typedef NS_ENUM(NSInteger, NetworkStatus) {
    /**
     *  未知网络
     */
    NetworkStatusUnknown             = 1 << 0,
    /**
     *  无法连接
     */
    NetworkStatusNotReachable        = 1 << 2,
    /**
     *  网络正常
     */
    NetworkStatusNormal              = 1 << 3
};

/**
 *  请求方式
 */
typedef NS_ENUM(NSInteger, RequestType) {
    /**
     *  POST方式来进行请求
     */
    POST = 1 << 0,
    /**
     *  GET方式来进行请求
     */
    GET  = 1 << 1
};

/**
 *  数据串行方式
 */
typedef NS_ENUM(NSInteger, SerializerType) {
    /**
     *  HTTP方式来进行请求或响应
     */
    HTTPSerializer = 1 << 0,
    /**
     *  JSON方式来进行请求或响应
     */
    JSONSerializer = 1 << 1
};

/**
 *  请求任务  起个别名，你懂的
 */
typedef NSURLSessionTask URLSessionTask;

/**
 *  成功回调
 *
 *  @param response 成功后返回的数据
 */
typedef void(^ResponseSuccessBlock)(id response);

/**
 *  失败回调
 *
 *  @param error 失败后返回的错误信息
 */
typedef void(^ResponseFailBlock)(NSError *error);

/**
 *  进度
 *
 *  @param bytesWritten              已下载或者上传进度的大小
 *  @param totalBytes                总下载或者上传进度的大小
 */
typedef void(^NetWorkingProgress)(int64_t bytesRead,
                                    int64_t totalBytes);


/**
 *  @brief  发起请求的参数键值对
 */
@property (strong, nonatomic) NSMutableDictionary *parameters;

/**
 *  配置请求头
 *
 *  @param httpHeaders 请求头参数
 */
+ (void)configHttpHeaders:(NSDictionary *)httpHeaders;

/**
 *  取消所有请求
 */
+ (void)cancelAllRequest;

/**
 *  根据url取消请求
 *
 *  @param url 请求url
 */
+ (void)cancelRequestWithURL:(NSString *)url;


/**
 *	设置超时时间
 *
 *  @param timeout 超时时间
 */
+ (void)setupTimeout:(NSTimeInterval)timeout;

/**
 *  更新请求或者返回数据的解析方式(0为HTTP模式，1为JSON模式)
 *
 *  @param requestType  请求数据解析方式
 *  @param responseType 返回数据解析方式
 */
+ (void)updateRequestSerializerType:(SerializerType)requestType
                 responseSerializer:(SerializerType)responseType;

/**
 *  统一请求接口
 *
 *  @param url              请求路径
 *  @param params           拼接参数
 *  @param httpMethod       请求方式（0为POST,1为GET）
 *  @param useCache         是否使用缓存
 *  @param progressBlock    进度回调
 *  @param successBlock     成功回调block
 *  @param failBlock        失败回调block
 *
 *  @return 返回的对象中可取消请求
 */
+ (URLSessionTask *)requestWithUrl:(NSString *)url
                              params:(NSDictionary *)params
                            useCache:(BOOL)useCache
                         httpMedthod:(RequestType)httpMethod
                       progressBlock:(NetWorkingProgress)progressBlock
                        successBlock:(ResponseSuccessBlock)successBlock
                           failBlock:(ResponseFailBlock)failBlock;

/**
 *  图片上传接口
 *
 *	@param image            图片对象
 *  @param url              请求路径
 *	@param name             图片名
 *	@param type             默认为image/jpeg
 *	@param params           拼接参数
 *	@param progressBlock    上传进度
 *	@param successBlock     成功回调
 *	@param failBlock		失败回调
 *
 *  @return 返回的对象中可取消请求
 */
+ (URLSessionTask *)uploadWithImage:(UIImage *)image
                                  url:(NSString *)url
                                 name:(NSString *)name
                                 type:(NSString *)type
                               params:(NSDictionary *)params
                        progressBlock:(NetWorkingProgress)progressBlock
                         successBlock:(ResponseSuccessBlock)successBlock
                            failBlock:(ResponseFailBlock)failBlock;

/**
 *  文件上传接口
 *
 *  @param url              上传文件接口地址
 *  @param uploadingFile    上传文件路径
 *  @param progressBlock    上传进度
 *	@param successBlock     成功回调
 *	@param failBlock		失败回调
 *
 *  @return 返回的对象中可取消请求
 */
+ (URLSessionTask *)uploadFileWithUrl:(NSString *)url
                          uploadingFile:(NSString *)uploadingFile
                          progressBlock:(NetWorkingProgress)progressBlock
                           successBlock:(ResponseSuccessBlock)successBlock
                              failBlock:(ResponseFailBlock)failBlock;

/**
 *  文件下载接口
 *
 *  @param url           下载文件接口地址
 *  @param saveToPath    存储目录
 *  @param progressBlock 下载进度
 *  @param successBlock  成功回调
 *  @param failBlock     下载回调
 *
 *  @return 返回的对象可取消请求
 */
+ (URLSessionTask *)downloadWithUrl:(NSString *)url
                           saveToPath:(NSString *)saveToPath
                        progressBlock:(NetWorkingProgress)progressBlock
                         successBlock:(ResponseSuccessBlock)successBlock
                            failBlock:(ResponseFailBlock)failBlock;


@end
