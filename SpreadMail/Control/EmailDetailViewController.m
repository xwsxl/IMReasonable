//
//  EmailDetailViewController.m
//  IMReasonable
//
//  Created by 翁金闪 on 15/11/19.
//  Copyright © 2015年 Reasonable. All rights reserved.
//

#define ERROR_999 -999//当异步加载取消返回。当它执行取消操作上加载资源时，Web 工具包框架委托将收到此错误

#import "PJNetWorkHelper.h"
#import "SpreadMailModel.h"
#import "EmailDetailViewController.h"
#import "AnimationHelper.h"
#import "MBProgressHUD.h"

@interface EmailDetailViewController ()

@property(nonatomic,strong)UIWebView *webView;
//是否成功加载过网页一次
@property(nonatomic,assign)BOOL hasLoadSucOnce;
//是否是返回上一个网页
@property(nonatomic,assign)BOOL isGoBack;
//重新加载
@property(nonatomic,strong)UIButton *reLoadButton;

@end

@implementation EmailDetailViewController

-(void)initController{
    UIButton *btn=[UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame=CGRectMake(0, 0, 120, 44);
    [btn setImage:[UIImage imageNamed:@"back"] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
    btn.imageEdgeInsets=UIEdgeInsetsMake(0, -120, 0, 0);
    UILabel *lab=[[UILabel alloc]initWithFrame:CGRectMake(10, 0, 60, 44)];
    
    lab.text=NSLocalizedString(@"BACK", nil);
    [btn addSubview:lab];
    UIBarButtonItem *backButton2=[[UIBarButtonItem alloc]initWithCustomView:btn];
    self.navigationItem.leftBarButtonItem=backButton2;
    
    
    UIBarButtonItem *backButton =[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"BACK", nil)
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self action:@selector(back)];
 //  UIBarButtonItem *button1=[[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"nav_back_normal"] style:UIBarButtonItemStyleBordered target:self action:@selector(back)];
    //self.navigationItem.leftBarButtonItem = button1;
    //self.navigationItem.backBarButtonItem=backButton;
   // self.navigationItem.leftBarButtonItems=@[button1,backButton];
    self.webView=[[UIWebView alloc] init];
    CGRect webViewFrame=CGRectMake(0, 0, SCREENWIDTH, SCREENWIHEIGHT);
    self.webView.scalesPageToFit=YES;
    self.webView.frame=webViewFrame;
    [self.view addSubview:self.webView];
    self.webView.delegate=self;
    NSURLRequest *request=[NSURLRequest requestWithURL:[NSURL URLWithString:self.model.newsletterLinkUrl] cachePolicy:NSURLRequestReloadRevalidatingCacheData timeoutInterval:16.0];
  //  NSLog(@"%@",self.model.newsletterLinkUrl);
    [self.webView loadRequest:request];
    [self initView];
}

-(void)initView{
    [self.view addSubview:self.reLoadButton];
}

-(UIButton *)reLoadButton{
    if(_reLoadButton==nil){
        
        _reLoadButton=[[UIButton alloc]init];
        [_reLoadButton setTitle:NSLocalizedString(@"RELOAD", nil) forState:UIControlStateNormal];
        [_reLoadButton addTarget:self action:@selector(reLoad) forControlEvents:UIControlEventTouchUpInside];
        _reLoadButton.frame=CGRectMake(0, 0, 100, 100);
        _reLoadButton.center=self.view.center;
        _reLoadButton.titleLabel.textColor=[UIColor blackColor];
        [_reLoadButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [_reLoadButton setTitleColor:[UIColor grayColor] forState:UIControlStateHighlighted];
        _reLoadButton.hidden=YES;
    }
    return _reLoadButton;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self initController];
 //   NSLog(@"%@",self.model.newsletterLinkUrl);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)webViewDidStartLoad:(UIWebView *)webView{
//    [AnimationHelper showHUD:@"load......"];
    self.navigationItem.title=NSLocalizedString(@"LOADING", nil);
   // NSLog(@"webViewDidStartLoad");
}

-(void)webViewDidFinishLoad:(UIWebView *)webView{
    self.hasLoadSucOnce=true;
//    [AnimationHelper removeHUD];
    self.navigationItem.title=NSLocalizedString(@"LOAD_COMPLETION", nil);
   // NSLog(@"webViewDidFinishLoad");
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
    if(!self.hasLoadSucOnce){
        
        self.reLoadButton.hidden=NO;
    }else{
        
        self.reLoadButton.hidden=YES;
    }
//    [AnimationHelper removeHUD];
    self.navigationItem.title=NSLocalizedString(@"FAILED_TO_LOAD", nil);
    if([PJNetWorkHelper isNetWorkAvailable]&&error.code!=ERROR_999){
        
        [AnimationHelper show:NSLocalizedString(@"FAILED_TO_LOAD", nil) InView:self.view];
    }
    NSLog(@"didFailLoadWithError:%ld",(long)error.code);
}

-(void)reLoad{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSURLRequest *request=[NSURLRequest requestWithURL:[NSURL URLWithString:self.model.newsletterLinkUrl] cachePolicy:NSURLRequestReloadRevalidatingCacheData timeoutInterval:16.0];
        [self.webView loadRequest:request];
    });
}

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
    if([PJNetWorkHelper isNetWorkAvailable]){
        
        return true;
    }else if(self.isGoBack&&navigationType!=UIWebViewNavigationTypeLinkClicked){
        
        return true;
    }
    else{
        
        [PJNetWorkHelper NoNetWork];
        return false;
    }
}

-(void)back{
    if(self.webView.canGoBack){
        
        self.isGoBack=YES;
        [self.webView goBack];
    }else{
        
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
