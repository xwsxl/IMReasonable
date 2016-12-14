
//  FavoritesViewController.m
//  IMReasonable
//
//  Created by apple on 14/12/22.
//  Copyright (c) 2014年 Reasonable. All rights reserved.
//

#import "PJNetWorkHelper.h"
#import "InviteAllFriendsController.h"
#import "PJSendInviteHttpTool.h"
#import "ContactsTool.h"
#import "ContactsViewController.h"
#import "AppDelegate.h"
#import "ChatUserTableViewCell.h"
#import "ChatViewController.h"
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import "ASIFormDataRequest.h"
#import "IMUser.h"
#import "FunctionTableViewCell.h"
#import "NewGroupViewController.h"
#import "XMPPRoomDao.h"
#import "AnimationHelper.h"
#import <MessageUI/MessageUI.h>

@interface ContactsViewController ()
{
    UITableView *tableview;
    NSMutableArray * chatuserlist;
    NSInteger index;
    
    NSMutableArray *filterData;
    
     UISearchDisplayController *searchDisplayController;
    UIActivityIndicatorView * at;
    NSString *cellphoneNumber;
    NSString *nickName;
}
@property(nonatomic,assign)BOOL isAdd;
@end

@implementation ContactsViewController

- (void)viewDidLoad {
    self.isAdd=NO;
    [super viewDidLoad];
    [XMPPDao sharedXMPPManager].chatHelerpDelegate=self;
    [self initNavbutton];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(localUserChange:)
                                                 name:@"CONNECTSCHANGE"
                                               object:nil];
    
    //chatuserlist=[[NSMutableArray alloc] init];
    
    [self initData];
    [self initControl];
    // Do any additional setup after loading the view.
}


-(void)localUserChange:(NSNotification *)nt{
    NSDictionary * dict=nt.userInfo;
    if ([[dict objectForKey:@"action"] isEqualToString:@"1"]) {// 开启联系人扫描动画
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [at startAnimating];
            self.navigationItem.title=NSLocalizedString(@"lblookforfriend",nil);
        });
       
        
        
    }else if([[dict objectForKey:@"action"] isEqualToString:@"2"]){ //停止动画 刷新数据
      
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [at stopAnimating];
            [self initData];
            self.navigationItem.title=NSLocalizedString(@"lbcontacts",nil);
        });
      
    }
    
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self initData];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
//    [self initData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) initData
{

    chatuserlist=[IMReasonableDao getContactsListModle];
    if (chatuserlist.count<5 ) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            
            NSMutableDictionary * dict=[[NSMutableDictionary alloc] initWithObjectsAndKeys:@"1",@"action", nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"CONNECTSCHANGE"
                                                                object:self userInfo:dict];
            
            ABAddressBookRef tmpAddressBook = nil;
            //根据系统版本不同，调用不同方法获取通讯录
            
            if ([[UIDevice currentDevice].systemVersion floatValue]>=6.0) {
                tmpAddressBook=ABAddressBookCreateWithOptions(NULL, NULL);
                dispatch_semaphore_t sema=dispatch_semaphore_create(0);
                ABAddressBookRequestAccessWithCompletion(tmpAddressBook, ^(bool greanted, CFErrorRef error){
                    dispatch_semaphore_signal(sema);
                });
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                
            }
            if (tmpAddressBook==nil) {
                return ;
            };
            
            CFArrayRef results = ABAddressBookCopyArrayOfAllPeople(tmpAddressBook);
            
            NSString* myphone= [[[[NSUserDefaults standardUserDefaults] objectForKey:XMPPREASONABLEJID] componentsSeparatedByString:@"@"] objectAtIndex:0];
            
            //在这里边获取所有的联系人
            for(int i = 0; i < CFArrayGetCount(results); i++)
            {
                ABRecordRef person = CFArrayGetValueAtIndex(results, i);
                //读取firstname
                NSString *firstname = (__bridge NSString*)ABRecordCopyValue(person, kABPersonFirstNameProperty);
                //读取lastname
                NSString *lastname = (__bridge NSString*)ABRecordCopyValue(person, kABPersonLastNameProperty);
                
                NSString * fullname;
                
                
                NSInteger personID = ABRecordGetRecordID(person);
                
                if ([Tool isHaveChinese:firstname]) {
                    fullname=[NSString stringWithFormat:@"%@%@",lastname?lastname:@"",firstname?firstname:@""];
                    
                }else{
                    fullname=[NSString stringWithFormat:@"%@ %@",firstname?firstname:@"",lastname?lastname:@""];
                }
                
                
                //读取电话多值
                ABMultiValueRef phone = ABRecordCopyValue(person, kABPersonPhoneProperty);
                for (int k = 0; k<10&&k<ABMultiValueGetCount(phone); k++)
                {
                    NSString * personPhoneLabel = (__bridge NSString*)ABAddressBookCopyLocalizedLabel(ABMultiValueCopyLabelAtIndex(phone, k));
                    //  获取該Label下的电话值
                    NSString * tmpPhoneIndex = (__bridge NSString*)ABMultiValueCopyValueAtIndex(phone, k);
                    NSString * unknowphone=[tmpPhoneIndex substringWithRange:NSMakeRange(0,1)];
                    tmpPhoneIndex=[Tool getPhoneNumber:tmpPhoneIndex];
                    NSString * flag=@"0";
                    
                    if (![tmpPhoneIndex isEqualToString:@""]&&(tmpPhoneIndex.length>=7))
                    {
                        
                        
                        NSString *firstPhone=[tmpPhoneIndex substringWithRange:NSMakeRange(0, 3)];
                        NSString *firstTwoPhone=[tmpPhoneIndex substringWithRange:NSMakeRange(0, 2)];
                        if (((tmpPhoneIndex.length==11)&&[firstPhone isEqualToString:@"852"])||((tmpPhoneIndex.length==13)&&[firstTwoPhone isEqualToString:@"86"]))
                        {
                            
                        }
                        else if (![unknowphone isEqualToString:@"+"])
                        {//需要当前用户的国家代码
                            NSString * countrycode=[[NSUserDefaults standardUserDefaults] objectForKey:XMPPUSERCOUNTRYCODE];
                            tmpPhoneIndex=[NSString stringWithFormat:@"%@%@",countrycode,tmpPhoneIndex];
                        }
                        if (![tmpPhoneIndex isEqualToString:myphone]) { //过滤掉自己的电话号码
                            [[XMPPDao sharedXMPPManager] XMPPAddFriendSubscribe:tmpPhoneIndex]; //不管是不是openfire的用户得发送邀请
                            
                            [IMReasonableDao saveUserLocalNick:tmpPhoneIndex image:fullname addid:[NSString stringWithFormat:@"%ld",(long)personID]  isImrea:flag phonetitle:personPhoneLabel];// 保存到本地数据库
                        }
                        
                    }
                    else
                    {
                        tmpPhoneIndex=@"0";
                    }
                    
                }
                
            }
            
            CFRelease(results);
            CFRelease(tmpAddressBook);
            
            [self GetAllRegUser];
            
        });
        chatuserlist=[IMReasonableDao getContactsListModle];
    }
    
    [self getfilterData];
 /* NSArray *array=[chatuserlist copy];
    NSLog(@"count=%ld",array.count);
    NSMutableArray *array1=[NSMutableArray array];
    NSMutableArray *array2=[NSMutableArray array];
    for (int i=0; i<array.count; i++) {
        IMChatListModle *model=chatuserlist[i];
        if ([self isRegToOpenfire:model.phonenumber]||[self isRegToOpenfire:model.jidstr]) {
            [array1 addObject:model];
        }
        else
        {
            [array2 addObject:model];
        }
    }
    NSLog(@"array1=%@",array1);
    NSLog(@"array2=%@",array2);
    NSArray *array3=[array1 sortedArrayUsingComparator:^NSComparisonResult(IMChatListModle * obj1, IMChatListModle * obj2) {
        
        return [obj1.localname compare:obj2.localname];
    }];
    NSArray *array4=[array2 sortedArrayUsingComparator:^NSComparisonResult(IMChatListModle * obj1, IMChatListModle * obj2) {
       return [obj1.localname compare:obj2.localname];
    }];
    NSLog(@"array3=%@,array4=%@",array3,array4);
   // [chatuserlist removeAllObjects];
   // [chatuserlist addObjectsFromArray:array3];
   // [chatuserlist addObjectsFromArray:array4];
                                                  */
        dispatch_async(dispatch_get_main_queue(), ^{
             [tableview reloadData];
        });
   

}

