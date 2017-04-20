//
//  SearchControllerHandler.h
//  ClarionNavigation
//
//  Created by Andrii Kravchenko on 19.04.17.
//  Copyright © 2017 Luxoft. All rights reserved.
//

#import <UIKit/UIKit.h>
@class ClarionSearchController;

@protocol SearchControllerHandlerDelegate <NSObject>

- (void)suggestionDidSelect:(NSString *)suggestion;

@end

@interface SearchControllerHandler : NSObject

- (instancetype)initWithSearchController:(ClarionSearchController *)searchController tableView:(UITableView *)tableView;
- (void)setSearchActive:(BOOL)isActive;

@property (nonatomic, weak) id<SearchControllerHandlerDelegate> delegate;

@end
