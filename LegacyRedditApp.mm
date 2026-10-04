#import "LegacyRedditApp.h"

#import <UIKit/UIKit.h>
#import <SafariServices/SafariServices.h>

#pragma mark - Configuration

static NSString * const LRRedditClientID = @"REDDIT_CLIENT_ID";
static NSString * const LRRedditRedirectURI = @"legacyreddit://oauth";
static NSString * const LRRedditUserAgent =
    @"LegacyReddit/1.0 by LegacyReddit";

#pragma mark - Helpers

static NSString *LRString(id value)
{
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }

    if ([value respondsToSelector:@selector(stringValue)]) {
        return [value stringValue];
    }

    return @"";
}

static NSInteger LRInteger(id value)
{
    if ([value respondsToSelector:@selector(integerValue)]) {
        return [value integerValue];
    }

    return 0;
}

static NSString *LRURLString(id value)
{
    NSString *string = LRString(value);

    if (string.length == 0) {
        return @"";
    }

    return string;
}

static NSString *LREscapeHTML(NSString *text)
{
    if (!text) {
        return @"";
    }

    NSMutableString *result =
        [text mutableCopy];

    [result replaceOccurrencesOfString:@"&amp;"
                             withString:@"&"
                                options:0
                                  range:NSMakeRange(0, result.length)];

    [result replaceOccurrencesOfString:@"&lt;"
                             withString:@"<"
                                options:0
                                  range:NSMakeRange(0, result.length)];

    [result replaceOccurrencesOfString:@"&gt;"
                             withString:@">"
                                options:0
                                  range:NSMakeRange(0, result.length)];

    [result replaceOccurrencesOfString:@"&quot;"
                             withString:@"\""
                                options:0
                                  range:NSMakeRange(0, result.length)];

    [result replaceOccurrencesOfString:@"&#39;"
                             withString:@"'"
                                options:0
                                  range:NSMakeRange(0, result.length)];

    return result;
}

#pragma mark - Reddit Network

@interface LRNetwork : NSObject
+ (void)getJSON:(NSString *)path
         token:(NSString *)token
     completion:(void (^)(id json, NSInteger status, NSError *error))completion;

+ (void)postForm:(NSString *)path
           token:(NSString *)token
            body:(NSDictionary *)body
       completion:(void (^)(id json, NSInteger status, NSError *error))completion;
@end

@implementation LRNetwork

+ (NSURL *)URLForPath:(NSString *)path
{
    NSString *base = @"https://oauth.reddit.com";

    if ([path hasPrefix:@"http://"] ||
        [path hasPrefix:@"https://"]) {
        return [NSURL URLWithString:path];
    }

    return [NSURL URLWithString:
        [NSString stringWithFormat:@"%@%@",
         base,
         path]];
}

+ (NSMutableURLRequest *)requestForPath:(NSString *)path
                                 method:(NSString *)method
                                 token:(NSString *)token
{
    NSURL *url = [self URLForPath:path];

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:url];

    request.HTTPMethod = method;

    [request setValue:LRRedditUserAgent
        forHTTPHeaderField:@"User-Agent"];

    [request setValue:@"application/json"
        forHTTPHeaderField:@"Accept"];

    if (token.length > 0) {
        [request setValue:
            [NSString stringWithFormat:@"Bearer %@", token]
            forHTTPHeaderField:@"Authorization"];
    }

    return request;
}

+ (void)getJSON:(NSString *)path
         token:(NSString *)token
     completion:(void (^)(id json, NSInteger status, NSError *error))completion
{
    NSMutableURLRequest *request =
        [self requestForPath:path
                      method:@"GET"
                      token:token];

    NSURLSessionDataTask *task =
        [[NSURLSession sharedSession]
            dataTaskWithRequest:request
            completionHandler:
        ^(NSData *data,
          NSURLResponse *response,
          NSError *error)
    {
        NSInteger status = 0;

        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            status =
                [(NSHTTPURLResponse *)response statusCode];
        }

        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, status, error);
            });

            return;
        }

        NSError *jsonError = nil;

        id json =
            [NSJSONSerialization
                JSONObjectWithData:data
                options:0
                error:&jsonError];

        if (jsonError) {
            NSString *body =
                [[NSString alloc]
                    initWithData:data
                    encoding:NSUTF8StringEncoding];

            NSDictionary *info = @{
                NSLocalizedDescriptionKey:
                    body.length > 0
                    ? body
                    : @"Reddit returned an invalid response."
            };

            NSError *responseError =
                [NSError errorWithDomain:@"LegacyReddit"
                                    code:status
                                userInfo:info];

            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, status, responseError);
            });

            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(json, status, nil);
        });
    }];

    [task resume];
}