#pragma mark-创建导航栏上得按钮
- (void) initNavbutton
{
    at=[[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(40, 0, 35, 35)];
    at.activityIndicatorViewStyle= UIActivityIndicatorViewStyleGray;
    UIBarButtonItem* leftitem=[[UIBarButtonItem alloc]initWithCustomView:at];
    self.navigationItem.title=NSLocalizedString(@"lbcontacts",nil);
    UIBarButtonItem* addItem=[[UIBarButtonItem alloc]init];
    [addItem setTarget:self];
    [addItem setAction:@selector(addUser)];
    addItem.title=NSLocalizedString(@"lbaddUser", nil);
    NSArray *array=[[NSArray alloc]initWithObjects:addItem,leftitem, nil];
    self.navigationItem.leftBarButtonItems=array;
    //添加群邀按钮
    UIBarButtonItem *contactsRightBarButton=[[UIBarButtonItem alloc] init];
    [contactsRightBarButton setTarget:self];
    [contactsRightBarButton setAction:@selector(Invitation)];
    contactsRightBarButton.title=NSLocalizedString(@"lbinvitation",nil);
    self.navigationItem.rightBarButtonItem=contactsRightBarButton;
}
-(void)addUser
{
    if ([[[UIDevice currentDevice] systemVersion] floatValue]>=8.0)
    {
    UIAlertController *alertcontroller=[UIAlertController alertControllerWithTitle:NSLocalizedString(@"lbaddFriend", nil) message:@"" preferredStyle:UIAlertControllerStyleAlert];
//设置两个文本输入框
    [alertcontroller addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        if (nickName!=nil) {
            textField.text=nickName;
        }else
        {
        textField.placeholder=NSLocalizedString(@"lbphonename", nil);
        }
        textField.secureTextEntry=NO;
    }];
    [alertcontroller addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        if (cellphoneNumber==nil) {
            
            textField.placeholder=NSLocalizedString(@"lbphoneNumber", nil);
        }else
        {
            textField.text=cellphoneNumber;
        }
        textField.secureTextEntry=NO;
    }];
//添加操作按钮
    [alertcontroller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"lbTCancle", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
        }]];
    [alertcontroller addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"btnDone", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *phoneNumberField=alertcontroller.textFields.lastObject;
        NSString *nickname=alertcontroller.textFields.firstObject.text;
        NSString *phoneNumber=[[NSString alloc]init];
        if(phoneNumberField.text.length==8) {
            phoneNumber=[NSString stringWithFormat:@"852%@",phoneNumberField.text];
        }else if(phoneNumberField.text.length==11)
        {
            if ([[phoneNumberField.text substringWithRange:NSMakeRange(0, 3)] isEqualToString:@"852"]) {
                phoneNumber=phoneNumberField.text;
            }else
            {
                phoneNumber=[NSString stringWithFormat:@"86%@",phoneNumberField.text];
            }
        }else if(phoneNumberField.text.length==13)
        {
            phoneNumber=phoneNumberField.text;
        }else
        {
            nickName=nickname;
            cellphoneNumber=phoneNumberField.text;
            [self AlertMsg:NSLocalizedString(@"lbphonenumbererr", nil)];
            [self addUser];
        }
        if(phoneNumber.length==11||phoneNumber.length==13)
        {
            NSString *jidstr=[NSString stringWithFormat:@"%@%@",phoneNumber,XMPPSERVER2];
           // [IMReasonableDao saveUserLocalNick:phoneNumber image:nickname addid:Nil  isImrea:@"0" phonetitle:NSLocalizedString(@"lbphonetitlecell", nil)];
          //  [IMReasonableDao saveUser:jidstr nick:nickname group:nil isimrea:@"0"];
            [IMReasonableDao saveUser:jidstr image:nickname];
            NSMutableDictionary *dict=[[NSMutableDictionary alloc] init];
            [dict setObject:phoneNumber forKey:@"phone"];
            [dict setObject:nickname forKey:@"nickname"];
            [dict setObject:jidstr forKey:@"jidstr"];
            NSMutableArray *array=[NSMutableArray arrayWithObject:dict];
            [[XMPPDao sharedXMPPManager] checkUser:array];
        }

        
    }]];
    
