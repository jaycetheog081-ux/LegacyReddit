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
+ (void)fetchFrontPage:(void (^)(NSArray<LRPost *> *, NSError *))completion {
    NSURL *url = [NSURL URLWithString:@"https://www.reddit.com/r/all.json?limit=25&raw_json=1"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"LegacyReddit/1.0 iOS12 client" forHTTPHeaderField:@"User-Agent"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
            return;
        }

        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        NSArray *children = json[@"data"][@"children"];
        NSMutableArray *posts = [NSMutableArray array];

        for (NSDictionary *child in children) {
            NSDictionary *d = child[@"data"];
            if (![d isKindOfClass:[NSDictionary class]]) continue;
            LRPost *post = [LRPost new];
            post.title = d[@"title"] ?: @"";
            post.author = d[@"author"] ?: @"[deleted]";
            post.subreddit = d[@"subreddit_name_prefixed"] ?: @"";
            post.permalink = d[@"permalink"] ?: @"";
            [posts addObject:post];
        }

        dispatch_async(dispatch_get_main_queue(), ^{ completion(posts, jsonError); });
    }] resume];
}
@end

@interface LRTableController : UITableViewController
@property(nonatomic, strong) NSArray<LRPost *> *posts;
@end

@implementation LRTableController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Reddit";
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    [self refresh:nil];
}

- (void)refresh:(id)sender {
    [LRAPI fetchFrontPage:^(NSArray<LRPost *> *posts, NSError *error) {
        if (posts) self.posts = posts;
        [self.tableView reloadData];
        [self.refreshControl endRefreshing];

        if (error) {
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Reddit"
                                                                        message:error.localizedDescription
                                                                 preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        }
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.posts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"Post";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
        cell.textLabel.numberOfLines = 3;
        cell.detailTextLabel.numberOfLines = 2;
    }

    LRPost *post = self.posts[indexPath.row];
    cell.textLabel.text = post.title;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", post.subreddit, post.author];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    LRPost *post = self.posts[indexPath.row];
    NSString *urlString = [NSString stringWithFormat:@"https://www.reddit.com%@", post.permalink];
    NSURL *url = [NSURL URLWithString:urlString];
    if ([[UIApplication sharedApplication] canOpenURL:url])
        [[UIApplication sharedApplication] openURL:url];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}
@end

@interface LRAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation LRAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    LRTableController *vc = [LRTableController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];

    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([LRAppDelegate class]));
    }
}