+ (void)postForm:(NSString *)path
           token:(NSString *)token
            body:(NSDictionary *)body
       completion:(void (^)(id json, NSInteger status, NSError *error))completion
{
    NSMutableURLRequest *request =
        [self requestForPath:path
                      method:@"POST"
                      token:token];

    [request setValue:
        @"application/x-www-form-urlencoded"
        forHTTPHeaderField:@"Content-Type"];

    NSMutableArray *parts =
        [NSMutableArray array];

    for (NSString *key in body) {
        NSString *value =
            LRString(body[key]);

        NSString *escapedKey =
            [self formEscape:key];

        NSString *escapedValue =
            [self formEscape:value];

        [parts addObject:
            [NSString stringWithFormat:@"%@=%@",
             escapedKey,
             escapedValue]];
    }

    NSString *form =
        [parts componentsJoinedByString:@"&"];

    request.HTTPBody =
        [form dataUsingEncoding:NSUTF8StringEncoding];

    NSURLSessionDataTask *task =
        [[NSURLSession sharedSession]
            dataTaskWithRequest:request
            completionHandler:
        ^(NSData *data,
          NSURLResponse *response,
          NSError *error)
    {
        NSInteger status = 0;

        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            status =
                [(NSHTTPURLResponse *)response statusCode];
        }

        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, status, error);
            });

            return;
        }

        NSError *jsonError = nil;

        id json =
            [NSJSONSerialization
                JSONObjectWithData:data
                options:0
                error:&jsonError];

        if (jsonError) {
            NSString *text =
                [[NSString alloc]
                    initWithData:data
                    encoding:NSUTF8StringEncoding];

            NSDictionary *info = @{
                NSLocalizedDescriptionKey:
                    text.length > 0
                    ? text
                    : @"Reddit returned an invalid response."
            };

            NSError *responseError =
                [NSError errorWithDomain:@"LegacyReddit"
                                    code:status
                                userInfo:info];

            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, status, responseError);
            });

            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(json, status, nil);
        });
    }];

    [task resume];
}

+ (NSString *)formEscape:(NSString *)value
{
    NSCharacterSet *allowed =
        [NSCharacterSet
            characterSetWithCharactersInString:
                @"abcdefghijklmnopqrstuvwxyz"
                "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                "0123456789-._* "];

    NSString *escaped =
        [value
            stringByAddingPercentEncodingWithAllowedCharacters:
                allowed];

    return [escaped
        stringByReplacingOccurrencesOfString:@" "
                                  withString:@"+"
                                     options:0
                                       range:NSMakeRange(0, escaped.length)];
}

@end

#pragma mark - OAuth

@interface LROAuthViewController : SFSafariViewController
@end

@implementation LROAuthViewController
@end

#pragma mark - Models

@interface LRPost : NSObject

@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *author;
@property(nonatomic, copy) NSString *subreddit;
@property(nonatomic, copy) NSString *selfText;
@property(nonatomic, copy) NSString *url;
@property(nonatomic, copy) NSString *permalink;
@property(nonatomic, copy) NSString *thumbnail;
@property(nonatomic, copy) NSString *created;
@property(nonatomic, assign) NSInteger score;
@property(nonatomic, assign) NSInteger comments;
@property(nonatomic, assign) BOOL isSelf;

@end

@implementation LRPost
@end

@interface LRComment : NSObject

@property(nonatomic, copy) NSString *author;
@property(nonatomic, copy) NSString *body;
@property(nonatomic, assign) NSInteger score;
@property(nonatomic, strong) NSArray *replies;

@end

@implementation LRComment
@end

#pragma mark - Image Viewer

@interface LRImageViewController : UIViewController

@property(nonatomic, copy) NSString *imageURL;
@property(nonatomic, strong) UIImageView *imageView;

@end

@implementation LRImageViewController

- (instancetype)initWithURL:(NSString *)url
{
    self = [super init];

    if (self) {
        _imageURL = [url copy];
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor =
        [UIColor blackColor];

    self.title = @"Image";

    self.imageView =
        [[UIImageView alloc] initWithFrame:self.view.bounds];

    self.imageView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    self.imageView.contentMode =
        UIViewContentModeScaleAspectFit;

    [self.view addSubview:self.imageView];

    NSURL *url =
        [NSURL URLWithString:self.imageURL];

    if (!url) {
        return;
    }

    NSURLSessionDataTask *task =
        [[NSURLSession sharedSession]
            dataTaskWithURL:url
            completionHandler:
        ^(NSData *data,
          NSURLResponse *response,
          NSError *error)
    {
        if (error || !data) {
            return;
        }

        UIImage *image =
            [UIImage imageWithData:data];

        if (!image) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageView.image = image;
        });
    }];

    [task resume];
}