//推出alert
    [self presentViewController:alertcontroller animated:YES completion:nil];
    }else
    {
    UIAlertView *addUserAlert=[[UIAlertView alloc]initWithTitle:NSLocalizedString(@"lbaddFriend", nil) message:nil delegate:self cancelButtonTitle:NSLocalizedString(@"lbTCancle", nil) otherButtonTitles:NSLocalizedString(@"btnDone", nil), nil];
    
    [addUserAlert setAlertViewStyle:UIAlertViewStyleLoginAndPasswordInput];

    UITextField *phoneNumberField=[addUserAlert textFieldAtIndex:1];
    
    phoneNumberField.secureTextEntry=NO;
    
    phoneNumberField.placeholder=NSLocalizedString(@"lbphoneNumber", nil);
    
    UITextField *nameField=[addUserAlert textFieldAtIndex:0];
    
    nameField.placeholder=NSLocalizedString(@"lbphonename", nil);
    self.isAdd=YES;
    [addUserAlert addSubview:phoneNumberField];
    [addUserAlert addSubview:nameField];
    [addUserAlert show];
    }
}
- (void)AlertMsg:(NSString*)msg
{
    MBProgressHUD* hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.removeFromSuperViewOnHide = YES;
    hud.mode = MBProgressHUDModeText;
    hud.labelText = msg;
    hud.minSize = CGSizeMake(132.f, 108.0f);
    [hud hide:YES afterDelay:2];
}
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex==alertView.firstOtherButtonIndex&&self.isAdd==YES)
    {
        UITextField *phoneNumberField=[alertView textFieldAtIndex:1];
        NSString *nickname=[alertView textFieldAtIndex:0].text;
        NSString *phoneNumber=[[NSString alloc]init];
        if(phoneNumberField.text.length==8) {
                phoneNumber=[NSString stringWithFormat:@"852%@",phoneNumberField.text];
        }else if(phoneNumberField.text.length==11)
        {
            if ([[phoneNumberField.text substringWithRange:NSMakeRange(0, 3)] isEqualToString:@"852"]) {
                phoneNumber=phoneNumberField.text;
            }else
            {
                phoneNumber=[NSString stringWithFormat:@"86%@",phoneNumberField.text];
            }
        }else if(phoneNumberField.text.length==13)
        {
          phoneNumber=phoneNumberField.text;
        }else
        {
            [self AlertMsg:NSLocalizedString(@"lbphonenumbererr", nil)];
        }
        if(phoneNumber.length==11||phoneNumber.length==13)
        {
        NSString *jidstr=[NSString stringWithFormat:@"%@%@",phoneNumber,XMPPSERVER2];
        [IMReasonableDao saveUserLocalNick:phoneNumber image:nickname addid:nil  isImrea:@"0" phonetitle:NSLocalizedString(@"lbphonetitlecell", nil)];
        NSMutableDictionary *dict=[[NSMutableDictionary alloc] init];
        [dict setObject:phoneNumber forKey:@"phone"];
        [dict setObject:nickname forKey:@"nickname"];
        [dict setObject:jidstr forKey:@"jidstr"];
        NSMutableArray *array=[NSMutableArray arrayWithObject:dict];
        [[XMPPDao sharedXMPPManager] checkUser:array];
        }
    }
    
    
    
    
}
//群邀
-(void)Invitation{
    self.isAdd=NO;
    if(![PJNetWorkHelper isNetWorkAvailable]){
        
        [PJNetWorkHelper NoNetWork];
    }else{
        
        [AnimationHelper showHUD:LOADING];
        InviteAllFriendsController *inviteAllFriendsController=[[InviteAllFriendsController alloc] init];
        UINavigationController * nvisecond=[[UINavigationController alloc] init];
        [nvisecond addChildViewController:inviteAllFriendsController];
        [self presentViewController:nvisecond animated:YES completion:nil];
    }
}

#pragma mark -uialertview代理
- (void)alertView:(UIAlertView*)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    //确定群邀
    if(buttonIndex==INVITE&&self.isAdd==NO){
        
        [self didInvitationAllFriends];
    }
}

//发送群邀
-(void)didInvitationAllFriends{
        [AnimationHelper show:NSLocalizedString(@"START_INVITE",nil) InView:[UIApplication sharedApplication].keyWindow.rootViewController.view];
        [ContactsTool DidInviteAllFriends:[ContactsTool AllPhoneAndEmail]];
}

