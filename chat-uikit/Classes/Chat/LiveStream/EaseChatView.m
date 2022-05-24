//
//  EaseChatView.m
//
//  Created by EaseMob on 16/5/9.
//  Copyright © 2016年 zilong.li All rights reserved.
//

#import "EaseChatView.h"
#import "EaseInputTextView.h"
#import "EaseChatroomMessageCell.h"
#import "EaseCustomSwitch.h"
#import "EaseChatroomJoinCell.h"
#import "EaseHeaders.h"


#define kSendTextButtonWitdh 190.0
#define kSendTextButtonHeight 32.0
#define kButtonHeight 40
#define kDefaultSpace 8.f
#define kDefaulfLeftSpace 10.f
#define kTextViewHeight 30.f
#define kUnreadButtonWitdh 150.0
#define kUnreadButtonHeight 20.0


void(^sendMsgCompletion)(AgoraChatMessage *message, AgoraChatError *error);

@interface EaseChatView () <AgoraChatManagerDelegate,UITableViewDelegate,UITableViewDataSource,UITextViewDelegate>
{
    NSString *_chatroomId;
    long long _curtime;
    BOOL _isBarrageInfo;
    NSTimer *_timer;
    NSInteger _praiseInterval;
    NSInteger _praiseCount;
    
}


@property (nonatomic,strong) AgoraChatConversation *conversation;
@property (nonatomic,strong) AgoraChatroom *chatroom;

@property (nonatomic,strong) UIView *bottomSendMsgView;
@property (nonatomic,strong) EaseInputTextView *textView;
//@property (nonatomic,strong) UIButton *sendButton;
@property (nonatomic,strong) UIButton *unreadButton;
@property (nonatomic, strong) UILabel *unreadLabel;

@property (nonatomic,strong) EaseCustomMessageHelper* customMsgHelper;

//custom chatView UI with option
@property (nonatomic, strong) EaseChatViewCustomOption *customOption;

//message queue
@property (nonatomic, strong) dispatch_queue_t msgQueue;

@property (nonatomic, strong) NSString *moreMsgId;

@property (nonatomic, assign) BOOL canScroll;


@end

@implementation EaseChatView
#pragma mark life cycle
- (instancetype)initWithFrame:(CGRect)frame
                     chatroom:(AgoraChatroom*)chatroom
              customMsgHelper:(EaseCustomMessageHelper*)customMsgHelper
                 customOption:(EaseChatViewCustomOption *)customOption {
    
    self = [super initWithFrame:frame];
    if (self) {
        self.customMsgHelper = customMsgHelper;
        self.customOption = customOption;
        self.chatroom = chatroom;
        
        _chatroomId = self.chatroom.chatroomId;
        _isBarrageInfo = false;
        _praiseInterval = 0;
        _praiseCount = 0;
        _curtime = (long long)([[NSDate date] timeIntervalSince1970]*1000);
        _canScroll = YES;
        _msgQueue = dispatch_queue_create("emmessage.com", NULL);

    
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyBoardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyBoardWillHide:) name:UIKeyboardWillHideNotification object:nil];
        
        [self placeAndLayoutSubviews];
        
        
        [[AgoraChatClient sharedClient].chatManager addDelegate:self delegateQueue:dispatch_get_main_queue()];

        self.conversation = [[AgoraChatClient sharedClient].chatManager getConversation:_chatroomId type:AgoraChatConversationTypeChatRoom createIfNotExist:YES];
        self.moreMsgId = @"";
        
        [self loadMessageScrollBottom:YES];
    }
    
    return self;
}


