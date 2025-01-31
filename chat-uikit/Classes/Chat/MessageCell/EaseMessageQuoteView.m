//
//  EaseMessageQuoteView.m
//  EaseIMKit
//
//  Created by 冯钊 on 2023/4/26.
//

#import "EaseMessageQuoteView.h"
#import <AgoraChat/AgoraChat.h>
#import "AgoraChatMessage+EaseUIExt.h"
#import "Easeonry.h"
#import "UIImageView+EaseWebCache.h"
#import "UIImage+EaseUI.h"
#import "EaseUserUtils.h"

@interface EaseMessageQuoteView ()

@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImageView *videoImageView;
@property (nonatomic, strong) UILabel *contentLabel;

@end

@implementation EaseMessageQuoteView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor colorWithRed:0.902 green:0.902 blue:0.902 alpha:1];
        self.layer.cornerRadius = 8;
        
        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        _nameLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1];
        [self addSubview:_nameLabel];
        
        _imageView = [[UIImageView alloc] init];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.layer.masksToBounds = YES;
        [self addSubview:_imageView];
        
        _videoImageView = [[UIImageView alloc] init];
        _videoImageView.image = [UIImage easeUIImageNamed:@"msg_video_white"];
        [_imageView addSubview:_videoImageView];
        [_videoImageView Ease_makeConstraints:^(EaseConstraintMaker *make) {
            make.size.equalTo(@20);
            make.center.equalTo(_imageView);
        }];
        
        _contentLabel = [[UILabel alloc] init];
        _contentLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        _contentLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1];
        _contentLabel.numberOfLines = 1;
        _contentLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self addSubview:_contentLabel];
    }
    return self;
}

- (void)setMessage:(AgoraChatMessage *)message
{
    _message = message;
    NSDictionary *quoteInfo = message.ext[@"msgQuote"];
    if (quoteInfo) {
        NSDictionary <NSString *, NSNumber *>*msgTypeDict = @{
            @"txt": @(AgoraChatMessageBodyTypeText),
            @"img": @(AgoraChatMessageBodyTypeImage),
            @"video": @(AgoraChatMessageBodyTypeVideo),
            @"audio": @(AgoraChatMessageBodyTypeVoice),
            @"custom": @(AgoraChatMessageBodyTypeCustom),
            @"cmd": @(AgoraChatMessageBodyTypeCmd),
            @"file": @(AgoraChatMessageBodyTypeFile),
            @"location": @(AgoraChatMessageBodyTypeLocation)
        };
        NSString *quoteMsgId = quoteInfo[@"msgID"];
        AgoraChatMessageBodyType msgBodyType = msgTypeDict[quoteInfo[@"msgType"]].intValue;
        NSString *msgSender = quoteInfo[@"msgSender"];
        NSString *msgPreview = quoteInfo[@"msgPreview"];
        AgoraChatMessage *quoteMessage = [AgoraChatClient.sharedClient.chatManager getMessageWithMessageId:quoteMsgId];
        
        _videoImageView.hidden = YES;
        _nameLabel.hidden = NO;
        _contentLabel.hidden = YES;
        _nameLabel.numberOfLines = 1;
        
        id<EaseUserProfile> userInfo = [EaseUserUtils.shared getUserInfo:msgSender moduleType:quoteMessage.chatType == AgoraChatTypeChat ? EaseUserModuleTypeChat : EaseUserModuleTypeGroupChat];
        NSString *showName = userInfo.showName.length > 0 ? userInfo.showName : quoteMessage.from;
        NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@:", showName] attributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightMedium]
        }]];
        
        if (_delegate && [_delegate respondsToSelector:@selector(quoteViewShowContent:)]) {
            NSAttributedString *content = [_delegate quoteViewShowContent:message];
            if (content) {
                [self setupTextLayout:2];
                [result appendAttributedString:content];
                self.nameLabel.attributedText = result;
                return;
            }
        }
        
        switch (msgBodyType) {
            case AgoraChatMessageBodyTypeImage: {
                [self setupImageLayout];
                [_imageView Ease_setImageWithURL:[NSURL URLWithString:((AgoraChatImageMessageBody *)quoteMessage.body).thumbnailRemotePath] placeholderImage:[UIImage easeUIImageNamed:@"msg_img_broken"]];
                _nameLabel.attributedText = result;
                break;
            }
            case AgoraChatMessageBodyTypeVideo: {
                [self setupImageLayout];
                _videoImageView.hidden = NO;
                if ([quoteMessage.from isEqualToString:AgoraChatClient.sharedClient.currentUsername]) {
                    [_imageView Ease_setImageWithURL:[NSURL fileURLWithPath:((AgoraChatVideoMessageBody *)quoteMessage.body).thumbnailLocalPath] placeholderImage:[UIImage easeUIImageNamed:@"msg_img_broken"]];
                } else {
                    [_imageView Ease_setImageWithURL:[NSURL URLWithString:((AgoraChatVideoMessageBody *)quoteMessage.body).thumbnailRemotePath] placeholderImage:[UIImage easeUIImageNamed:@"msg_img_broken"]];
                }
                _nameLabel.attributedText = result;
                break;
            }
            case AgoraChatMessageBodyTypeFile: {
                [self setupTextImageTextLayout];
                _nameLabel.attributedText = result;
                _contentLabel.text = ((AgoraChatFileMessageBody *)quoteMessage.body).displayName;
                _imageView.image = [UIImage easeUIImageNamed:@"quote_file"];
                break;
            }
            case AgoraChatMessageBodyTypeVoice: {
                [self setupTextImageTextLayout];
                _nameLabel.attributedText = result;
                _contentLabel.text = [NSString stringWithFormat:@"%d”", ((AgoraChatVoiceMessageBody *)quoteMessage.body).duration];
                _imageView.image = [UIImage easeUIImageNamed:@"quote_voice"];
                break;
            }
            case AgoraChatMessageBodyTypeLocation: {
                [self setupTextLayout:2];
                NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
                attachment.image = [UIImage easeUIImageNamed:@"quote_location"];
                attachment.bounds = CGRectMake(0, -4, attachment.image.size.width, attachment.image.size.height);
                [result appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
                [result appendAttributedString:[[NSAttributedString alloc] initWithString:((AgoraChatLocationMessageBody *)quoteMessage.body).address attributes:@{
                    NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightRegular]
                }]];
                _nameLabel.attributedText = result;
                break;
            }
            case AgoraChatMessageBodyTypeText: {
                /*
                if (quoteMessage.ext[@"em_expression_id"]) {
                    [self setupImageLayout];
                    NSString *localeLanguageCode = [NSLocale.currentLocale objectForKey:NSLocaleLanguageCode];;
                    NSString *name = [(AgoraChatTextMessageBody *)quoteMessage.body text];
                    if ([localeLanguageCode isEqualToString:@"zh"] && [name containsString:@"Example"]) {
                        name = [name stringByReplacingOccurrencesOfString:@"Example" withString:@"示例"];
                    }
                    if ([localeLanguageCode isEqualToString:@"en"] && [name containsString:@"示例"]) {
                        name = [name stringByReplacingOccurrencesOfString:@"示例" withString:@"Example"];
                    }
                    EaseEmoticonGroup *group = [EaseEmoticonGroup getGifGroup];
                    for (EaseEmoticonModel *model in group.dataArray) {
                        if ([model.name isEqualToString:name]) {
                            NSString *path = [NSBundle.mainBundle pathForResource:@"EaseIMKit" ofType:@"bundle"];
                            NSString *gifPath = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.gif", model.original]];
                            NSData *imageData = [NSData dataWithContentsOfFile:gifPath];
                            self.imageView.image = [UIImage imageWithData:imageData];
                            break;
                        }
                    }
                    _nameLabel.attributedText = result;
                    break;
                } else {
                 */
                    [self setupTextLayout:2];
                    NSString *showText = quoteMessage.easeUI_quoteShowText;
                    if (showText.length <= 0) {
                        showText = msgPreview;
                    }
                    [result appendAttributedString:[[NSAttributedString alloc] initWithString:showText attributes:@{
                        NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightRegular]
                    }]];
                    _nameLabel.attributedText = result;
//                }
                break;
            }
            default: {
                [self setupTextLayout:2];
                NSString *showText = quoteMessage.easeUI_quoteShowText;
                if (showText.length <= 0) {
                    showText = msgPreview;
                }
                [result appendAttributedString:[[NSAttributedString alloc] initWithString:showText attributes:@{
                    NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightRegular]
                }]];
                _nameLabel.attributedText = result;
                break;
            }
        }
    } else {
        _nameLabel.hidden = YES;
        _imageView.hidden = YES;
        _contentLabel.hidden = YES;
        [_nameLabel Ease_remakeConstraints:^(EaseConstraintMaker *make) {
            make.edges.Ease_equalTo(0);
        }];
        _nameLabel.attributedText = nil;
    }
}

