```objc
#import <UIKit/UIKit.h>

#pragma mark - Post Model

@interface LRPost : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *subreddit;
@property (nonatomic, copy) NSString *permalink;

@end

@implementation LRPost
@end

#pragma mark - Reddit API

@interface LRAPI : NSObject

+ (void)fetchFrontPage:(void (^)(NSArray<LRPost *> *posts, NSError *error))completion;

@end

@implementation LRAPI

+ (void)fetchFrontPage:(void (^)(NSArray<LRPost *> *, NSError *))completion
{
    NSURL *url = [NSURL URLWithString:
                  @"https://www.reddit.com/r/all.json?limit=25&raw_json=1"];

    if (url == nil) {
        NSError *error = [NSError errorWithDomain:@"LegacyReddit"
                                             code:1
                                         userInfo:@{
                                             NSLocalizedDescriptionKey:
                                                 @"Could not create Reddit URL."
                                         }];

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, error);
        });

        return;
    }

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
            NSError *dataError =
                [NSError errorWithDomain:@"LegacyReddit"
                                     code:2
                                 userInfo:@{
                                     NSLocalizedDescriptionKey:
                                         @"Reddit returned no data."
                                 }];

            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, dataError);
            });

            return;
        }

        NSError *jsonError = nil;

        id json =
            [NSJSONSerialization JSONObjectWithData:data
                                            options:0
                                              error:&jsonError];

        if (jsonError != nil || ![json isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, jsonError);
            });

            return;
        }

        NSDictionary *jsonDictionary = (NSDictionary *)json;
        NSDictionary *dataDictionary = jsonDictionary[@"data"];

        if (![dataDictionary isKindOfClass:[NSDictionary class]]) {
            NSError *formatError =
                [NSError errorWithDomain:@"LegacyReddit"
                                     code:3
                                 userInfo:@{
                                     NSLocalizedDescriptionKey:
                                         @"Invalid Reddit response."
                                 }];

            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, formatError);
            });

            return;
        }

        NSArray *children = dataDictionary[@"children"];

        if (![children isKindOfClass:[NSArray class]]) {
            NSError *formatError =
                [NSError errorWithDomain:@"LegacyReddit"
                                     code:4
                                 userInfo:@{
                                     NSLocalizedDescriptionKey:
                                         @"Reddit returned an invalid post list."
                                 }];

            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, formatError);
            });

            return;
        }

        NSMutableArray<LRPost *> *posts =
            [NSMutableArray array];

        for (id childObject in children) {

            if (![childObject isKindOfClass:[NSDictionary class]]) {
                continue;
            }

            NSDictionary *child =
                (NSDictionary *)childObject;

            NSDictionary *postData =
                child[@"data"];

            if (![postData isKindOfClass:[NSDictionary class]]) {
                continue;
            }

            LRPost *post = [[LRPost alloc] init];

            id title = postData[@"title"];
            id author = postData[@"author"];
            id subreddit = postData[@"subreddit_name_prefixed"];
            id permalink = postData[@"permalink"];

            if ([title isKindOfClass:[NSString class]]) {
                post.title = title;
            } else {
                post.title = @"";
            }

            if ([author isKindOfClass:[NSString class]]) {
                post.author = author;
            } else {
                post.author = @"[deleted]";
            }

            if ([subreddit isKindOfClass:[NSString class]]) {
                post.subreddit = subreddit;
            } else {
                post.subreddit = @"";
            }

            if ([permalink isKindOfClass:[NSString class]]) {
                post.permalink = permalink;
            } else {
                post.permalink = @"";
            }

            [posts addObject:post];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(posts, nil);
        });
    }];

    [task resume];
}

@end

#pragma mark - Reddit Table Controller

@interface LRTableController : UITableViewController

@property (nonatomic, strong) NSArray<LRPost *> *posts;

@end

@implementation LRTableController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"Reddit";

    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 70.0;

    UIRefreshControl *refreshControl =
        [[UIRefreshControl alloc] init];

    self.refreshControl = refreshControl;

    [refreshControl addTarget:self
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

            UIAlertAction *action =
                [UIAlertAction
                 actionWithTitle:@"OK"
                 style:UIAlertActionStyleDefault
                 handler:nil];

            [alert addAction:action];

            [self presentViewController:alert
                               animated:YES
                             completion:nil];
        }
    }];
}

#pragma mark - Table View

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

    LRPost *post = self.posts[indexPath.row];

    cell.textLabel.text = post.title;

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
    LRPost *post = self.posts[indexPath.row];

    NSString *urlString =
        [NSString stringWithFormat:
         @"https://www.reddit.com%@",
         post.permalink];

    NSURL *url =
        [NSURL URLWithString:urlString];

    if (url != nil) {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

        [[UIApplication sharedApplication] openURL:url];

#pragma clang diagnostic pop
    }

    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
}

@end

#pragma mark - App Delegate

@interface LRAppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;

@end

@implementation LRAppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window =
        [[UIWindow alloc]
         initWithFrame:[UIScreen mainScreen].bounds];

    LRTableController *tableController =
        [[LRTableController alloc] init];

    UINavigationController *navigationController =
        [[UINavigationController alloc]
         initWithRootViewController:tableController];

    self.window.rootViewController =
        navigationController;

    [self.window makeKeyAndVisible];

    return YES;
}

@end

#pragma mark - Main

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
```