@end

#pragma mark - Comments

@interface LRCommentsViewController : UITableViewController

@property(nonatomic, strong) NSArray *comments;

@end

@implementation LRCommentsViewController

- (instancetype)initWithComments:(NSArray *)comments
{
    self = [super initWithStyle:UITableViewStylePlain];

    if (self) {
        _comments = comments;
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Comments";

    self.tableView.rowHeight =
        UITableViewAutomaticDimension;

    self.tableView.estimatedRowHeight = 80.0;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return self.comments.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier =
        @"CommentCell";

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:
            identifier];

    if (!cell) {
        cell =
            [[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:identifier];

        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.numberOfLines = 1;
    }

    LRComment *comment =
        self.comments[indexPath.row];

    cell.textLabel.text =
        comment.body.length > 0
        ? comment.body
        : @"[deleted]";

    if (comment.author.length > 0) {
        cell.detailTextLabel.text =
            [NSString stringWithFormat:
                @"u/%@  •  %ld",
                comment.author,
                (long)comment.score];
    } else {
        cell.detailTextLabel.text =
            [NSString stringWithFormat:
                @"deleted  •  %ld",
                (long)comment.score];
    }

    return cell;
}

@end

#pragma mark - Post Detail

@interface LRPostViewController : UITableViewController

@property(nonatomic, strong) LRPost *post;
@property(nonatomic, strong) NSArray *comments;

@end

@implementation LRPostViewController

- (instancetype)initWithPost:(LRPost *)post
{
    self =
        [super initWithStyle:UITableViewStyleGrouped];

    if (self) {
        _post = post;
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Post";

    self.tableView.rowHeight =
        UITableViewAutomaticDimension;

    self.tableView.estimatedRowHeight = 80.0;

    UIBarButtonItem *open =
        [[UIBarButtonItem alloc]
            initWithTitle:@"Open"
            style:UIBarButtonItemStylePlain
            target:self
            action:@selector(openPost)];

    self.navigationItem.rightBarButtonItem = open;

    [self loadComments];
}

- (void)openPost
{
    if (self.post.url.length == 0) {
        return;
    }

    NSURL *url =
        [NSURL URLWithString:self.post.url];

    if (!url) {
        return;
    }

    SFSafariViewController *browser =
        [[SFSafariViewController alloc]
            initWithURL:url];

    [self presentViewController:browser
                       animated:YES
                     completion:nil];
}

- (void)loadComments
{
    if (self.post.name.length == 0) {
        return;
    }

    NSString *path =
        [NSString stringWithFormat:
            @"/comments/%@.json?raw_json=1&limit=100",
            [self.post.name
                stringByReplacingOccurrencesOfString:@"t3_"
                                          withString:@""]];

    NSString *token =
        [[NSUserDefaults standardUserDefaults]
            stringForKey:@"LRAccessToken"];

    [LRNetwork getJSON:path
                 token:token
             completion:
    ^(id json,
      NSInteger status,
      NSError *error)
    {
        if (error || ![json isKindOfClass:[NSArray class]]) {
            return;
        }

        if (json.count < 2) {
            return;
        }

        NSDictionary *commentsListing =
            json[1];

        NSDictionary *data =
            commentsListing[@"data"];

        NSArray *children =
            data[@"children"];

        NSMutableArray *result =
            [NSMutableArray array];

        for (NSDictionary *child in children) {
            NSDictionary *childData =
                child[@"data"];

            if (![childData isKindOfClass:[NSDictionary class]]) {
                continue;
            }

            NSString *body =
                LRString(childData[@"body"]);

            if (body.length == 0) {
                continue;
            }

            LRComment *comment =
                [[LRComment alloc] init];

            comment.author =
                LRString(childData[@"author"]);

            comment.body = body;

            comment.score =
                LRInteger(childData[@"score"]);

            [result addObject:comment];
        }

        self.comments = result;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }];
}

- (NSInteger)numberOfSectionsInTableView:
    (UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 1;
    }

    return self.comments.count;
}

- (UITableViewCell *)tableView:
    (UITableView *)tableView
    cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {

        UITableViewCell *cell =
            [[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:nil];

        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.numberOfLines = 0;

        NSMutableString *text =
            [NSMutableString string];

        if (self.post.title.length > 0) {
            [text appendString:self.post.title];
        }

        if (self.post.selfText.length > 0) {
            [text appendString:@"\n\n"];
            [text appendString:self.post.selfText];
        }

        cell.textLabel.text = text;

        cell.detailTextLabel.text =
            [NSString stringWithFormat:
                @"u/%@  •  r/%@  •  %ld points  •  %ld comments",
                self.post.author,
                self.post.subreddit,
                (long)self.post.score,
                (long)self.post.comments];

        return cell;
    }

    static NSString *identifier =
        @"PostComment";

    UITableViewCell *cell =
        [tableView
            dequeueReusableCellWithIdentifier:identifier];

    if (!cell) {
        cell =
            [[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:identifier];

        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.numberOfLines = 1;
    }

    LRComment *comment =
        self.comments[indexPath.row];

    cell.textLabel.text =
        comment.body;

    cell.detailTextLabel.text =
        [NSString stringWithFormat:
            @"u/%@  •  %ld",
            comment.author,
            (long)comment.score];

    return cell;
}

@end

#pragma mark - New Post

@interface LRNewPostViewController : UIViewController

@property(nonatomic, copy) NSString *subreddit;
@property(nonatomic, strong) UITextField *titleField;
@property(nonatomic, strong) UITextView *bodyView;

@end

@implementation LRNewPostViewController

- (instancetype)initWithSubreddit:(NSString *)subreddit
{
    self = [super init];

    if (self) {
        _subreddit = [subreddit copy];
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"New Text Post";

    self.view.backgroundColor =
        [UIColor systemBackgroundColor];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:
                UIBarButtonSystemItemCancel
            target:self
            action:@selector(cancel)];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:
                UIBarButtonSystemItemSave
            target:self
            action:@selector(submit)];

    UILabel *subredditLabel =
        [[UILabel alloc]
            initWithFrame:CGRectZero];

    subredditLabel.translatesAutoresizingMaskIntoConstraints = NO;

    subredditLabel.text =
        [NSString stringWithFormat:
            @"Posting to r/%@",
            self.subreddit];

    [self.view addSubview:subredditLabel];

    self.titleField =
        [[UITextField alloc]
            initWithFrame:CGRectZero];

    self.titleField.translatesAutoresizingMaskIntoConstraints = NO;

    self.titleField.borderStyle =
        UITextBorderStyleRoundedRect;

    self.titleField.placeholder =
        @"Post title";

    [self.view addSubview:self.titleField];

    self.bodyView =
        [[UITextView alloc]
            initWithFrame:CGRectZero];

    self.bodyView.translatesAutoresizingMaskIntoConstraints = NO;

    self.bodyView.layer.borderWidth = 1.0;
    self.bodyView.layer.cornerRadius = 8.0;
    self.bodyView.layer.borderColor =
        [UIColor lightGrayColor].CGColor;

    self.bodyView.font =
        [UIFont systemFontOfSize:16.0];

    [self.view addSubview:self.bodyView];

    [NSLayoutConstraint activateConstraints:@[
        [subredditLabel.topAnchor
            constraintEqualToAnchor:
                self.view.safeAreaLayoutGuide.topAnchor
            constant:20.0],

        [subredditLabel.leadingAnchor
            constraintEqualToAnchor:
                self.view.leadingAnchor
            constant:16.0],

        [subredditLabel.trailingAnchor
            constraintEqualToAnchor:
                self.view.trailingAnchor
            constant:-16.0],

        [self.titleField.topAnchor
            constraintEqualToAnchor:
                subredditLabel.bottomAnchor
            constant:15.0],

        [self.titleField.leadingAnchor
            constraintEqualToAnchor:
                self.view.leadingAnchor
            constant:16.0],

        [self.titleField.trailingAnchor
            constraintEqualToAnchor:
                self.view.trailingAnchor
            constant:-16.0],

        [self.titleField.heightAnchor
            constraintEqualToConstant:44.0],

        [self.bodyView.topAnchor
            constraintEqualToAnchor:
                self.titleField.bottomAnchor
            constant:15.0],

        [self.bodyView.leadingAnchor
            constraintEqualToAnchor:
                self.view.leadingAnchor
            constant:16.0],

        [self.bodyView.trailingAnchor
            constraintEqualToAnchor:
                self.view.trailingAnchor
            constant:-16.0],

        [self.bodyView.bottomAnchor
            constraintEqualToAnchor:
                self.view.safeAreaLayoutGuide.bottomAnchor
            constant:-16.0]
    ]];
}

- (void)cancel
{
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

- (void)submit
{
    NSString *title =
        [self.titleField.text
            stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSString *body =
        self.bodyView.text ?: @"";

    if (title.length == 0) {
        UIAlertView *alert =
            [[UIAlertView alloc]
                initWithTitle:@"Missing title"
                message:@"Enter a title."
                delegate:nil
                cancelButtonTitle:@"OK"
                otherButtonTitles:nil];

        [alert show];
        return;
    }

    NSString *token =
        [[NSUserDefaults standardUserDefaults]
            stringForKey:@"LRAccessToken"];

    if (token.length == 0) {
        [self showLoginRequired];
        return;
    }

    NSDictionary *form = @{
        @"api_type": @"json",
        @"kind": @"self",
        @"sr": self.subreddit ?: @"",
        @"title": title,
        @"text": body,
        @"resubmit": @"true",
        @"sendreplies": @"true"
    };

    [LRNetwork postForm:@"/api/submit"
                  token:token
                   body:form
              completion:
    ^(id json,
      NSInteger status,
      NSError *error)
    {
        if (error) {
            [self showError:error];
            return;
        }

        NSDictionary *dict =
            [json isKindOfClass:[NSDictionary class]]
            ? json
            : nil;

        NSArray *errors =
            dict[@"json"][@"errors"];

        if (errors.count > 0) {
            NSString *message =
                [NSString stringWithFormat:
                    @"Reddit rejected the post:\n%@",
                    errors.firstObject];

            UIAlertView *alert =
                [[UIAlertView alloc]
                    initWithTitle:@"Post failed"
                    message:message
                    delegate:nil
                    cancelButtonTitle:@"OK"
                    otherButtonTitles:nil];

            [alert show];

            return;
        }

        [self dismissViewControllerAnimated:YES
                                 completion:nil];
    }];
}

- (void)showLoginRequired
{
    UIAlertView *alert =
        [[UIAlertView alloc]
            initWithTitle:@"Reddit Login Required"
            message:@"Log into Reddit before creating a post."
            delegate:nil
            cancelButtonTitle:@"OK"
            otherButtonTitles:nil];

    [alert show];
}

- (void)showError:(NSError *)error
{
    UIAlertView *alert =
        [[UIAlertView alloc]
            initWithTitle:@"Reddit Error"
            message:error.localizedDescription
            delegate:nil
            cancelButtonTitle:@"OK"
            otherButtonTitles:nil];

    [alert show];
}

@end

#pragma mark - Main Controller

@interface LDRedditMainViewController ()

@property(nonatomic, strong) NSMutableArray *posts;
@property(nonatomic, copy) NSString *subreddit;
@property(nonatomic, copy) NSString *accessToken;
@property(nonatomic, copy) NSString *refreshToken;

@end

@implementation LDRedditMainViewController

- (instancetype)init
{
    self =
        [super initWithStyle:UITableViewStylePlain];

    if (self) {
        _posts =
            [NSMutableArray array];

        _subreddit =
            @"popular";
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"LegacyReddit";

    self.tableView.rowHeight =
        UITableViewAutomaticDimension;

    self.tableView.estimatedRowHeight = 100.0;

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc]
            initWithTitle:@"Subreddit"
            style:UIBarButtonItemStylePlain
            target:self
            action:@selector(changeSubreddit)];

    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:
                UIBarButtonSystemItemRefresh
            target:self
            action:@selector(loadPosts)],

        [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:
                UIBarButtonSystemItemAdd
            target:self
            action:@selector(newPost)]
    ];

    self.refreshControl =
        [[UIRefreshControl alloc] init];

    [self.refreshControl
        addTarget:self
        action:@selector(loadPosts)
        forControlEvents:UIControlEventValueChanged];

    self.accessToken =
        [[NSUserDefaults standardUserDefaults]
            stringForKey:@"LRAccessToken"];

    self.refreshToken =
        [[NSUserDefaults standardUserDefaults]
            stringForKey:@"LRRefreshToken"];

    [self loadPosts];
}

