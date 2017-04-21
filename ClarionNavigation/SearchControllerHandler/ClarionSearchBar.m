//
//  ClarionSearchBar.m
//  ClarionNavigation
//
//  Created by Andrii Kravchenko on 19.04.17.
//  Copyright © 2017 Luxoft. All rights reserved.
//

#import "ClarionSearchBar.h"

@implementation ClarionSearchBar

// Due to Apple Bug Report radar #29859105
// http://stackoverflow.com/questions/33227177/hiding-cancel-button-on-search-bar-in-uisearchcontroller

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self setShowsCancelButton:NO];
}

@end
