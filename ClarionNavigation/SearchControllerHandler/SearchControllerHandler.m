//
//  SearchControllerHandler.m
//  ClarionNavigation
//
//  Created by Andrii Kravchenko on 19.04.17.
//  Copyright © 2017 Luxoft. All rights reserved.
//

#import "SearchControllerHandler.h"
#import "ClarionSearchBar.h"
#import "ClarionSearchController.h"

@interface SearchControllerHandler() <UISearchControllerDelegate, UISearchResultsUpdating, UISearchBarDelegate>

@property (nonatomic, weak) UISearchController *searchController;

@end

@implementation SearchControllerHandler

- (void)setupSearchController:(ClarionSearchController *)searchController {
    searchController.searchResultsUpdater = self;
    searchController.delegate = self;
    searchController.searchBar.delegate = self;    
    searchController.searchBar.placeholder = @"Choose a destination...";
    
    self.searchController = searchController;
}

- (void)willPresentSearchController:(UISearchController *)searchController {
    
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    
}

@end