- (void)setupTextLayout:(int)numberOfLines
{
    _imageView.hidden = YES;
    _nameLabel.numberOfLines = numberOfLines;
    _contentLabel.hidden = YES;
    [_nameLabel Ease_remakeConstraints:^(EaseConstraintMaker *make) {
        make.edges.Ease_equalTo(UIEdgeInsetsMake(8, 10, 8, 10));
    }];
    [_imageView Ease_remakeConstraints:^(EaseConstraintMaker *make) {}];
    [_contentLabel Ease_remakeConstraints:^(EaseConstraintMaker *make) {}];
}

- (void)setupImageLayout
{
    _imageView.hidden = NO;
    [_nameLabel Ease_remakeConstraints:^(EaseConstraintMaker *make) {
        make.left.equalTo(@10);
        make.top.equalTo(@8);
    }];
    [_imageView Ease_remakeConstraints:^(EaseConstraintMaker *make) {
        make.size.equalTo(@36);
        make.left.equalTo(_nameLabel.ease_right).offset(4);
        make.top.equalTo(_nameLabel);
        make.right.equalTo(@-10);
        make.bottom.equalTo(@-8);
    }];
    [_contentLabel Ease_remakeConstraints:^(EaseConstraintMaker *make) {}];
}

- (void)setupTextImageTextLayout
{
    _contentLabel.hidden = NO;
    _imageView.hidden = NO;
    [_nameLabel Ease_remakeConstraints:^(EaseConstraintMaker *make) {
        make.left.equalTo(@10);
        make.top.equalTo(@8);
        make.bottom.equalTo(@-10);
    }];
    [_imageView Ease_remakeConstraints:^(EaseConstraintMaker *make) {
        make.size.equalTo(@18);
        make.left.equalTo(_nameLabel.ease_right).offset(4);
        make.centerY.equalTo(_nameLabel);
    }];
    [_contentLabel Ease_remakeConstraints:^(EaseConstraintMaker *make) {
        make.left.equalTo(_imageView.ease_right).offset(4);
        make.right.equalTo(@-10);
        make.centerY.equalTo(_imageView);
    }];
}

@end