#pragma mark Login

- (void)login
{
    if (LRRedditClientID.length == 0 ||
        [LRRedditClientID
            isEqualToString:@"REDDIT_CLIENT_ID"]) {

        UIAlertView *alert =
            [[UIAlertView alloc]
                initWithTitle:@"Reddit API Setup Required"
                message:@"Add your approved Reddit client ID before logging in."
                delegate:nil
                cancelButtonTitle:@"OK"
                otherButtonTitles:nil];

        [alert show];

        return;
    }

    NSString *state =
        [[NSUUID UUID] UUIDString];

    [[NSUserDefaults standardUserDefaults]
        setObject:state
        forKey:@"LROAuthState"];

    NSString *scope =
        @"identity read submit vote comment";

    NSString *query =
        [NSString stringWithFormat:
            @"client_id=%@&response_type=code&state=%@&"
             "redirect_uri=%@&duration=permanent&scope=%@",
            [self urlEscape:LRRedditClientID],
            [self urlEscape:state],
            [self urlEscape:LRRedditRedirectURI],
            [self urlEscape:scope]];

    NSString *urlString =
        [NSString stringWithFormat:
            @"https://www.reddit.com/api/v1/authorize?%@",
            query];

    NSURL *url =
        [NSURL URLWithString:urlString];

    if (!url) {
        return;
    }

    SFSafariViewController *browser =
        [[SFSafariViewController alloc]
            initWithURL:url];

    [self presentViewController:browser
                       animated:YES
                     completion:nil];
}