- (void)dealloc {
    [[AgoraChatClient sharedClient].chatManager removeDelegate:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)placeAndLayoutSubviews {
    [self addSubview:self.tableView];
    [self addSubview:self.unreadButton];
    [self addSubview:self.sendTextButton];
    
    [self.tableView Ease_makeConstraints:^(EaseConstraintMaker *make) {
        make.top.equalTo(self);
        make.left.equalTo(self);
        make.right.equalTo(self).offset(-self.customOption.tableViewRightMargin);
        make.bottom.equalTo(self.sendTextButton.ease_top);
    }];
    
    
    [self.unreadButton Ease_makeConstraints:^(EaseConstraintMaker *make) {
        make.width.equalTo(@(kUnreadButtonWitdh));
        make.height.equalTo(@(kUnreadButtonHeight));
        make.left.equalTo(self.tableView).offset(12.0);
        make.bottom.equalTo(self.sendTextButton.ease_top).offset(-12.0);
    }];

    
    [self.sendTextButton Ease_makeConstraints:^(EaseConstraintMaker *make) {
        make.left.equalTo(self).offset(12.0);
        if (self.customOption.sendTextButtonRightMargin > 0) {
            make.width.equalTo(self).offset(-self.customOption.sendTextButtonRightMargin);
        }else {
            make.width.equalTo(@(kSendTextButtonWitdh));
        }
        make.height.equalTo(@(kSendTextButtonHeight));
        make.bottom.equalTo(self).offset(-self.customOption.sendTextButtonBottomMargin);
    }];
    
    //bottom textView && sendButton
    [self placeAndLayoutBottomSendView];
}

- (void)placeAndLayoutBottomSendView {
    [self addSubview:self.bottomSendMsgView];
    [self.bottomSendMsgView addSubview:self.textView];
//    [self.bottomSendMsgView addSubview:self.sendButton];
    
    [self.bottomSendMsgView Ease_makeConstraints:^(EaseConstraintMaker *make) {
        make.left.right.equalTo(self);
        make.height.equalTo(@(kSendTextButtonHeight));
        make.bottom.equalTo(self).offset(-self.customOption.sendTextButtonBottomMargin);
    }];
    
    [self.textView Ease_makeConstraints:^(EaseConstraintMaker *make) {
        make.edges.equalTo(self.bottomSendMsgView).insets(UIEdgeInsetsMake(2.0, 2.0, 2.0, 2.0));
    }];
    
//    [self.sendButton Ease_makeConstraints:^(EaseConstraintMaker *make) {
//        make.centerY.equalTo(self.textView);
//        make.width.equalTo(@(40.0));
//        make.right.equalTo(self.bottomSendMsgView).offset(-5);
//        make.height.equalTo(self.textView);
//    }];
}

#pragma mark load message
- (void)loadMessageScrollBottom:(BOOL)isScrollBottom
{
    
    [self.conversation loadMessagesStartFromId:self.moreMsgId count:50 searchDirection:AgoraChatMessageSearchDirectionUp completion:^(NSArray *aMessages, AgoraChatError *aError) {
        [self.tableView reloadData];
        [self updateUI];

    }];
}



#pragma mark - AgoraChatManagerDelegate
- (void)messagesDidReceive:(NSArray *)aMessages
{
            
    EaseKit_WS
    dispatch_async(self.msgQueue, ^{
        NSString *conId = weakSelf.conversation.conversationId;
        NSMutableArray *msgArray = [[NSMutableArray alloc] init];
        for (int i = 0; i < [aMessages count]; i++) {
            AgoraChatMessage *msg = aMessages[i];
            if (![msg.conversationId isEqualToString:conId]) {
                continue;
            }
            
            //filter custom gift message
            if (msg.body.type == AgoraChatMessageBodyTypeCustom) {
                AgoraChatCustomMessageBody* customBody = (AgoraChatCustomMessageBody*)msg.body;
                if ([customBody.event isEqualToString:kCustomMsgChatroomGift]) {
                    continue;
                }
            }
            
            [msgArray addObject:msg];
        }
        
        if (self.canScroll) {
            AgoraChatError *error = nil;
            [weakSelf.conversation markAllMessagesAsRead:&error];
            if (error) {
                return;
            }
        }

        [self.datasource addObjectsFromArray:msgArray];

        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self.tableView reloadData];
            [self updateUI];
        });
    });
}