- (void)addpeople:(UIBarButtonItem*) btn
{
    dispatch_async(dispatch_get_global_queue(2, 0), ^{
          NSMutableArray * allLacalUser=[IMReasonableDao getAllLocalUser];
        if(allLacalUser.count<=0){
            
            [self GetContacts];
        }else{
            
            for (int i=0; i<allLacalUser.count; i++) {
                IMChatListModle * tempuser=[allLacalUser objectAtIndex:i];
                [[XMPPDao sharedXMPPManager] XMPPAddFriendSubscribe2:tempuser.jidstr];
                [[XMPPDao sharedXMPPManager] queryOneRoster:tempuser.jidstr];
            }
        }
    });


    [self GetAllRegUser];//把不是好友的人
    [tableview reloadData];
    
}


- (void)GetAllRegUser{
    
    NSMutableArray * alluser=[IMReasonableDao getAllUser];
    
    [[XMPPDao sharedXMPPManager] checkUser:alluser];
}

- (void) checkUserArrSuc:(ASIHTTPRequest *) req{
    //请求成功了，就需要邀请成为朋友，并标记本地数据库的值为激活用户
    NSData *responsedata=[req responseData];
    NSDictionary * data=[Tool jsontodate:responsedata];
    NSDictionary *code=[data objectForKey:@"CheckByArrResult"];
    NSString * state=[code objectForKey:@"state"];
    if ([state isEqualToString:@"1"]) {
        NSArray * user=[code objectForKey:@"userarr"];
        if (![user isKindOfClass:[NSNull class]]  && user != nil && user.count != 0) {//如果有用户是使用过的
            NSString * data=@"";
            for (int i=0; i<user.count; i++) {
                
                NSString * phone=[user objectAtIndex:i];
                if (phone && ![phone isEqualToString:@""]) {
                    data=[NSString stringWithFormat:@"%@,%@",phone,data];
                    [[XMPPDao sharedXMPPManager] XMPPAddFriendSubscribe:phone]; //是openfire的用户就发送好友邀请
                    [[XMPPDao sharedXMPPManager] queryOneRoster:[NSString stringWithFormat:@"%@%@",phone,XMPPSERVER2]];//请求该联系人的信息
                }
                
            }
            
            if (data && data.length>2) {
                
                NSString *indata = [data substringToIndex:data.length - 1];
                [IMReasonableDao  updateUserIsLocal:indata];
                
                [self initData];
                
            }
            
            
        }
        
    }
    
    
}

- (void) checkUserArrFaied:(ASIHTTPRequest *) req{
    //失败了需要标记没有请求用户数据
}

//判断电话号码是否不是openfire账户;true  是  fase 不是
- (BOOL)isRegToOpenfire:(NSString *) phone
{
    NSURL *url = [NSURL URLWithString:  [Tool Append:IMReasonableAPP witnstring:@"UserIsReg"]];
    NSString * Apikey= IMReasonableAPPKey;
    NSString * tempphone=phone;
    NSDictionary *data = [[NSDictionary alloc] initWithObjectsAndKeys:Apikey, @"apikey",tempphone,@"phone",nil];
    NSDictionary *sendsmsD = [[NSDictionary alloc] initWithObjectsAndKeys:data, @"isreg", nil];
    if ([NSJSONSerialization isValidJSONObject:sendsmsD])
    {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:sendsmsD options:NSJSONWritingPrettyPrinted error: &error];
        NSMutableData *tempJsonData = [NSMutableData dataWithData:jsonData];
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
        [request addRequestHeader:@"Content-Type" value:@"application/json; encoding=utf-8"];
        [request addRequestHeader:@"Accept" value:@"application/json"];
        [request setRequestMethod:@"POST"];
        [request setPostBody:tempJsonData];
        [request startSynchronous ];
        error =[request error];
        if (error == nil ) {
            NSData *responsedata=[request responseData];
            NSDictionary * dict=[Tool jsontodate:responsedata];
            NSString *code=[dict objectForKey:@"UserIsRegResult"];
            BOOL flag=false;
            [code isEqualToString:@"1"]?(flag=true):(flag=false);
            return flag;
            
        } else {
            
            return false;
        }
        
    }else{
        
        return false;
        
    }
}


#pragma mark-系统联系人回调
//联系人界面点击取消时
-(void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

//选择一个联系人后是否需要调整下一个页面
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person
{
    return YES;
}

//选择练习人时是否可以打电话
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
    //返回NO就意味着不能操作上面的属性
    return NO;

}



#pragma mark-初始化Control
- (void)initControl
{
     self.edgesForExtendedLayout = UIRectEdgeNone ;
    tableview =[[UITableView alloc] initWithFrame:CGRectMake(0, 0, SCREENWIDTH, SCREENWIHEIGHT)];
    tableview.delegate=self;
    tableview.dataSource=self;
    tableview.tableFooterView = [[UIView alloc]init];//设置不要显示多余的行;
    
    
    // 添加搜索栏
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width
                                                                        , 44)];
    searchBar.barTintColor=[UIColor whiteColor];
    searchBar.placeholder =NSLocalizedString(@"lbfsearch",nil);;// @"搜索";//lbfsearch
    searchBar.delegate=self;
    tableview.tableHeaderView = searchBar;
    searchDisplayController = [[UISearchDisplayController alloc] initWithSearchBar:searchBar contentsController:self];
    searchDisplayController.delegate=self;
    searchDisplayController.searchResultsDataSource = self;
    searchDisplayController.searchResultsDelegate = self;
    
    
    UIRefreshControl * ref=[[UIRefreshControl alloc] init];
    ref.tintColor = [UIColor grayColor];
    //ref.backgroundColor=[UIColor redColor];
    ref.attributedTitle = [[NSAttributedString alloc]initWithString:NSLocalizedString(@"msgRef",nil)];
    [ref addTarget:self action:@selector(RefreshViewControlEventValueChanged:) forControlEvents:UIControlEventValueChanged];
    [tableview addSubview:ref];
    //tableview.backgroundColor=[UIColor greenColor];
    
    tableview.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:tableview];
    
}

