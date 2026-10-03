#import <UIKit/UIKit.h>

@interface LRPost : NSObject

@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *author;
@property(nonatomic, copy) NSString *subreddit;
@property(nonatomic, copy) NSString *permalink;

@end

@implementation LRPost
@end


@interface LRAPI : NSObject

+ (void)fetchFrontPage:(void (^)(NSArray<LRPost *> *posts, NSError *error))completion;

@end


@implementation LRAPI

+ (void)fetchFrontPage:(void (^)(NSArray<LRPost *> *posts, NSError *error))completion
{
    NSURL *url = [NSURL URLWithString:@"https://www.reddit.com/r/all.json?limit=25&raw_json=1"];

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:url];

    [request setHTTPMethod:@"GET"];
    [request setValue:@"LegacyReddit/1.0 iOS12"
   forHTTPHeaderField:@"User-Agent"];

    NSURLSessionDataTask *task =
        [[NSURLSession sharedSession]
            dataTaskWithRequest:request
            completionHandler:^(NSData *data,
                                NSURLResponse *response,
                                NSError *error) {

        if (error != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }

        if (data == nil) {
            NSError *e =
                [NSError errorWithDomain:@"LegacyReddit"
                                    code:1
                                userInfo:@{
                                    NSLocalizedDescriptionKey:
                                        @"Reddit returned no data."
                                }];

            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, e);
            });
            return;
        }

        NSError *jsonError = nil;

        id json =
            [NSJSONSerialization JSONObjectWithData:data
                                            options:0
                                              error:&jsonError];

        if (jsonError != nil ||
            ![json isKindOfClass:[NSDictionary class]]) {

            if (jsonError == nil) {
                jsonError =
                    [NSError errorWithDomain:@"LegacyReddit"
                                        code:2
                                    userInfo:@{
                                        NSLocalizedDescriptionKey:
                                            @"Invalid Reddit JSON response."
                                    }];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, jsonError);
            });

            return;
        }

        NSDictionary *root = (NSDictionary *)json;
        NSDictionary *dataDictionary = root[@"data"];

        if (![dataDictionary isKindOfClass:[NSDictionary class]]) {
            NSError *e =
                [NSError errorWithDomain:@"LegacyReddit"
                                    code:3
                                userInfo:@{
                                    NSLocalizedDescriptionKey:
                                        @"Invalid Reddit response."
                                }];

            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, e);
            });

            return;
        }

        NSArray *children = dataDictionary[@"children"];

        if (![children isKindOfClass:[NSArray class]]) {
            NSError *e =
                [NSError errorWithDomain:@"LegacyReddit"
                                    code:4
                                userInfo:@{
                                    NSLocalizedDescriptionKey:
                                        @"Reddit returned no posts."
                                }];

            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, e);
            });

            return;
        }

        NSMutableArray *posts =
            [NSMutableArray array];

        for (id child in children) {

            if (![child isKindOfClass:[NSDictionary class]]) {
                continue;
            }

            NSDictionary *childDictionary =
                (NSDictionary *)child;

            NSDictionary *postData =
                childDictionary[@"data"];

            if (![postData isKindOfClass:[NSDictionary class]]) {
                continue;
            }

            LRPost *post =
                [[LRPost alloc] init];

            NSString *title =
                postData[@"title"];

            NSString *author =
                postData[@"author"];

            NSString *subreddit =
                postData[@"subreddit_name_prefixed"];

            NSString *permalink =
                postData[@"permalink"];

            post.title =
                [title isKindOfClass:[NSString class]]
                    ? title
                    : @"";

            post.author =
                [author isKindOfClass:[NSString class]]
                    ? author
                    : @"[deleted]";

            post.subreddit =
                [subreddit isKindOfClass:[NSString class]]
                    ? subreddit
                    : @"";

            post.permalink =
                [permalink isKindOfClass:[NSString class]]
                    ? permalink
                    : @"";

            [posts addObject:post];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(posts, nil);
        });
    }];

    [task resume];
}

@end


@interface LRTableController : UITableViewController

@property(nonatomic, strong) NSArray<LRPost *> *posts;

@end


@implementation LRTableController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Reddit";

    UIRefreshControl *refresh =
        [[UIRefreshControl alloc] init];

    self.refreshControl = refresh;

    [refresh addTarget:self
                action:@selector(refresh:)
      forControlEvents:UIControlEventValueChanged];

    [self refresh:nil];
}


- (void)refresh:(id)sender
{
    [LRAPI fetchFrontPage:^(NSArray<LRPost *> *posts,
                            NSError *error) {

        if (posts != nil) {
            self.posts = posts;
            [self.tableView reloadData];
        }

        [self.refreshControl endRefreshing];

        if (error != nil) {

            UIAlertController *alert =
                [UIAlertController
                    alertControllerWithTitle:@"Reddit"
                                      message:error.localizedDescription
                               preferredStyle:UIAlertControllerStyleAlert];

            [alert addAction:
                [UIAlertAction
                    actionWithTitle:@"OK"
                              style:UIAlertActionStyleDefault
                            handler:nil]];

            [self presentViewController:alert
                               animated:YES
                             completion:nil];
        }
    }];
}


- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return self.posts.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"RedditPost";

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:identifier];

    if (cell == nil) {

        cell =
            [[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleSubtitle
              reuseIdentifier:identifier];

        cell.textLabel.numberOfLines = 3;
        cell.detailTextLabel.numberOfLines = 2;
        cell.accessoryType =
            UITableViewCellAccessoryDisclosureIndicator;
    }

    LRPost *post =
        self.posts[indexPath.row];

    cell.textLabel.text =
        post.title;

    if (post.subreddit.length > 0 &&
        post.author.length > 0) {

        cell.detailTextLabel.text =
            [NSString stringWithFormat:@"%@ • %@",
                post.subreddit,
                post.author];

    } else if (post.subreddit.length > 0) {

        cell.detailTextLabel.text =
            post.subreddit;

    } else {

        cell.detailTextLabel.text =
            post.author;
    }

    return cell;
}


- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    LRPost *post =
        self.posts[indexPath.row];

    if (post.permalink.length > 0) {

        NSString *urlString =
            [NSString stringWithFormat:
                @"https://www.reddit.com%@",
                post.permalink];

        NSURL *url =
            [NSURL URLWithString:urlString];

        if (url != nil) {

            [[UIApplication sharedApplication]
                openURL:url
                options:@{}
                completionHandler:nil];
        }
    }

    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
}

@end


@interface LRAppDelegate : UIResponder <UIApplicationDelegate>

@property(nonatomic, strong) UIWindow *window;

@end


@implementation LRAppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window =
        [[UIWindow alloc]
            initWithFrame:[UIScreen mainScreen].bounds];

    LRTableController *controller =
        [[LRTableController alloc] init];

    UINavigationController *navigation =
        [[UINavigationController alloc]
            initWithRootViewController:controller];

    self.window.rootViewController =
        navigation;

    [self.window makeKeyAndVisible];

    return YES;
}

@end


int main(int argc, char *argv[])
{
    @autoreleasepool {

        return UIApplicationMain(
            argc,
            argv,
            nil,
            NSStringFromClass([LRAppDelegate class])
        );
    }
}
