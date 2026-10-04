#import <UIKit/UIKit.h>
#import "LegacyRedditApp.h"

@interface LDAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation LDAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window =
        [[UIWindow alloc]
            initWithFrame:[[UIScreen mainScreen] bounds]];

    LDRedditMainViewController *viewController =
        [[LDRedditMainViewController alloc] init];

    UINavigationController *navigationController =
        [[UINavigationController alloc]
            initWithRootViewController:viewController];

    self.window.rootViewController = navigationController;

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
            NSStringFromClass([LDAppDelegate class])
        );
    }
}