- (void)updateUI {
    if (self.canScroll) {
        if (self.datasource.count > 0) {
            [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:[self.datasource count] - 1] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
    }else {
        self.unreadLabel.text = [NSString stringWithFormat:@"%@ New Messages",@(self.conversation.unreadMessagesCount)];
        self.unreadButton.hidden = NO;
    }
    
}

- (void)cmdMessagesDidReceive:(NSArray *)aCmdMessages
{
    for (AgoraChatMessage *message in aCmdMessages) {
        if ([message.conversationId isEqualToString:_chatroomId]) {
            if (message.timestamp < _curtime) {
                continue;
            }
        }
    }
}


#pragma  mark - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    if ([self.delegate respondsToSelector:@selector(easeMessageCellHeightAtIndexPath:)]) {
        return [self.delegate easeMessageCellHeightAtIndexPath:indexPath];
    }
    
    if ([self.delegate respondsToSelector:@selector(easeJoinCellHeightAtIndexPath:)]) {
        return [self.delegate easeJoinCellHeightAtIndexPath:indexPath];
    }

    AgoraChatMessage *message = [self.datasource objectAtIndex:indexPath.section];
    if ([message.ext objectForKey:EaseKit_chatroom_join]) {
        return 44.0;
    }
    return [EaseChatroomMessageCell heightForMessage:message];
}

#pragma mark - UITableViewDataSource
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 5;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    UIView *blank = [[UIView alloc]initWithFrame:CGRectMake(0, 0, self.frame.size.width, 5)];
    blank.backgroundColor = [UIColor clearColor];
    return blank;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.datasource count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    if (self.customOption.customMessageCell) {
        if ([self.delegate respondsToSelector:@selector(easeMessageCellForRowAtIndexPath:)]) {
            return [self.delegate easeMessageCellForRowAtIndexPath:indexPath];
        }
    }

    
    if (self.customOption.customJoinCell) {
        if ([self.delegate respondsToSelector:@selector(easeJoinCellForRowAtIndexPath:)]) {
            return [self.delegate easeJoinCellForRowAtIndexPath:indexPath];
        }
    }
    
    EaseChatroomMessageCell *messageCell = [tableView dequeueReusableCellWithIdentifier:[EaseChatroomMessageCell reuseIdentifier]];
    if (messageCell == nil) {
        messageCell = [[[EaseChatroomMessageCell class] alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[EaseChatroomMessageCell reuseIdentifier] customOption:self.customOption];
    }


    EaseChatroomJoinCell *joinCell = [tableView dequeueReusableCellWithIdentifier:[EaseChatroomJoinCell reuseIdentifier]];
    if (joinCell == nil) {
        joinCell = [[[EaseChatroomJoinCell class] alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[EaseChatroomJoinCell reuseIdentifier] customOption:self.customOption];
    }

    if (!self.datasource || [self.datasource count] < 1)
        return nil;
    AgoraChatMessage *message = [self.datasource objectAtIndex:indexPath.section];
    if ([message.ext objectForKey:EaseKit_chatroom_join]) {
        [joinCell updateWithObj:message];
        joinCell.tapCellBlock = ^{
            [self.textView resignFirstResponder];
            self.canScroll = NO;

            if (self.delegate && [self.delegate respondsToSelector:@selector(didSelectUserWithMessage:)]) {
                [self.delegate didSelectUserWithMessage:message];
            }
        };

        return joinCell;
    }else {
        [messageCell setMesssage:message chatroom:self.chatroom];
        messageCell.tapCellBlock = ^{
            [self.textView resignFirstResponder];
            self.canScroll = NO;

            if (self.delegate && [self.delegate respondsToSelector:@selector(didSelectUserWithMessage:)]) {
                [self.delegate didSelectUserWithMessage:message];
            }
        };
    }
    return messageCell;
    
}


#pragma mark - UIScrollViewDelegate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self resetUnreadState];
}


