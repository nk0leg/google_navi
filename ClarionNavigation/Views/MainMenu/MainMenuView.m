//
//  MainMenuViewController.m
//  ClarionNavigation
//
//  Created by Andrii Kravchenko on 18.04.17.
//  Copyright © 2017 Luxoft. All rights reserved.
//

#import "MainMenuView.h"

@interface MainMenuView()

@property (nonatomic, strong) IBOutlet UIView *loadedView;
@property (nonatomic, weak) IBOutlet UIView *titleView;

@end

@implementation MainMenuView

#pragma mark - Setup
- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self != nil) {
        [self placeView];
        [self configureAppearance];
    }
    return self;
}

- (void)placeView {
    self.clipsToBounds = YES;
    
    [[[NSBundle mainBundle] loadNibNamed:NSStringFromClass([self class]) owner:self options:nil] firstObject];
    self.loadedView.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:self.loadedView];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[_loadedView]-0-|" options:NSLayoutFormatDirectionLeadingToTrailing metrics:nil views:NSDictionaryOfVariableBindings(_loadedView)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[_loadedView]-0-|" options:NSLayoutFormatDirectionLeadingToTrailing metrics:nil views:NSDictionaryOfVariableBindings(_loadedView)]];
}

- (void)configureAppearance {
    [self addBorder];
    [self addTitleShadow];
}

- (void)addBorder {
    CGFloat borderWidth = 2.0f;
    
    self.frame = CGRectInset(self.frame, -borderWidth, -borderWidth);
    self.layer.borderColor = [UIColor whiteColor].CGColor;
    self.layer.borderWidth = borderWidth;
    
    self.layer.cornerRadius = 10.0;
}

- (void)addTitleShadow {
    self.titleView.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.titleView.layer.shadowOffset = CGSizeMake(0,3);
    self.titleView.layer.shadowOpacity = 0.5;
}

#pragma mark - Actions

- (IBAction)menuItemClicked:(UIButton *)sender {
    [self.delegate menuItemSelected:sender.tag];
}

@end
