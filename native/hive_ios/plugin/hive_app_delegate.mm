#import <HIVEService/HIVEService-Swift.h>
#import "drivers/apple_embedded/godot_app_delegate.h"

// Register before UIApplicationMain, not while Godot is enumerating services.
@interface JellyMonHiveAppDelegate : NSObject <UIApplicationDelegate, UIWindowSceneDelegate>
@end

@implementation JellyMonHiveAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	BOOL ready = [HIVEAppDelegate application:application didFinishLaunchingWithOptions:launchOptions];
	NSLog(@"[JellyMonHive] app delegate initialized=%d", ready);
	return ready;
}
@end

__attribute__((constructor)) static void register_hive_app_delegate() {
	[GDTApplicationDelegate addService:[JellyMonHiveAppDelegate new]];
}