- (void)resetUnreadState {
    self.canScroll = YES;
    self.unreadButton.hidden = YES;
    [self.conversation markAllMessagesAsRead:nil];
}

#pragma mark - UITextViewDelegate
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    return YES;
}


- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if (text.length > 0 && [text isEqualToString:@"\n"]) {
        if (_isBarrageInfo) {
            [self sendBarrageMsg:self.textView.text];
        } else {
            [self sendText];
        }
        [self textViewDidChange:self.textView];
        return NO;
    }
    [self textViewDidChange:self.textView];
    return YES;
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    [self _setSendState:NO];
}

- (void)textViewDidChange:(UITextView *)textView
{
//    if (self.textView.text.length > 0 && ![self.textView.text isEqualToString:@""]) {
//        self.sendButton.backgroundColor = [UIColor colorWithRed:4/255.0 green:174/255.0 blue:240/255.0 alpha:1.0];
//        self.sendButton.tag = 1;
//    } else {
//        self.sendButton.backgroundColor = [UIColor lightGrayColor];
//        self.sendButton.tag = 0;
//    }
    
}

#pragma mark public method
- (void)updateChatViewWithHidden:(BOOL)isHidden {
    self.tableView.hidden = isHidden;
    self.sendTextButton.hidden = isHidden;
}


#pragma mark - UIKeyboardNotification
- (void)keyBoardWillShow:(NSNotification *)note
{
    // Obtaining User information
    NSDictionary *userInfo = [NSDictionary dictionaryWithDictionary:note.userInfo];
    // Get keyboard height
    CGRect keyBoardBounds  = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyBoardHeight = keyBoardBounds.size.height;
        
    CGFloat offSet = keyBoardHeight - self.customOption.sendTextButtonBottomMargin;

    if (self.delegate && [self.delegate respondsToSelector:@selector(chatViewDidBottomOffset:)]) {
        [self.delegate chatViewDidBottomOffset:offSet];
    }

}


- (void)keyBoardWillHide:(NSNotification *)note
{
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatViewDidBottomOffset:)]) {
        [self.delegate chatViewDidBottomOffset:0];
    }

}

- (AgoraChatMessage *)_sendTextMessage:(NSString *)text
                                    to:(NSString *)toUser
                           messageType:(AgoraChatType)messageType
                            messageExt:(NSDictionary *)messageExt {
    
    AgoraChatMessageBody *body = [[AgoraChatTextMessageBody alloc] initWithText:text];
    NSString *from = [[AgoraChatClient sharedClient] currentUsername];
    AgoraChatMessage *message = [[AgoraChatMessage alloc] initWithConversationID:toUser from:from to:toUser body:body ext:messageExt];
    message.chatType = messageType;
    return message;
}

- (void)_setSendState:(BOOL)state
{
    if (state) {
        self.bottomSendMsgView.hidden = NO;
        self.sendTextButton.hidden = YES;
        [self.textView becomeFirstResponder];
    } else {
        self.bottomSendMsgView.hidden = YES;
        self.sendTextButton.hidden = NO;
        [self.textView resignFirstResponder];
    }
}

#pragma mark - action
//- (void)sendMsgAction
//{
//    if (self.sendButton.tag == 1) {
//        if (_isBarrageInfo) {
//            [self sendBarrageMsg:self.textView.text];
//        } else {
//            [self sendText];
//        }
//    }
//}

- (void)unreadButtonAction {
    
    [self resetUnreadState];

    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:[self.datasource count] - 1] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}


- (void)sendTextAction
{
    [self _setSendState:YES];
}