-(void)RefreshViewControlEventValueChanged:(UIRefreshControl *)ref
{
    if (ref.refreshing) {
        
        ref.attributedTitle = [[NSAttributedString alloc]initWithString:NSLocalizedString(@"msgRefing",nil)];
        
        if(chatuserlist.count){
            [self initData];
        }else{
            [self addpeople:nil];
        }
        [self performSelector:@selector(RefTableview:) withObject:ref afterDelay:1];
        // [self RefTableview:ref];
        
    }
}

- (void) RefTableview:(UIRefreshControl *)ref
{
    [ref endRefreshing];
    ref.attributedTitle = [[NSAttributedString alloc]initWithString:NSLocalizedString(@"msgRef",nil)];
    [tableview reloadData];
    
}

#pragma mark- 表格代理是需要实现的方法

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return chatuserlist.count+1;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ChatListCell";
    
   // static NSString *CellIdentifier = @"ChatListCell";
    if ([indexPath row]==0) {
        FunctionTableViewCell * cell=[tableView dequeueReusableCellWithIdentifier:@"cell_Function"];
        if (cell == nil)
        {
            cell = [[FunctionTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                reuseIdentifier:@"cell_Function"];
            
            
            
            if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
                [cell setSeparatorInset:UIEdgeInsetsMake(0,0,0,0)];
            }
            
            if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
                [cell setLayoutMargins:UIEdgeInsetsMake(0,0,0,0)];
            }
        }
        
        //设置第一行的标题
        [cell.mucListBtn setTitle:NSLocalizedString(@"lbfaCreatbroadcast", nil) forState:UIControlStateNormal];
        [cell.mucListBtn setHidden:YES];
        
        [cell.mucChatBtn setTitle:NSLocalizedString(@"lbfaCreatgroup", nil) forState:UIControlStateNormal];
        
        //设置两个按钮的事件
        [cell.mucListBtn addTarget:self action:@selector(newMucList:) forControlEvents:UIControlEventTouchUpInside];
        [cell.mucChatBtn addTarget:self action:@selector(newMucChat:) forControlEvents:UIControlEventTouchUpInside];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        //NSLog(@"%@",NSStringFromCGRect(cell.frame));
        
        return cell;
        
        
        
    }else{
    
     ChatUserTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        cell = [[ChatUserTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        
        if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
            [cell setSeparatorInset:UIEdgeInsetsMake(0,0,0,0)];
        }
        
        if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
            [cell setLayoutMargins:UIEdgeInsetsMake(0,0,0,0)];
        }
    }
    
    
    IMChatListModle *temp=[chatuserlist objectAtIndex:[indexPath row]-1];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    UIImage * tempimg=[UIImage imageWithContentsOfFile:[Tool getFilePathFromDoc:temp.faceurl]];
        /*if([temp.jidstr isEqualToString:@"test@talk-king.net"]){
            temp.localname=@"Talkking";
        }*/
    cell.userphoto.image=tempimg?tempimg:[UIImage imageNamed:@"default"];//[UIImage imageNamed:temp.faceurl];
    cell.username.text=temp.localname; //?temp.localname:[[temp.jidstr componentsSeparatedByString:@"@"] objectAtIndex:0];
    cell.phoneown.text=temp.phoneown;
    cell.device.text= [temp.state isEqualToString:@"available"]?temp.device:@"";
    cell.invite.hidden=YES;
    cell.invite.tag=[indexPath row];
    
    if (![temp.isloc isEqualToString:@"1"]) {//显示邀请
            cell.invite.hidden=NO;
        [cell.invite addTarget:self action:@selector(inviteUser:) forControlEvents:UIControlEventTouchUpInside];
    }else{
       cell.invite.hidden=YES;
    }
    
        
    cell.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    return cell;
    }
    
}

#pragma mark - searchdelegate

- (BOOL) searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{

    [self getfilterData];
    return  YES;
}

- (void)getfilterData{
    
    [filterData removeAllObjects];
    
    NSString * search=searchDisplayController.searchBar.text;
    if (search.length>0) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"localname contains[c] %@ or phonenumber contains[c] %@ ",search,search];//用于过滤
        chatuserlist = [NSMutableArray arrayWithArray:[chatuserlist filteredArrayUsingPredicate:predicate]];
    }
    else{
         chatuserlist=[IMReasonableDao getContactsListModle];
         [tableview reloadData];
    }
   // [tableview reloadData];
}

- (BOOL) searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption
{
    //当scope改变时调用
    return YES;
}

-(void)searchBarCancelButtonClicked:(UISearchBar *)searchBar{
   
    chatuserlist=[IMReasonableDao getContactsListModle];
    [tableview reloadData];
}

-(void)inviteUser:(UIButton*)btn
{
    
    index=btn.tag-1;
    IMChatListModle *temp=[chatuserlist objectAtIndex:btn.tag-1];
    NSMutableDictionary * userdata=[[NSMutableDictionary alloc] init];
    [userdata setObject:temp.phonenumber forKey:@"phone"];
    [userdata setObject:temp.localname forKey:@"nickname"];
    NSMutableArray * alluser=[[NSMutableArray alloc] init];
    [alluser addObject:userdata];
    [AnimationHelper showHUD:NSLocalizedString(@"lbfasendinginvite", nil)];
    
    NSLog(@"%@",alluser);
    [self SendInvite:alluser getButton:btn];

}

