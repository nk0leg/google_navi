//
//  AppDelegate.h
//  ClarionNavigation
//
//  Created by luxoft iosdev on 09.04.17.
//  Copyright © 2017 Luxoft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