- (void)sendText
{
    if (self.textView.text.length > 0) {
        AgoraChatMessage *message = [self _sendTextMessage:self.textView.text to:_chatroomId messageType:AgoraChatTypeChatRoom messageExt:nil];
        EaseKit_WS
        [[AgoraChatClient sharedClient].chatManager sendMessage:message progress:NULL completion:^(AgoraChatMessage *message, AgoraChatError *error) {
            if ([self.delegate respondsToSelector:@selector(chatViewDidSendMessage:error:)]) {
                [self.delegate chatViewDidSendMessage:message error:error];
            }
            
            if (!error) {
                [weakSelf currentViewDataFill:message];
                weakSelf.textView.text = @"";
                [weakSelf _setSendState:NO];
                [weakSelf resetUnreadState];
            }
        }];
        
    }
}


- (void)sendBarrageMsg:(NSString*)text
{
    EaseKit_WS
    [self.customMsgHelper sendCustomMessage:text num:0 to:_chatroomId messageType:AgoraChatTypeChatRoom customMsgType:customMessageType_barrage completion:^(AgoraChatMessage * _Nonnull message, AgoraChatError * _Nonnull error) {
        if (!error) {
//            [_customMsgHelper barrageAction:message backView:self.superview];
            [weakSelf currentViewDataFill:message];
        } else {
            [self.delegate chatViewDidSendMessage:message error:error];
        }
    }];
    self.textView.text = @"";
}


- (void)sendGiftAction:(NSString *)giftId
                   num:(NSInteger)num
            completion:(void (^)(BOOL success))aCompletion

{
    [self.customMsgHelper sendCustomMessage:giftId num:num to:_chatroomId messageType:AgoraChatTypeChatRoom customMsgType:customMessageType_gift completion:^(AgoraChatMessage * _Nonnull message, AgoraChatError * _Nonnull error) {
        bool ret = false;
        if (!error) {
            ret = true;
        } else {
            ret = false;
        }
        aCompletion(ret);
    }];
}


#pragma mark - private
- (void)currentViewDataFill:(AgoraChatMessage*)message
{
    if ([self.datasource count] >= 200) {
        [self.datasource removeObjectsInRange:NSMakeRange(0, 190)];
    }
    [self.datasource addObject:message];
    [self.tableView reloadData];
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:[self.datasource count] - 1] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}


#pragma mark getter and setter
- (UITableView*)tableView
{
    if (_tableView == nil) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, CGRectGetHeight(self.bounds) - 48.f) style:UITableViewStylePlain];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.scrollsToTop = NO;
        _tableView.showsVerticalScrollIndicator = NO;
        
        if (self.customOption.tableViewBgColor) {
            _tableView.backgroundColor = self.customOption.tableViewBgColor;
        }
        
    }
    return _tableView;
}

- (NSMutableArray *)datasource {
    if (_datasource == nil) {
        _datasource = NSMutableArray.new;
    }
    return _datasource;
}


- (UIButton*)sendTextButton
{
    if (_sendTextButton == nil) {
        _sendTextButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _sendTextButton.frame = CGRectMake(kDefaultSpace*1.5, 0, kSendTextButtonWitdh, kButtonHeight);
        _sendTextButton.layer.cornerRadius = kSendTextButtonHeight* 0.5;
        _sendTextButton.layer.borderWidth = 1.0;
        _sendTextButton.layer.borderColor = EaseKitTextLabelGrayColor.CGColor;
        _sendTextButton.titleLabel.font = EaseKitNFont(14.0f);
        _sendTextButton.titleLabel.textAlignment = NSTextAlignmentLeft;
        [_sendTextButton setTitle:@"Say Hi to your Fans..." forState:UIControlStateNormal];
        [_sendTextButton setTitleColor:EaseKitTextLabelGrayColor forState:UIControlStateNormal];
        [_sendTextButton addTarget:self action:@selector(sendTextAction) forControlEvents:UIControlEventTouchUpInside];

    }
    return _sendTextButton;
}


