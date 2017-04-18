//
//  MainMenuView.h
//  ClarionNavigation
//
//  Created by Andrii Kravchenko on 18.04.17.
//  Copyright © 2017 Luxoft. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, MainMenuItemType) {
    MainMenuItemTypeSearch = 0,
    MainMenuItemTypeFavourite,
    MainMenuItemTypeRecent,
    MainMenuItemTypeAbout,
    MainMenuItemTypeExit
};

@protocol MainMenuDelegate <NSObject>

- (void)menuItemSelected:(MainMenuItemType)itemType;

@end

@interface MainMenuView : UIView

@property (weak, nonatomic) id<MainMenuDelegate> delegate;

@end