- (NSString *)urlEscape:(NSString *)value
{
    NSCharacterSet *allowed =
        [NSCharacterSet
            characterSetWithCharactersInString:
                @"abcdefghijklmnopqrstuvwxyz"
                "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                "0123456789-._~"];

    return
        [value
            stringByAddingPercentEncodingWithAllowedCharacters:
                allowed];
}

#pragma mark Subreddit

- (void)changeSubreddit
{
    UIAlertView *alert =
        [[UIAlertView alloc]
            initWithTitle:@"Subreddit"
            message:@"Enter a subreddit name."
            delegate:self
            cancelButtonTitle:@"Cancel"
            otherButtonTitles:@"Open", nil];

    alert.alertViewStyle =
        UIAlertViewStylePlainTextInput;

    UITextField *field =
        [alert textFieldAtIndex:0];

    field.text = self.subreddit;
    field.placeholder = @"example: iphone";

    [alert show];
}

- (void)alertView:(UIAlertView *)alertView
clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != 1) {
        return;
    }

    UITextField *field =
        [alertView textFieldAtIndex:0];

    NSString *name =
        [field.text
            stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (name.length == 0) {
        return;
    }

    if ([name hasPrefix:@"r/"]) {
        name =
            [name substringFromIndex:2];
    }

    self.subreddit = name;

    self.title =
        [NSString stringWithFormat:
            @"r/%@",
            self.subreddit];

    [self loadPosts];
}

