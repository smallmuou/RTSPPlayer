//
//  ViewController.h
//  RTSPPlayer
//
//  Created by xuwf on 13-8-19.
//  Copyright (c) 2013年 xuwf. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RTSPPlayerViewController.h"

@interface ViewController : UIViewController {
    UITextField* _urlTextView;
    RTSPPlayerViewController* _playerViewController;

}

@property (nonatomic, strong) IBOutlet UITextField*  urlTextView;
@property (nonatomic, strong) RTSPPlayerViewController* playerViewController;

@end
