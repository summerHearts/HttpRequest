//
//  ViewController.m
//  HttpRequest
//
//  Created by Kenvin on 16/8/14.
//  Copyright © 2016年 上海方创金融股份服务有限公司. All rights reserved.
//

#import "ViewController.h"
#import "HttpSessionRequest.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [HttpSessionRequest requestWithUrl:@"http://123.57.188.187/eliteall/3187/hosts/openapi/api.php?token=dfad3fe6a365776d469cbfc05ae24079&cust_id=10288&display_id=e732270d08dd610c0e930dd4bc5084da&appkey=46982266432&timer=1468204513309&type=projectAPI&method=eliteall.project&cust_class=3&username=15202153577&class=getcustomers&classtype=investors&search=&perpage=1&createtimer=0"
                         params:nil
                       useCache:NO
                    httpMedthod:GET
                  progressBlock:^(int64_t bytesRead, int64_t totalBytes) {
        
    } successBlock:^(id response) {
        
    } failBlock:^(NSError *error) {
        
    }];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