#pragma mark Posts

- (void)loadPosts
{
    [self.refreshControl beginRefreshing];

    NSString *path =
        [NSString stringWithFormat:
            @"/r/%@/hot.json?limit=25&raw_json=1",
            self.subreddit];

    NSString *token =
        self.accessToken ?: @"";

    [LRNetwork getJSON:path
                 token:token
             completion:
    ^(id json,
      NSInteger status,
      NSError *error)
    {
        [self.refreshControl endRefreshing];

        if (error) {
            [self showNetworkError:error
                             status:status];
            return;
        }

        if (![json isKindOfClass:[NSDictionary class]]) {
            return;
        }

        NSDictionary *data =
            json[@"data"];

        NSArray *children =
            data[@"children"];

        if (![children isKindOfClass:[NSArray class]]) {
            return;
        }

        NSMutableArray *newPosts =
            [NSMutableArray array];

        for (NSDictionary *child in children) {

            NSDictionary *postData =
                child[@"data"];

            if (![postData isKindOfClass:[NSDictionary class]]) {
                continue;
            }

            LRPost *post =
                [[LRPost alloc] init];

            post.name =
                LRString(postData[@"name"]);

            post.title =
                LRString(postData[@"title"]);

            post.author =
                LRString(postData[@"author"]);

            post.subreddit =
                LRString(postData[@"subreddit"]);

            post.selfText =
                LRString(postData[@"selftext"]);

            post.url =
                LRURLString(postData[@"url"]);

            post.permalink =
                LRURLString(postData[@"permalink"]);

            post.thumbnail =
                LRURLString(postData[@"thumbnail"]);

            post.score =
                LRInteger(postData[@"score"]);

            post.comments =
                LRInteger(postData[@"num_comments"]);

            post.isSelf =
                [postData[@"is_self"] boolValue];

            [newPosts addObject:post];
        }

        self.posts =
            newPosts;

        [self.tableView reloadData];
    }];
}