- (void)SendInvite:(NSMutableArray *)alluser getButton:(UIButton*)btn
{
 
    NSString* phone= [[[[NSUserDefaults standardUserDefaults] objectForKey:XMPPREASONABLEJID] componentsSeparatedByString:@"@"] objectAtIndex:0];
    
    NSURL *url = [NSURL URLWithString:  [Tool Append:IMReasonableAPP witnstring:@"SendInvitationSMS"]];
    NSString * Apikey= IMReasonableAPPKey;
    NSDictionary *sendsms = [[NSDictionary alloc] initWithObjectsAndKeys:Apikey, @"apikey",phone,@"ownphone",alluser,@"userarr", nil];
    NSDictionary *sendsmsD = [[NSDictionary alloc] initWithObjectsAndKeys:sendsms, @"senddata", nil];
    if ([NSJSONSerialization isValidJSONObject:sendsmsD])
    {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:sendsmsD options:NSJSONWritingPrettyPrinted error: &error];
        NSMutableData *tempJsonData = [NSMutableData dataWithData:jsonData];
        ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
        [request addRequestHeader:@"Content-Type" value:@"application/json; encoding=utf-8"];
        [request addRequestHeader:@"Accept" value:@"application/json"];
        [request setRequestMethod:@"POST"];
        [request setPostBody:tempJsonData];
        [request setDelegate:self];
        [request setDidFinishSelector:@selector(sendInviteSuc:)];
        [request setDidFailSelector:@selector(sendInviteFaied:)];
        [request startAsynchronous];
        [btn setTitle:NSLocalizedString(@"INVITE_FINISHED", nil) forState:UIControlStateNormal];
    }
}

- (void) sendInviteSuc:(ASIHTTPRequest *) req{
    
    [AnimationHelper removeHUD];
    //[Tool alert:NSLocalizedString(@"lbfasendsucinvite", nil)];
    NSData *responsedata=[req responseData];
    NSDictionary * data=[Tool jsontodate:responsedata];
    NSDictionary * code=[data objectForKey:@"SendInvitationResult"];
    
    NSInteger state=(NSInteger)[code valueForKey:@"count"];
    if (state>0) {
        NSArray * user=[code objectForKey:@"userarr"];
        if ( ![user isKindOfClass:[NSNull class]]  && user != nil && user.count != 0) {//如果有用户是使用过的
            NSString * data=@"";
            for (int i=0; i<user.count; i++) {
                
                NSString * phone=[user objectAtIndex:i];
                if (phone && ![phone isEqualToString:@""]) {
                    data=[NSString stringWithFormat:@"%@,%@",phone,data];
                    [[XMPPDao sharedXMPPManager] XMPPAddFriendSubscribe:phone]; //是openfire的用户就发送好友邀请
                    [[XMPPDao sharedXMPPManager] queryOneRoster:[NSString stringWithFormat:@"%@%@",phone,XMPPSERVER2]];//请求该联系人的信息
                }
                
            }
            
            if (data && data.length>2) {
                
                NSString *indata = [data substringToIndex:data.length - 1];
                [IMReasonableDao  updateUserIsLocal:indata];
                
            }
        }
         [self initData];
    }
}

- (void) sendInviteFaied:(ASIHTTPRequest *) req{
    [AnimationHelper removeHUD];
    IMChatListModle *temp=[chatuserlist objectAtIndex:index];
    [self showMessageView:[NSArray arrayWithObjects:temp.phonenumber, nil] title:@"123" body:[self getSMSContent]];
}

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
        
        switch (buttonIndex)
        {
            case 0:
            {
                IMChatListModle *temp=[chatuserlist objectAtIndex:index];
                [self showMessageView:[NSArray arrayWithObjects:temp.phonenumber, nil] title:@"123" body:[self getSMSContent]];
            }
                break;
            case 1:
                // 取消 不需要做任何操作
                
                break;
        }
}

- (NSString *)getSMSContent{
    
    IMChatListModle *temp=[chatuserlist objectAtIndex:index];
    NSUserDefaults *defaults =[NSUserDefaults standardUserDefaults];
    
    NSString * name=[defaults objectForKey:MyLOCALNICKNAME];
    NSString *jidstr=[[[defaults stringForKey:XMPPREASONABLEJID] componentsSeparatedByString:@"@"] objectAtIndex:0];
    
     NSRange range = [temp.phonenumber rangeOfString:CH];
    if (range.location==0 &&range.length>0) {
        
        NSString *phone=[temp.phonenumber substringFromIndex:range.length];
        
        return [NSString stringWithFormat:InvitationSms86,temp.localname,name,phone];
        
    }
    range = [temp.phonenumber rangeOfString:HK];
    if (range.location==0 &&range.length>0) {
        NSString *phone=[temp.phonenumber substringFromIndex:range.length];
        return [NSString stringWithFormat:InvitationSms852,temp.localname,name,phone];
    }
    range = [temp.phonenumber rangeOfString:@"1"];
    
    if (range.location==0 &&range.length>0 && temp.phonenumber.length==11) {
        NSString *phone=[NSString stringWithFormat:@"+1 %@",[jidstr substringFromIndex:1]];
        return [NSString stringWithFormat:InvitationSms,temp.localname,name,phone];
    }
    
    NSString *phone=jidstr;
    return [NSString stringWithFormat:InvitationSms,temp.localname,name,phone];

}

-(void)showMessageView:(NSArray *)phones title:(NSString *)title body:(NSString *)body
{
    if( [MFMessageComposeViewController canSendText] )
    {
        MFMessageComposeViewController * controller = [[MFMessageComposeViewController alloc] init];
        controller.recipients = phones;
        //controller.navigationBar.tintColor = [UIColor greenColor];
        controller.body = body;
        controller.messageComposeDelegate = self;
        [self presentViewController:controller animated:YES completion:nil];
        [[[[controller viewControllers] lastObject] navigationItem] setTitle:title];//修改短信界面标题
    }
    /*
     
     ajjaegaejgjaejgaeghaheghaheghjiujiajaiejijijaijijaiejliiaeii
     lkieag
     
     
     
     
     */
}