- (UIView*)bottomSendMsgView
{
    if (_bottomSendMsgView == nil) {
        _bottomSendMsgView = [[UIView alloc] init];
        _bottomSendMsgView.backgroundColor = EaseKitRGBACOLOR(255, 255, 255, 1);
        _bottomSendMsgView.layer.borderWidth = 1;
        _bottomSendMsgView.layer.borderColor = [UIColor lightGrayColor].CGColor;
        _bottomSendMsgView.hidden = YES;
    }
    return _bottomSendMsgView;
}


- (EaseInputTextView*)textView
{
    if (_textView == nil) {
        _textView = [[EaseInputTextView alloc] init];
        _textView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        _textView.scrollEnabled = YES;
        _textView.returnKeyType = UIReturnKeySend;
        _textView.enablesReturnKeyAutomatically = YES;
        _textView.placeHolder = NSLocalizedString(@"chat.input.placeholder", @"input a new message");
        _textView.delegate = self;
        _textView.backgroundColor = EaseKitRGBACOLOR(236, 236, 236, 1);
        _textView.layer.cornerRadius = 4.0f;
    }
    return _textView;
}

//- (UIButton*)sendButton
//{
//    if (_sendButton == nil) {
//        _sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
//        _sendButton.backgroundColor = [UIColor lightGrayColor];
//        _sendButton.tag = 0;
//        [_sendButton setTitle:@"send" forState:UIControlStateNormal];
//        _sendButton.titleLabel.font = [UIFont systemFontOfSize:14];
//        [_sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
//        _sendButton.layer.cornerRadius = 3;
//        [_sendButton addTarget:self action:@selector(sendMsgAction) forControlEvents:UIControlEventTouchUpInside];
//    }
//    return _sendButton;
//}

- (UIButton *)unreadButton {
    if (_unreadButton == nil) {
        _unreadButton = [[UIButton alloc] init];
        [_unreadButton setBackgroundImage:[UIImage easeUIImageNamed:@"chatroom_unread_bg"] forState:UIControlStateNormal];
        _unreadButton.layer.cornerRadius = kUnreadButtonHeight * 0.5;
        [_unreadButton addTarget:self action:@selector(unreadButtonAction) forControlEvents:UIControlEventTouchUpInside];
        _unreadButton.hidden = YES;
        
        UIImageView *iconImageView = [[UIImageView alloc] init];
        [iconImageView setImage:[UIImage easeUIImageNamed:@"chatroom_unread_arrow"]];
        
        [_unreadButton addSubview:self.unreadLabel];
        [_unreadButton addSubview:iconImageView];
        
        [self.unreadLabel Ease_makeConstraints:^(EaseConstraintMaker *make) {
            make.centerY.equalTo(_unreadButton);
            make.left.equalTo(_unreadButton).offset(10.0);
            make.right.equalTo(iconImageView.ease_left).offset(-5.0);
        }];
        
        [iconImageView Ease_makeConstraints:^(EaseConstraintMaker *make) {
            make.centerY.equalTo(_unreadButton);
            make.right.equalTo(_unreadButton).offset(-10.0);
        }];
    }
    return _unreadButton;
}

- (UILabel *)unreadLabel {
    if (_unreadLabel == nil) {
        _unreadLabel = UILabel.new;
        _unreadLabel.font = EaseKitNFont(12.0f);
        _unreadLabel.textColor = UIColor.whiteColor;
        _unreadLabel.textAlignment = NSTextAlignmentLeft;
        _unreadLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _unreadLabel.text = @"76 New Messages";
    }
    return _unreadLabel;
}



- (void)setIsMuted:(BOOL)isMuted {
    _isMuted = isMuted;
    self.sendTextButton.enabled = !_isMuted;
}


@end

#undef kSendTextButtonWitdh
#undef kSendTextButtonHeight
#undef kButtonHeight
#undef kDefaultSpace
#undef kDefaulfLeftSpace
#undef kTextViewHeight
#undef kUnreadButtonWitdh
#undef kUnreadButtonHeight