- (void)showNetworkError:(NSError *)error
                  status:(NSInteger)status
{
    NSString *message =
        error.localizedDescription ?: @"Unknown error.";

    if (status > 0) {
        message =
            [NSString stringWithFormat:
                @"HTTP %ld\n\n%@",
                (long)status,
                message];
    }

    UIAlertView *alert =
        [[UIAlertView alloc]
            initWithTitle:@"Reddit Error"
            message:message
            delegate:nil
            cancelButtonTitle:@"OK"
            otherButtonTitles:nil];

    [alert show];
}

#pragma mark New Post

- (void)newPost
{
    if (self.accessToken.length == 0) {
        [self login];
        return;
    }

    LRNewPostViewController *controller =
        [[LRNewPostViewController alloc]
            initWithSubreddit:self.subreddit];

    UINavigationController *navigationController =
        [[UINavigationController alloc]
            initWithRootViewController:controller];

    [self presentViewController:navigationController
                       animated:YES
                     completion:nil];
}

#pragma mark Table

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return self.posts.count;
}

- (UITableViewCell *)tableView:
    (UITableView *)tableView
    cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier =
        @"PostCell";

    UITableViewCell *cell =
        [tableView
            dequeueReusableCellWithIdentifier:identifier];

    if (!cell) {
        cell =
            [[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:identifier];

        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.numberOfLines = 2;
        cell.accessoryType =
            UITableViewCellAccessoryDisclosureIndicator;
    }

    LRPost *post =
        self.posts[indexPath.row];

    cell.textLabel.text =
        post.title;

    cell.detailTextLabel.text =
        [NSString stringWithFormat:
            @"u/%@  •  %ld points  •  %ld comments",
            post.author.length > 0
                ? post.author
                : @"[deleted]",
            (long)post.score,
            (long)post.comments];

    return cell;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];

    LRPost *post =
        self.posts[indexPath.row];

    LRPostViewController *controller =
        [[LRPostViewController alloc]
            initWithPost:post];

    [self.navigationController
        pushViewController:controller
        animated:YES];
}

@end