-(void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    [self dismissViewControllerAnimated:YES completion:nil];
    switch (result) {
        case MessageComposeResultSent:
            //信息传送成功
            [Tool alert:@"信息发送成功"];
            
            break;
        case MessageComposeResultFailed:
            //信息传送失败
            
            break;
        case MessageComposeResultCancelled:
            //信息被用户取消传送
            
            break;
        default:
            break;
    }
}

#pragma mark-新建列表和聊天室
-(void)newMucList:(UIButton*)btn
{
    [Tool alert:@"asd"];
    
}

-(void)newMucChat:(UIButton*)btn
{

    UINavigationController *nav=[[UINavigationController alloc]init];
    NewGroupViewController * newgroup=[[NewGroupViewController alloc]init];
    [nav addChildViewController:newgroup];
    [self presentViewController:nav animated:YES completion:nil];
    
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    IMChatListModle * temp=[chatuserlist objectAtIndex:[indexPath row]-1];
    if ([temp.isloc isEqualToString:@"1"]) {
        [searchDisplayController.searchBar resignFirstResponder];
        
        ChatViewController *Cannotview=[[ChatViewController alloc] init];
        Cannotview.from=temp;
        [chatuserlist replaceObjectAtIndex:[indexPath row]-1 withObject:temp];
        Cannotview.hidesBottomBarWhenPushed=YES;
        
        UIBarButtonItem *backItem = [[UIBarButtonItem alloc] init];
        backItem.title =NSLocalizedString(@"lbchats",nil);
        self.navigationItem.backBarButtonItem = backItem;
        [self.navigationController pushViewController:Cannotview animated:NO];
    }else{
     
        NSMutableArray *arruser=[[NSMutableArray alloc] init];
        NSDictionary *dict=[[NSDictionary alloc] initWithObjectsAndKeys:temp.jidstr,@"jidstr", nil];
        [arruser addObject:dict];
        [[XMPPDao sharedXMPPManager] checkUser:arruser];
        
        if(temp.localname.length>0)
        {
            
            NSString *locaname=temp.localname;
            ABAddressBookRef tmpAddressBook = nil;
            //根据系统版本不同，调用不同方法获取通讯录
            if ([[UIDevice currentDevice].systemVersion floatValue]>=6.0) {
                tmpAddressBook=ABAddressBookCreateWithOptions(NULL, NULL);
                dispatch_semaphore_t sema=dispatch_semaphore_create(0);
                ABAddressBookRequestAccessWithCompletion(tmpAddressBook, ^(bool greanted, CFErrorRef error){
                    dispatch_semaphore_signal(sema);
                });
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
                
            }
            
            
            
            if (tmpAddressBook==nil) {
                return ;
            };
    
            ABRecordRef person=NULL;
   
            
            NSArray* arrayByName = (NSArray*)CFBridgingRelease(ABAddressBookCopyPeopleWithName(tmpAddressBook, CFBridgingRetain(locaname)));
            if (arrayByName.count>0&&arrayByName.count==1) {
                person =CFBridgingRetain([arrayByName objectAtIndex:0]);
            }else
            {
                
                NSArray* tmpPeoples = (NSArray*)CFBridgingRelease(ABAddressBookCopyArrayOfAllPeople(tmpAddressBook));
                for(id tmpPerson in tmpPeoples){
                
            
                    
                    ABMultiValueRef tmpPhones = ABRecordCopyValue(CFBridgingRetain(tmpPerson), kABPersonPhoneProperty);
                   
                    for(NSInteger j = 0; j < ABMultiValueGetCount(tmpPhones); j++)
                    {
                     
        
                        NSString* tmpPhoneIndex = (NSString*)CFBridgingRelease(ABMultiValueCopyValueAtIndex(tmpPhones, j));
                        NSString * unknowphone=[tmpPhoneIndex substringWithRange:NSMakeRange(0,1)];
                        tmpPhoneIndex=[Tool getPhoneNumber:tmpPhoneIndex];
                        if (![unknowphone isEqualToString:@"+"]) {//需要当前用户的国家代码
                            NSString * countrycode=[[NSUserDefaults standardUserDefaults] objectForKey:XMPPUSERCOUNTRYCODE];
                            tmpPhoneIndex=[NSString stringWithFormat:@"%@%@",countrycode,tmpPhoneIndex];
                        }
                        
                        if ([tmpPhoneIndex isEqualToString:temp.phonenumber]) {
                            person=CFBridgingRetain(tmpPerson);
                            break;
                        }
                
                }
            }
          }
            
            if (person != NULL) {
                ABPersonViewController * personViewController = [[ABPersonViewController alloc]init];
                [personViewController setDisplayedPerson:person];
                personViewController.allowsEditing =NO;
                personViewController.hidesBottomBarWhenPushed=YES;
                [self.navigationController pushViewController:personViewController animated:YES];
            }
    }
        
}
    
    
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 55;
    
}

-(void)viewDidLayoutSubviews
{
    //去除分割线左边出现的空格
    if ([tableview respondsToSelector:@selector(setSeparatorInset:)]) {
        [tableview setSeparatorInset:UIEdgeInsetsMake(0,0,0,0)];
    }
    
    if ([tableview respondsToSelector:@selector(setLayoutMargins:)]) {
        [tableview setLayoutMargins:UIEdgeInsetsMake(0,0,0,0)];
    }
}

