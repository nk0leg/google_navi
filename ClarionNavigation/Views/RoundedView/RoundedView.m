//
//  RoundedView.m
//  ClarionNavigation
//
//  Created by Andrii Kravchenko on 19.04.17.
//  Copyright © 2017 Luxoft. All rights reserved.
//

#import "RoundedView.h"

@implementation RoundedView

- (void)setCornerRadius:(CGFloat)cornerRadius {
    _cornerRadius = cornerRadius;
    self.layer.cornerRadius = cornerRadius;
}

@end
