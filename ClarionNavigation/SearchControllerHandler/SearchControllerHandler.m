//
//  SearchControllerHandler.m
//  ClarionNavigation
//
//  Created by Andrii Kravchenko on 19.04.17.
//  Copyright © 2017 Luxoft. All rights reserved.
//

#import "SearchControllerHandler.h"
#import <GooglePlaces/GooglePlaces.h>

#import "ClarionSearchBar.h"
#import "ClarionSearchController.h"
#import "SuggestionCell.h"

@interface SearchControllerHandler() <UISearchControllerDelegate, UISearchResultsUpdating, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, GMSAutocompleteFetcherDelegate>

@property (nonatomic, weak) UISearchController *searchController;
@property (nonatomic, weak) UITableView *tableView;

@property (nonatomic, strong) NSArray<GMSAutocompletePrediction *> *items;
@property (nonatomic, strong) GMSAutocompleteFetcher *fetcher;

@end

@implementation SearchControllerHandler

- (instancetype)initWithSearchController:(ClarionSearchController *)searchController tableView:(UITableView *)tableView
{
    self = [super init];
    if (self) {
        _searchController = searchController;
        [self setupSearchController];
        
        _tableView = tableView;
        [self setupTableView];
        
        _fetcher = [[GMSAutocompleteFetcher alloc] initWithBounds:nil filter:nil];
        _fetcher.delegate = self;
    }
    return self;
}

- (void)setupTableView {
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableFooterView = nil;
}

- (void)setupSearchController {
    self.searchController.searchResultsUpdater = self;
    self.searchController.delegate = self;
    self.searchController.searchBar.delegate = self;
    self.searchController.searchBar.placeholder = @"Choose a destination...";
    self.searchController.dimsBackgroundDuringPresentation = NO;
}

#pragma mark - Public

- (void)setSearchActive:(BOOL)isActive {
    if (isActive) {
        [self.searchController.searchBar performSelectorOnMainThread:@selector(becomeFirstResponder) withObject:nil waitUntilDone:NO];
        self.tableView.hidden = NO;
    } else {
        [self.searchController.searchBar endEditing:YES];
        self.tableView.hidden = YES;
    }
}

#pragma mark - UITableViewDatasource, UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SuggestionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SuggestionCell" forIndexPath:indexPath];
    
    GMSAutocompletePrediction *item = self.items[indexPath.row];
    
    cell.suggestionTitleLabel.attributedText = item.attributedPrimaryText;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self setSearchActive:NO];
    
    GMSAutocompletePrediction *item = self.items[indexPath.row];
    self.searchController.searchBar.text = [item.attributedPrimaryText string];
    [self.delegate suggestionDidSelect:[item.attributedPrimaryText string]];
}

#pragma mark - UISearchBarDelegate

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    self.tableView.hidden = NO;
    return YES;
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *text = searchController.searchBar.text;
    
    if (text.length) {
        [self.fetcher sourceTextHasChanged:text];
    }
}

#pragma mark - GMSAutocompleteFetcherDelegate

- (void)didAutocompleteWithPredictions:(NSArray<GMSAutocompletePrediction *> *)predictions {
    self.items = predictions;
    [self.tableView reloadData];
}

- (void)didFailAutocompleteWithError:(NSError *)error {
    NSLog(@"Suggestions error: %@", error);
}

@end