#pragma mark-ChatHelperDelegate
//聊天代理
- (void) userStatusChange:(XMPPPresence *)presence
{
    
    
    if (![presence.type isEqualToString:@"error"])
    {
        NSPredicate *predicate=[NSPredicate predicateWithFormat:@"jidstr = %@", presence.from.bare];
        NSArray * group = [chatuserlist filteredArrayUsingPredicate:predicate];
        if (group.count>0) {
              IMChatListModle * tempuser=[group objectAtIndex:0];
                  tempuser.state=presence.type;
                  tempuser.device=presence.from.resource;
        }
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [tableview reloadData];
        });
    }

}
-(void)receiveNewMessage:(MessageModel *)message isFwd:(BOOL)isfwd
{
    
    
}
- (void) isSuccSendMessage:(IMMessage *)msg issuc:(BOOL) flag
{
    
    if (flag) {
        [self initData];
    }
}

#pragma mark-ConnectsChangeDelegate
-(void)ContactsChange
{
    [self initData];

}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:YES];
}

-(void)dealloc
{
    
     [[NSNotificationCenter defaultCenter] removeObserver:self name:@"CONNECTSCHANGE" object:nil];
}

//在这个函数里面创建数据库并获取扫描联系人
- (void)GetContacts
{
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        // [AnimationHelper showHUD:NSLocalizedString(@"lblookforfriend",nil)];
        
        ABAddressBookRef tmpAddressBook = nil;
        //根据系统版本不同，调用不同方法获取通讯录
        if ([[UIDevice currentDevice].systemVersion floatValue] >= 6.0) {
            tmpAddressBook = ABAddressBookCreateWithOptions(NULL, NULL);
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            ABAddressBookRequestAccessWithCompletion(tmpAddressBook, ^(bool greanted, CFErrorRef error) {
                dispatch_semaphore_signal(sema);
            });
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        }
        if (tmpAddressBook == nil) {
            return;
        };
        
        CFArrayRef results = ABAddressBookCopyArrayOfAllPeople(tmpAddressBook);
        
        NSString* myphone = [[[[NSUserDefaults standardUserDefaults] objectForKey:XMPPREASONABLEJID] componentsSeparatedByString:@"@"] objectAtIndex:0];
        
        //在这里边获取所有的联系人
        for (int i = 0; i < CFArrayGetCount(results); i++) {
            ABRecordRef person = CFArrayGetValueAtIndex(results, i);
            //读取firstname
            NSString* firstname = (__bridge NSString*)ABRecordCopyValue(person, kABPersonFirstNameProperty);
            //读取lastname
            NSString* lastname = (__bridge NSString*)ABRecordCopyValue(person, kABPersonLastNameProperty);
            
            NSString* fullname;
            
            NSInteger personID = ABRecordGetRecordID(person);
            
            if ([Tool isHaveChinese:firstname]) {
                fullname = [NSString stringWithFormat:@"%@%@", lastname ? lastname : @"", firstname ? firstname : @""];
            }
            else {
                fullname = [NSString stringWithFormat:@"%@ %@", firstname ? firstname : @"", lastname ? lastname : @""];
            }
            
            //读取电话多值
            ABMultiValueRef phone = ABRecordCopyValue(person, kABPersonPhoneProperty);
            for (int k = 0; k < ABMultiValueGetCount(phone); k++) {
                NSString* personPhoneLabel = (__bridge NSString*)ABAddressBookCopyLocalizedLabel(ABMultiValueCopyLabelAtIndex(phone, k));
                //  获取該Label下的电话值
                NSString* tmpPhoneIndex = (__bridge NSString*)ABMultiValueCopyValueAtIndex(phone, k);
                
                NSString* unknowphone = [tmpPhoneIndex substringWithRange:NSMakeRange(0, 1)];
                tmpPhoneIndex = [Tool getPhoneNumber:tmpPhoneIndex];
                NSString* flag = @"0";
                if (![tmpPhoneIndex isEqualToString:@""]) {
                    
                    if (![unknowphone isEqualToString:@"+"]) { //需要当前用户的国家代码
                        NSString* countrycode = [[NSUserDefaults standardUserDefaults] objectForKey:XMPPUSERCOUNTRYCODE];
                        tmpPhoneIndex = [NSString stringWithFormat:@"%@%@", countrycode, tmpPhoneIndex];
                    }
                    
                    if (![tmpPhoneIndex isEqualToString:myphone]) { //过滤掉自己的电话号码
                        [[XMPPDao sharedXMPPManager] XMPPAddFriendSubscribe:tmpPhoneIndex]; //不管是不是openfire的用户得发送邀请
                        [IMReasonableDao saveUserLocalNick:tmpPhoneIndex image:fullname addid:[NSString stringWithFormat:@"%ld", (long)personID] isImrea:flag phonetitle:personPhoneLabel]; // 保存到本地数据库
                    }
                }
            }
        }
        
        CFRelease(results);
        CFRelease(tmpAddressBook);
        
        [AnimationHelper removeHUD];
        
        [self GetAllRegUser];
        
    });
}

//cell加载时的动画效果
-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    AppDelegate* appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    if (appDelegate.openAnimation) {
        
        // 从锚点位置出发，逆时针绕 Y 和 Z 坐标轴旋转90度
        CATransform3D transform3D = CATransform3DMakeRotation(M_PI_2, 0.0, 1.0, 1.0);
        // 定义 cell 的初始状态
        cell.alpha = 0.0;
        cell.layer.transform = transform3D;
        cell.layer.anchorPoint = CGPointMake(0.0, 0.5); // 设置锚点位置；默认为中心点(0.5, 0.5)
        [UIView animateWithDuration:0.6 animations:^{
            cell.alpha = 1.0;
            cell.layer.transform = CATransform3DIdentity;
            CGRect rect = cell.frame;
            rect.origin.x = 0.0;
            cell.frame = rect;
        }];
    }
}

@end
