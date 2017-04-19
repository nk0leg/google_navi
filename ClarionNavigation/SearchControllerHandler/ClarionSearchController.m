
//
//  ClarionSearchController.m
//  ClarionNavigation
//
//  Created by Andrii Kravchenko on 19.04.17.
//  Copyright © 2017 Luxoft. All rights reserved.
//

#import "ClarionSearchController.h"
#import "ClarionSearchBar.h"

@interface ClarionSearchController ()

@property (nonatomic, strong) ClarionSearchBar *_searchBar;

@end

@implementation ClarionSearchController

- (instancetype)initWithSearchResultsController:(UIViewController *)searchResultsController {
    self = [super initWithSearchResultsController:searchResultsController];
    
    if (self != nil) {
        self.hidesNavigationBarDuringPresentation = NO;
        self.dimsBackgroundDuringPresentation = YES;
    }
    return self;
}

- (UISearchBar *)searchBar {
    if (!self._searchBar) {
        self._searchBar = [ClarionSearchBar new];
    }
    return self._searchBar;
}

@end
